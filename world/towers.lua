local Constants = require("core.constants")
local TowerStatDisplay = require("core.tower_stat_display")
local Theme = require("core.theme")
local TowerDefs = require("world.tower_defs")
local Sound = require("systems.sound")
local State = require("core.state")
local MapMod = require("world.map")
local Floaters = require("ui.floaters")
local Targeting = require("world.targeting")
local Difficulty = require("systems.difficulty")
local Enemies = require("world.enemies")
local Effects = require("world.effects")
local Achievements = require("systems.achievements")
local Emissions = require("world.emissions")
local L = require("core.localization")
local ProjectileProfiles = require("world.projectile_profiles")
local RunStats = require("systems.run_stats")
local Save = require("core.save")
local CampaignUnlocks = require("systems.campaign_unlocks")

local towers = {}
local towersByCell = {}
local suppressionProjectiles = {}
-- Suppression is uncommon, so only visit towers whose timers can expire.
local suppressedTowers = {}
-- Only towers in this dense list can have a buff expire. Towers keep their
-- current slot so removal is O(1) and does not leave holes.
local activeAbilityBuffTowers = {}

local pi = math.pi
local TWO_PI = pi * 2
local abs = math.abs
local cos = math.cos
local sin = math.sin
local atan2 = math.atan2
local min = math.min
local max = math.max
local floor = math.floor
local sqrt = math.sqrt
local format = string.format

local colorGood = Theme.ui.good
local colorWarn = Theme.ui.warn

local cgR, cgG, cgB = colorGood[1], colorGood[2], colorGood[3]
local cwR, cwG, cwB = colorWarn[1], colorWarn[2], colorWarn[3]

local enemies = Enemies.enemies

local findTarget = Targeting.findTarget
local isSemanticallyValidTarget = Targeting.isSemanticallyValidTarget
local beginTargetingFrame = Targeting.beginFrame
local sampleFast = MapMod.sampleFast

local FIRE_ANGLE_EPS = math.rad(6)
local AIM_RECOMPUTE_POS_EPS2 = 1
local AIM_RECOMPUTE_ANGLE_EPS = math.rad(0.75)
local AIM_RECOMPUTE_STALE_FRAMES = 6
local RETARGET_INTERVAL = Constants.TOWER_RETARGET_INTERVAL or 0.10
local MAX_UPGRADES = 4
-- Each entry is the cost of the next level as a multiple of the tower's
-- purchase price. Every upgrade costs more than placing the base tower, and
-- later power tiers carry an increasingly large premium.
local UPGRADE_COST_MULTIPLIERS = {1.25, 1.5, 1.75, 2.0}
local RETARGET_JITTER = 0.10
local RETARGET_MIN_FACTOR = 0.5
local RETARGET_MAX_FACTOR = 1.5

-- These identifiers are part of addTower's public contract. Keep placement
-- failures distinct so callers can present the correct explanation without
-- inspecting map state or tower definitions themselves.
local PLACEMENT_FAILURE = {
	UNKNOWN_TOWER = "unknown_tower",
	TOWER_LOCKED = "tower_locked",
	INSUFFICIENT_FUNDS = "insufficient_funds",
	INVALID_TILE = "invalid_tile",
	ENEMY_PATH = "enemy_path",
	OCCUPIED_TILE = "occupied_tile",
}

local mapPlacementFailures = {
	path = PLACEMENT_FAILURE.ENEMY_PATH,
	occupied = PLACEMENT_FAILURE.OCCUPIED_TILE,
}

local function normalizeAngle(a)
	-- Performance-sensitive path: avoid `%` for the common small-diff case.
	if a > pi then
		a = a - TWO_PI
	elseif a < -pi then
		a = a + TWO_PI
	end

	if a > pi or a < -pi then
		while a > pi do
			a = a - TWO_PI
		end

		while a < -pi do
			a = a + TWO_PI
		end
	end

	return a
end

local function swapRemove(list, index)
	local last = #list
	list[index] = list[last]
	list[last] = nil
end

local function recomputeAbilityModifiers(t)
	local attackSpeed, rangeMult = 1, 1
	for i = 1, #(t.abilityBuffs or {}) do
		local buff = t.abilityBuffs[i]
		attackSpeed = min(2.5, attackSpeed * (buff.attackSpeed or 1))
		rangeMult = max(rangeMult, buff.range or 1)
	end
	t.abilityAttackSpeed = attackSpeed
	t.abilityRangeMultiplier = rangeMult
	local effectiveRange = (t.range or 0) * rangeMult
	t.range2 = effectiveRange * effectiveRange
end

local function untrackAbilityBuffTower(t)
	local index = t and t._activeAbilityBuffIndex
	if not index then return end

	local moved = activeAbilityBuffTowers[#activeAbilityBuffTowers]
	swapRemove(activeAbilityBuffTowers, index)
	if moved and moved ~= t then
		moved._activeAbilityBuffIndex = index
	end
	t._activeAbilityBuffIndex = nil
end

local function addAbilityBuff(t, buff)
	if not t or not buff then return false end
	t.abilityBuffs = t.abilityBuffs or {}
	t.abilityBuffs[#t.abilityBuffs + 1] = buff
	if not t._activeAbilityBuffIndex then
		activeAbilityBuffTowers[#activeAbilityBuffTowers + 1] = t
		t._activeAbilityBuffIndex = #activeAbilityBuffTowers
	end
	t.range2 = t.range * t.range
	return true
end

local function clearAbilityBuffs(t)
	if not t then return end
	untrackAbilityBuffTower(t)
	t.abilityBuffs = nil
	recomputeAbilityModifiers(t)
end

local function expireAbilityBuffs(now)
	for activeIndex = #activeAbilityBuffTowers, 1, -1 do
		local t = activeAbilityBuffTowers[activeIndex]
		local buffs = t.abilityBuffs or {}
		local write = 1
		for read = 1, #buffs do
			local buff = buffs[read]
			if (buff.expires or 0) > now then
				buffs[write] = buff
				write = write + 1
			end
		end
		local changed = write <= #buffs
		for i = #buffs, write, -1 do buffs[i] = nil end
		if #buffs == 0 then
			untrackAbilityBuffTower(t)
			t.abilityBuffs = nil
		end
		if changed then recomputeAbilityModifiers(t) end
	end
end

local function hashString(s)
	local h = 0

	for i = 1, #s do
		h = (h * 131 + s:byte(i)) % 4294967296
	end

	return h
end

local function towerPhaseSeed(kind, gx, gy)
	local kindHash = hashString(kind or "")
	local seed = (kindHash + gx * 73856093 + gy * 19349663) % 4294967296

	return seed
end

local function unitFromSeed(seed)
	return ((seed % 104729) + 0.5) / 104729
end

local function nextRetargetInterval(t)
	local cycle = (t._retargetCycle or 0) + 1
	t._retargetCycle = cycle

	local seed = (t._retargetSeed or 0) + cycle * 83492791
	local u = unitFromSeed(seed)
	local factor = 1 + ((u * 2 - 1) * RETARGET_JITTER)
	factor = min(RETARGET_MAX_FACTOR, max(RETARGET_MIN_FACTOR, factor))

	return RETARGET_INTERVAL * factor
end


local function setTowerIndex(t)
	if not t then
		return
	end

	local gx, gy = t.gx, t.gy

	if gx == nil or gy == nil then
		return
	end

	local col = towersByCell[gx]

	if not col then
		col = {}
		towersByCell[gx] = col
	end

	col[gy] = t
	t._indexGx = gx
	t._indexGy = gy
end

local function clearTowerIndexAt(gx, gy, expectedTower)
	local col = towersByCell[gx]

	if not col then
		return
	end

	if expectedTower == nil or col[gy] == expectedTower then
		col[gy] = nil

		if not next(col) then
			towersByCell[gx] = nil
		end
		::continue_tower_update::
	end
end

local function clearTowerIndex(t)
	if not t then
		return
	end

	clearTowerIndexAt(t._indexGx or t.gx, t._indexGy or t.gy, t)
	t._indexGx = nil
	t._indexGy = nil
end

local function recomputeTowerStats(t)
	local def = t and t.def
	if not def then
		return
	end

	local level = max(1, t.level or 1)
	local upgrades = max(0, level - 1)
	local upgrade = def.upgrade or {}
	local progress = min(1, upgrades / MAX_UPGRADES)

	local dmgMult = upgrade.dmgMult or 1
	local fireMult = upgrade.fireMult or 1
	local rangeAdd = upgrade.rangeAdd or 0

	-- Upgrade multipliers are interpreted as "at max upgrade" values so they scale
	-- smoothly as levels are gained.
	local scaledDamageMult = 1 + (dmgMult - 1) * progress
	local scaledFireMult = 1 + (fireMult - 1) * progress
	t.damage = def.damage * scaledDamageMult
	t.fireRate = def.fireRate * scaledFireMult
	t.fireInterval = 1 / max(0.001, t.fireRate)
	t.range = def.range + rangeAdd * upgrades
	recomputeAbilityModifiers(t)
end

local function addTower(kind, gx, gy)
	local def = TowerDefs[kind]
	if not def then return false, PLACEMENT_FAILURE.UNKNOWN_TOWER end

	if not CampaignUnlocks.isTowerUnlocked(kind) then
		return false, PLACEMENT_FAILURE.TOWER_LOCKED
	end

	if State.money < def.cost then
		return false, PLACEMENT_FAILURE.INSUFFICIENT_FUNDS
	end

	if type(gx) ~= "number" or type(gy) ~= "number"
		or gx % 1 ~= 0 or gy % 1 ~= 0
		or gx < 1 or gx > Constants.GRID_W
		or gy < 1 or gy > Constants.GRID_H then
		return false, PLACEMENT_FAILURE.INVALID_TILE
	end

	local ok, why = MapMod.canPlaceAt(gx, gy)

	if not ok then
		return false, mapPlacementFailures[why] or PLACEMENT_FAILURE.INVALID_TILE
	end

	local x, y = MapMod.gridToCenter(gx, gy)
	local diff = Difficulty.get()

	local t = {
		kind = kind,
		def = def,
		gx = gx,
		gy = gy,
		x = x,
		y = y,
		level = 1,
		height = 0,
		prevHeight = 0,
		renderY = y,
		range = 0,
		range2 = 0,
		fireRate = 0,
		fireInterval = 0,
		damage = 0,
		projSpeed = def.projSpeed,
		cooldown = 0,
		damageDealt = 0,
		kills = 0,
		charge = 0,
		windUp = 0,
		fireAnim = 0,
		recoil = 0,
		recoilStrength = def.recoilStrength or 0,
		recoilDecay = def.recoilDecay or 18,
		angle = -pi / 2,
		levelUpAnim = 0,
		target = nil,
		lastTargetId = nil,
		lastTargetX = nil,
		lastTargetY = nil,
		lastAimDiff = nil,
		aimStaleFrames = 0,
		retargetT = 0,
		_retargetSeed = towerPhaseSeed(kind, gx, gy),
		_retargetCycle = 0,
		turnSpeed = def.turnSpeed or 12,
		canRotate = def.canRotate ~= false,
		color = def.color,
		sellValue = floor(def.cost * diff.sellRefund),
		_upgradePreview = {
			nextLevel = 2,
		},
	}

	local phase = unitFromSeed(t._retargetSeed)
	t.retargetT = RETARGET_INTERVAL * phase

	recomputeTowerStats(t)

	State.money = State.money - def.cost
	RunStats.recordPurchase(t)
	Save.recordTowerPlacement(kind)

	MapMod.setBlocked(gx, gy)

	towers[#towers + 1] = t
	setTowerIndex(t)

	Floaters.add(x, t.renderY - 30, "-" .. def.cost, cwR, cwG, cwB)

	Effects.spawnPlacePuff(x, y)

	Sound.play("towerPlaced")


	return true
end

local function getUpgradeCost(tower)
	if not tower or (tower.level or 1) >= 5 then
		return nil
	end
	local upgradeIndex = tower.level or 1
	local multiplier = UPGRADE_COST_MULTIPLIERS[upgradeIndex]

	if not multiplier then
		return nil
	end

	return floor(tower.def.cost * multiplier + 0.5)
end

local getUpgradePreview

local function upgradeTower(t)
	if not t then
		return false, "missing_tower"
	end

	local cost = getUpgradeCost(t)

	if not cost then
		return false, "max_level"
	end

	if State.money < cost then
		return false, "money"
	end

	local diff = Difficulty.get()
	-- Capture the same derived data used by the UI before mutating the tower. This
	-- keeps the cosmetic response tied to the authored tower stats.
	local transformationPreview = getUpgradePreview and getUpgradePreview(t)

	State.money = State.money - cost

	t.level = t.level + 1
	t.prevHeight = t.height
	t.height = (t.level - 1) * 4
	t.levelUpAnim = 1
	-- Render-only confirmation that follows the tower body while its new tier rises.
	t.upgradeFlash = 0.3
	Save.recordTowerUpgrade(t.kind)
	recomputeTowerStats(t)
	t.sellValue = t.sellValue + floor(cost * diff.sellRefund)
	t._upgradePreview = t._upgradePreview or {}
	t._upgradePreview.nextLevel = t.level + 1

	Floaters.add(t.x, t.renderY - 30, L("floater.upgrade"), cgR, cgG, cgB)

	Sound.play("towerUpgraded")

	Achievements.increment("TOWER_UPGRADES")
	local isFinalTier = t.level >= 5
	Emissions.emitUpgradeTransformation(t, transformationPreview, isFinalTier)
	if isFinalTier then
		Effects.shake(6, 0.3)
	end


	return true
end

local function previewTowerStats(t, level)
	local def = t.def
	local upgrades = max(0, level - 1)
	local progress = min(1, upgrades / MAX_UPGRADES)
	local upgrade = def.upgrade or {}

	return {
		damage = def.damage * (1 + ((upgrade.dmgMult or 1) - 1) * progress),
		fireRate = def.fireRate * (1 + ((upgrade.fireMult or 1) - 1) * progress),
		range = def.range + (upgrade.rangeAdd or 0) * upgrades,
	}
end

local function cloneForPreview(t, level)
	local clone = {}
	for k, v in pairs(t) do
		clone[k] = v
	end
	clone.level = level
	return clone
end

local function behaviorMap(profile)
	local out = {}
	for i = 1, #(profile and profile.behaviors or {}) do
		local behavior = profile.behaviors[i]
		out[behavior.id] = behavior.data or {}
	end
	return out
end

local function effectiveDamage(stats, behaviors)
	local mult = 1
	if behaviors.hit_damage then mult = mult * (behaviors.hit_damage.mult or 1) end
	if behaviors.cannon_damage_scale then mult = mult * (behaviors.cannon_damage_scale.mult or 1) end
	return stats.damage * mult
end

local function numberText(value, decimals, suffix)
	return format("%." .. decimals .. "f%s", value, suffix or "")
end

local function addPreviewRow(rows, key, current, nextValue, direction)
	if current ~= nextValue then
		rows[#rows + 1] = {
			key = key,
			labelKey = "upgradePreview." .. key,
			current = current,
			next = nextValue,
			direction = direction,
		}
	end
end

local function addBehaviorRows(rows, before, after)
	local scalar = {
		{ "splash", "aoe_damage", "radius", function(v) return numberText(v, 0, " px") end },
		{ "slowStrength", "apply_slow", "factor", function(v) return numberText((1 - v) * 100, 0, "%") end, true },
		{ "poisonStrength", "apply_poison", "dps", function(v) return numberText(v, 1, "/s") end },
		{ "poisonStacks", "apply_poison", "maxStacks", function(v) return numberText(v, 0) end },
		{ "poisonDuration", "apply_poison", "dur", function(v) return numberText(v, 1, "s") end },
		{ "slowDuration", "apply_slow", "dur", function(v) return numberText(v, 1, "s") end },
		{ "tickRate", "tick_damage", "rate", function(v) return numberText(v, 3, "s") end, true },
	}
	for i = 1, #scalar do
		local item = scalar[i]
		local a = before[item[2]] and before[item[2]][item[3]]
		local b = after[item[2]] and after[item[2]][item[3]]
		if a and b and a ~= b then
			addPreviewRow(rows, item[1], item[4](a), item[4](b), item[5] and (b < a and "good" or "bad") or (b > a and "good" or "bad"))
		elseif b and not a then
			addPreviewRow(rows, item[1], "—", item[4](b), "good")
		end
	end

	local descriptors = {
		{ "chains", "hit_chain", "jumps", function(v) return format("%d", v) end },
		{ "impactFragments", "split_on_hit", "count", function(v) return format("%d", v) end },
		{ "pierce", "pierce", "maxHits", function(v) return format("%d", v) end },
	}
	for i = 1, #descriptors do
		local item = descriptors[i]
		local a = before[item[2]] and before[item[2]][item[3]]
		local b = after[item[2]] and after[item[2]][item[3]]
		if b and a ~= b then
			addPreviewRow(rows, item[1], a and item[4](a) or "—", item[4](b), "good")
		end
	end
end

getUpgradePreview = function(t)
	if not t or not t.def then
		return nil
	end
	local level = max(1, t.level or 1)
	local nextLevel = level + 1
	local currentClone = cloneForPreview(t, level)
	local nextClone = cloneForPreview(t, nextLevel)
	local currentStats = previewTowerStats(currentClone, level)
	local nextStats = previewTowerStats(nextClone, nextLevel)
	local currentBehaviors = behaviorMap({ behaviors = ProjectileProfiles.get(currentClone) })
	local nextBehaviors = behaviorMap({ behaviors = ProjectileProfiles.get(nextClone) })
	local rows = {}

	local currentDamage = effectiveDamage(currentStats, currentBehaviors)
	local nextDamage = effectiveDamage(nextStats, nextBehaviors)
	currentStats.directDamage = currentDamage
	currentStats.mechanics = currentBehaviors
	nextStats.directDamage = nextDamage
	nextStats.mechanics = nextBehaviors
	addPreviewRow(rows, "damage", numberText(currentDamage, 1), numberText(nextDamage, 1), nextDamage > currentDamage and "good" or "bad")
	addPreviewRow(rows, "fireRate", tostring(TowerStatDisplay.attackSpeed(currentStats.fireRate)), tostring(TowerStatDisplay.attackSpeed(nextStats.fireRate)), nextStats.fireRate > currentStats.fireRate and "good" or "bad")
	addPreviewRow(rows, "range", tostring(TowerStatDisplay.range(currentStats.range)), tostring(TowerStatDisplay.range(nextStats.range)), nextStats.range > currentStats.range and "good" or "bad")
	addBehaviorRows(rows, currentBehaviors, nextBehaviors)

	return {
		nextLevel = nextLevel,
		current = currentStats,
		postUpgrade = nextStats,
		rows = rows,
	}
end

local function sellTower(t)
	if not t then
		return
	end

	State.money = State.money + t.sellValue

	local col = MapMod.map.blocked[t.gx]

	if col then
		col[t.gy] = nil

		if not next(col) then
			MapMod.map.blocked[t.gx] = nil
		end
	end

	clearTowerIndex(t)

	for i = #towers, 1, -1 do
		if towers[i] == t then
			swapRemove(towers, i)
			break
		end
	end

	Floaters.add(t.x, t.renderY - 30, "+" .. t.sellValue, cgR, cgG, cgB)
	State.selectedTower = nil

	Sound.play("towerSold")

end

local function findTowerAt(gx, gy)
	local col = towersByCell[gx]

	if not col then
		return nil
	end

	return col[gy]
end


local function updateTowerVisuals(t, dt)
	t.fireAnim = max(0, t.fireAnim - dt * 8)
	t.levelUpAnim = max(0, t.levelUpAnim - dt * 3.5)
	t.upgradeFlash = max(0, (t.upgradeFlash or 0) - dt)

	local riseAnim = t.levelUpAnim or 0
	local animatedHeight
	if riseAnim > 0 then
		local p = 1 - riseAnim
		local ease = p * p * (3 - 2 * p)
		local prev = t.prevHeight or 0
		animatedHeight = prev + (t.height - prev) * ease
	else
		animatedHeight = t.height
	end

	t.renderY = t.y - animatedHeight

	local recoilDecay = t.recoilDecay or 18
	t.recoil = max(0, t.recoil - recoilDecay * dt)

	if t.cooldown > 0 then
		local pct = 1 - (t.cooldown * t.fireInterval)
		t.charge = max(0, min(1, pct))
	else
		t.charge = 1
	end
end

local function isTowerActive(t)
	return t and towersByCell[t.gx] and towersByCell[t.gx][t.gy] == t
end

local function applySuppression(target, duration)
	if not isTowerActive(target) then return end
	target.suppressedTimer = duration
	if duration > 0 and not target._suppressedTowerIndex then
		suppressedTowers[#suppressedTowers + 1] = target
		target._suppressedTowerIndex = #suppressedTowers
	end
	target.target = nil
	target.windUp = 0
end

local function updateSuppressedTowers(dt)
	for i = #suppressedTowers, 1, -1 do
		local t = suppressedTowers[i]
		local active = isTowerActive(t)
		if active then
			t.suppressedTimer = max(0, (t.suppressedTimer or 0) - dt)
		end

		if not active or t.suppressedTimer <= 0 then
			local moved = suppressedTowers[#suppressedTowers]
			swapRemove(suppressedTowers, i)
			if moved and moved ~= t then
				moved._suppressedTowerIndex = i
			end
			t._suppressedTowerIndex = nil
		end
	end
end

local function updateSuppressionProjectiles(dt)
	for i = #suppressionProjectiles, 1, -1 do
		local p = suppressionProjectiles[i]
		local target = p.target
		if not isTowerActive(target) then
			swapRemove(suppressionProjectiles, i)
		else
			local tx, ty = target.x, target.renderY or target.y
			local dx, dy = tx - p.x, ty - p.y
			local distance2 = dx * dx + dy * dy
			local step = p.speed * dt
			if distance2 <= step * step then
				applySuppression(target, p.duration)
				swapRemove(suppressionProjectiles, i)
			else
				local scale = step / sqrt(distance2)
				p.x = p.x + dx * scale
				p.y = p.y + dy * scale
			end
		end
	end
end

local function findSuppressionTarget(boss, suppression)
	local range2 = suppression.range * suppression.range
	local target, targetDistance2
	for i = 1, #towers do
		local candidate = towers[i]
		local dx, dy = candidate.x - boss.x, candidate.y - boss.y
		local distance2 = dx * dx + dy * dy
		if distance2 <= range2 and (candidate.suppressedTimer or 0) <= 0 then
			-- Grid coordinates provide an explicit, stable tie-break independent of
			-- tower array order (which can change when a tower is sold).
			local winsTie = target and distance2 == targetDistance2
				and (candidate.gy < target.gy
					or (candidate.gy == target.gy and candidate.gx < target.gx))
			if not target or distance2 < targetDistance2 or winsTie then
				target, targetDistance2 = candidate, distance2
			end
		end
	end
	return target
end

local function updateSuppression(dt)
	updateSuppressionProjectiles(dt)

	local boss = State.activeBoss
	local suppression = boss and boss.suppression
	if not suppression or boss.dying or (boss.hp or 0) <= 0 then return end

	boss.suppressionTimer = (boss.suppressionTimer or suppression.period) - dt
	if boss.suppressionTimer > 0 or #towers == 0 then return end

	local target = findSuppressionTarget(boss, suppression)
	if not target then return end
	suppressionProjectiles[#suppressionProjectiles + 1] = {
		x = boss.x,
		y = boss.y,
		target = target,
		duration = suppression.duration,
		speed = suppression.projectileSpeed,
	}
	boss.suppressionCasts = (boss.suppressionCasts or 0) + 1
	boss.suppressionTimer = suppression.period
end

local function updateTowers(dt)
	-- Retire last frame's targeting keys even when no tower needs to retarget.
	beginTargetingFrame(State.frameId)
	-- Tick order is intentional: suppression timers expire first; existing boss
	-- projectiles move and impact; the boss may cast; then towers retarget and fire.
	-- This lets an impact retain its full authored duration for the current tick.
	updateSuppressedTowers(dt)
	updateSuppression(dt)

	for i = 1, #towers do
		local t = towers[i]
		local prevWindUp = t.windUp or 0
		t.cooldown = max(0, (t.cooldown or 0) - dt)
		t.windUp = max(0, prevWindUp - dt)
		t.retargetT = max(0, (t.retargetT or 0) - dt)
		local windUpCompleted = prevWindUp > 0 and t.windUp <= 0

		updateTowerVisuals(t, dt)
		if (t.suppressedTimer or 0) > 0 then
			t.target = nil
			t.windUp = 0
			goto continue_tower_update
		end

		if t.cooldown > 0
			and not t.target
			and (not t.windUp or t.windUp <= 0)
			and t.retargetT > 0 then
			goto continue_tower_update
		end

		local target = t.target

		-- Keep existing target if still valid
		if target then
			if not isSemanticallyValidTarget(t, target) then
				target = nil
			end
		end

		-- Only search when we need a new target
		local canRetarget = t.retargetT <= 0
		if not target and canRetarget then
			target = findTarget(t)
			t.retargetT = nextRetargetInterval(t)
		end

		t.target = target

		if not target and t.cooldown > 0 and (not t.windUp or t.windUp <= 0) then
			goto continue_tower_update
		end

		-- Aim + rotation
		local aimDiff = nil
		local canRotate = t.canRotate
		local tx, ty = t.x, t.y
		local turnSpeedBase = t.turnSpeed or 12
		local recoilStrength = t.recoilStrength or 1

		if target then
			local targetId = target.id or target.uid or target.spawnId or target
			local targetX, targetY = target.x, target.y
			local lastTargetId = t.lastTargetId
			local lastTargetX = t.lastTargetX
			local lastTargetY = t.lastTargetY
			local dxTarget = (targetX or 0) - (lastTargetX or targetX or 0)
			local dyTarget = (targetY or 0) - (lastTargetY or targetY or 0)
			local movedEnough = (dxTarget * dxTarget + dyTarget * dyTarget) > AIM_RECOMPUTE_POS_EPS2
			local targetChanged = targetId ~= lastTargetId
			local hasFreshGate = windUpCompleted or (t.cooldown <= 0)
			local staleFrames = (t.aimStaleFrames or 0) + 1
			local staleExceeded = staleFrames >= AIM_RECOMPUTE_STALE_FRAMES

			local shouldRecompute = targetChanged or movedEnough or staleExceeded or hasFreshGate

			if not shouldRecompute and canRotate and t.lastAimDiff then
				shouldRecompute = abs(t.lastAimDiff) > AIM_RECOMPUTE_ANGLE_EPS
			end

			if shouldRecompute then
				local ax, ay = targetX, targetY
				local targetSpeed = target.speed or 0
				local leadSpeedThreshold = t.def.targeting and t.def.targeting.leadPathTargetsAboveSpeed
				if leadSpeedThreshold and targetSpeed > leadSpeedThreshold then
					local speedFactor = min(targetSpeed / 120, 0.18)
					local leadTime = 0.28 + speedFactor

					if target.slowTimer and target.slowTimer > 0 then
						leadTime = leadTime * 0.85
					end

					local futureDist = (target.dist or 0) + targetSpeed * leadTime
					local nx, ny = sampleFast(futureDist)

					ax = ax + (nx - targetX)
					ay = ay + (ny - targetY)
				end

				t.aimX = ax
				t.aimY = ay

				local dx = ax - tx
				local dy = ay - ty
				local targetAngle = atan2(dy, dx)
				t.targetAngle = targetAngle
				aimDiff = normalizeAngle(targetAngle - t.angle)

				t.lastTargetId = targetId
				t.lastTargetX = targetX
				t.lastTargetY = targetY
				t.lastAimDiff = aimDiff
				t.aimStaleFrames = 0
			else
				aimDiff = t.lastAimDiff
				t.aimStaleFrames = staleFrames
			end

			if canRotate then
				local recoilT = t.recoil / recoilStrength
				local recoilDamp = 1 - min(1, recoilT)
				local turnSpeed = turnSpeedBase * (1 + t.fireAnim * 0.35) * recoilDamp

				if abs(aimDiff) > 0.001 then
					t.angle = t.angle + aimDiff * min(1, turnSpeed * dt)
					aimDiff = normalizeAngle(t.targetAngle - t.angle)
					t.lastAimDiff = aimDiff
				end
			else
				aimDiff = 0
				t.lastAimDiff = 0
			end
		else
			t.lastTargetId = nil
			t.lastTargetX = nil
			t.lastTargetY = nil
			t.lastAimDiff = nil
			t.aimStaleFrames = 0
		end

		-- Wind-up / fire
		if windUpCompleted and target then
				local canFire = true

				if canRotate then
					canFire = aimDiff and abs(aimDiff) <= FIRE_ANGLE_EPS
				end

				if canFire then
					Emissions.emit(t, target)
					t.fireAnim = 1
					t.recoil = t.recoilStrength or 0

					t.cooldown = t.fireInterval
				end

				t.windUp = 0

		elseif t.windUp > 0 then
			-- Keep winding up.
		elseif t.cooldown <= 0 and target then
			if not canRotate or (aimDiff and abs(aimDiff) <= FIRE_ANGLE_EPS) then
				t.windUp = 0.08
			end
		end

		::continue_tower_update::
	end
end

local function clear()
	Targeting.clearFrameCache()
	for i = #towers, 1, -1 do
		clearTowerIndex(towers[i])
		towers[i] = nil
	end

	for gx in pairs(towersByCell) do
		towersByCell[gx] = nil
	end

	for i = #suppressionProjectiles, 1, -1 do
		suppressionProjectiles[i] = nil
	end

	for i = #suppressedTowers, 1, -1 do
		suppressedTowers[i]._suppressedTowerIndex = nil
		suppressedTowers[i] = nil
	end
end

return {
	towers = towers,
	TowerDefs = TowerDefs,
	PLACEMENT_FAILURE = PLACEMENT_FAILURE,
	towersByCell = towersByCell,
	suppressionProjectiles = suppressionProjectiles,
	suppressedTowers = suppressedTowers,
	activeAbilityBuffTowers = activeAbilityBuffTowers,
	addAbilityBuff = addAbilityBuff,
	expireAbilityBuffs = expireAbilityBuffs,
	recomputeAbilityModifiers = recomputeAbilityModifiers,
	clearAbilityBuffs = clearAbilityBuffs,
	addTower = addTower,
	getUpgradeCost = getUpgradeCost,
	upgradeTower = upgradeTower,
	getUpgradePreview = getUpgradePreview,
	sellTower = sellTower,
	findTowerAt = findTowerAt,
	updateTowers = updateTowers,
	updateSuppression = updateSuppression,
	clear = clear,
}
