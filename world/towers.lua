local Constants = require("core.constants")
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
local Modules = require("systems.modules")
local TowerBranchDefs = require("world.tower_branch_defs")
local RunStats = require("systems.run_stats")
local Save = require("core.save")
local CampaignUnlocks = require("systems.campaign_unlocks")

local towers = {}
local towersByCell = {}

local pi = math.pi
local TWO_PI = pi * 2
local abs = math.abs
local cos = math.cos
local sin = math.sin
local atan2 = math.atan2
local min = math.min
local max = math.max
local floor = math.floor

local colorGood = Theme.ui.good
local colorWarn = Theme.ui.warn

local cgR, cgG, cgB = colorGood[1], colorGood[2], colorGood[3]
local cwR, cwG, cwB = colorWarn[1], colorWarn[2], colorWarn[3]

local enemies = Enemies.enemies

local findTarget = Targeting.findTarget
local isSemanticallyValidTarget = Targeting.isSemanticallyValidTarget
local sampleFast = MapMod.sampleFast
local getTargetMode = Modules.getTargetMode

local FIRE_ANGLE_EPS = math.rad(6)
local AIM_RECOMPUTE_POS_EPS2 = 1
local AIM_RECOMPUTE_ANGLE_EPS = math.rad(0.75)
local AIM_RECOMPUTE_STALE_FRAMES = 6
local SPLASH_LEAD_SPEED_THRESHOLD = 20
local RETARGET_INTERVAL = Constants.TOWER_RETARGET_INTERVAL or 0.10
local MAX_BRANCH_UPGRADES = 4
-- Each entry is the cost of the next specialization as a multiple of the
-- tower's purchase price. Keeping this curve explicit prevents a base-cost
-- balance pass from being amplified by an opaque exponential formula.
local UPGRADE_COST_MULTIPLIERS = {1.25, 1.75, 2.4, 3.2}
local RETARGET_JITTER = 0.10
local RETARGET_MIN_FACTOR = 0.5
local RETARGET_MAX_FACTOR = 1.5

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
	local progress = min(1, upgrades / MAX_BRANCH_UPGRADES)

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
	t.range2 = t.range * t.range
	t._cache = t._cache or {}
	t._cache.targetMode = {
		value = Modules.getTargetMode(t) or Targeting.MODES.PROGRESS,
		modulesVersion = Modules.version,
		cacheVersion = t._cacheVersion or 0,
	}
	t.targetMode = t._cache.targetMode.value
	t._targetModeVersion = t._cache.targetMode.modulesVersion
end

local function refreshTargetModeCache(t)
	local modulesVersion = Modules.version
	local cacheVersion = t._cacheVersion or 0
	t._cache = t._cache or {}
	local cached = t._cache.targetMode

	if not cached or cached.modulesVersion ~= modulesVersion or cached.cacheVersion ~= cacheVersion then
		cached = {
			value = getTargetMode(t) or Targeting.MODES.PROGRESS,
			modulesVersion = modulesVersion,
			cacheVersion = cacheVersion,
		}
		t._cache.targetMode = cached
	end

	t.targetMode = cached.value
	t._targetModeVersion = cached.modulesVersion
end

local function addTower(kind, gx, gy)
	local def = TowerDefs[kind]
	if not def then return false, "unknown_tower" end

	if not CampaignUnlocks.isTowerUnlocked(kind) then
		return false, "locked"
	end

	if State.money < def.cost then
		return false, "money"
	end

	local ok, why = MapMod.canPlaceAt(gx, gy)

	if not ok then
		return false, why
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
		spawnAnim = 1,
		target = nil,
		lastTargetId = nil,
		lastTargetX = nil,
		lastTargetY = nil,
		lastAimDiff = nil,
		aimStaleFrames = 0,
		targetMode = nil,
		_targetModeVersion = nil,
		_cacheVersion = 0,
		_cache = {},
		retargetT = 0,
		_retargetSeed = towerPhaseSeed(kind, gx, gy),
		_retargetCycle = 0,
		turnSpeed = def.turnSpeed or 12,
		canRotate = def.canRotate ~= false,
		color = def.color,
		sellValue = floor(def.cost * diff.sellRefund),
		slow = def.onHitSlow,
		splash = def.splash,
		chain = def.chain,
		poison = def.poison,
		plasma = def.plasma,
		specializationId = nil,
		appliedModules = {},
		branchSelections = {},
		_upgradePreview = {
			specializationId = nil,
			nextLevel = 2,
		},
	}

	local phase = unitFromSeed(t._retargetSeed)
	t.retargetT = RETARGET_INTERVAL * phase

	recomputeTowerStats(t)

	State.money = State.money - def.cost
	RunStats.recordPurchase(t, def.cost)
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
	if State.isReplayMode() and not TowerBranchDefs.getChoices(tower.kind, (tower.level or 1) + 1) then
		return nil
	end

	local upgradeIndex = tower.level or 1
	local multiplier = UPGRADE_COST_MULTIPLIERS[upgradeIndex]

	if not multiplier then
		return nil
	end

	return floor(tower.def.cost * multiplier + 0.5)
end

local function upgradeTower(t, specializationId)
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
	local nextLevel = (t.level or 1) + 1

	if State.isReplayMode() and not specializationId then
		return false, "missing_choice"
	end
	if specializationId and not TowerBranchDefs.isValidChoice(t.kind, nextLevel, specializationId) then
		return false, "invalid_choice"
	end

	State.money = State.money - cost

	t.level = t.level + 1
	t.prevHeight = t.height
	t.height = (t.level - 1) * 4
	t.levelUpAnim = 1
	if State.isReplayMode() then
		t.specializationId = specializationId
		t.branchSelections = t.branchSelections or {}
		t.branchSelections[#t.branchSelections + 1] = specializationId
	end
	RunStats.recordUpgrade(t, specializationId, cost, State.wave, t.level >= 5)
	Save.recordTowerUpgrade(t.kind, specializationId)
	recomputeTowerStats(t)
	Modules.invalidateTower(t)
	t.sellValue = t.sellValue + floor(cost * diff.sellRefund)
	t._upgradePreview = t._upgradePreview or {}
	t._upgradePreview.specializationId = specializationId
	t._upgradePreview.nextLevel = t.level + 1

	Floaters.add(t.x, t.renderY - 30, L("floater.upgrade"), cgR, cgG, cgB)

	Sound.play("towerUpgraded")

	Achievements.increment("TOWER_UPGRADES")
	if TowerBranchDefs.getChoices(t.kind, t.level + 1) == nil then
		Effects.trigger("final_tier_upgrade", {intensity = 4, shake = 6, duration = 0.3, hitStop = 0.06})
	end


	return true
end

local function getUpgradePreview(t)
	if not t or not t.def then
		return nil
	end

	local preview = t._upgradePreview
	if not preview then
		preview = {}
		t._upgradePreview = preview
	end
	preview.specializationId = t.specializationId
	preview.nextLevel = t.level + 1

	return preview
end

local function sellTower(t)
	if not t then
		return
	end

	State.money = State.money + t.sellValue
	RunStats.recordSale(t, t.sellValue)

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
	t.spawnAnim = max(0, (t.spawnAnim or 0) - dt * 5)
	t.levelUpAnim = max(0, t.levelUpAnim - dt * 3.5)

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

	local spawn = t.spawnAnim or 0
	local bodyY = t.y
	if spawn > 0 then
		local pSpawn = 1 - spawn
		local easeSpawn = pSpawn * pSpawn * (3 - 2 * pSpawn)
		bodyY = bodyY - ((1 - easeSpawn) * 8)
	end

	t.renderY = bodyY - animatedHeight

	local recoilDecay = t.recoilDecay or 18
	t.recoil = max(0, t.recoil - recoilDecay * dt)

	if t.cooldown > 0 then
		local pct = 1 - (t.cooldown * t.fireInterval)
		t.charge = max(0, min(1, pct))
	else
		t.charge = 1
	end
end

local function updateTowers(dt)

	for i = 1, #towers do
		local t = towers[i]

		local attackSpeed, rangeMult, lastStand = 1, 1, false
		local buffs = t.abilityBuffs
		if buffs then
			for bi = #buffs, 1, -1 do
				local buff = buffs[bi]
				if (buff.expires or 0) <= (State.abilityClock or 0) then table.remove(buffs, bi)
				else attackSpeed = min(2.5, attackSpeed * (buff.attackSpeed or 1)); rangeMult = max(rangeMult, buff.range or 1); lastStand = lastStand or buff.kind == "last_stand" end
			end
		end
		t.abilityAttackSpeed, t.abilityRangeMultiplier = attackSpeed, rangeMult
		t.range2 = (t.range * rangeMult) ^ 2
		local prevWindUp = t.windUp or 0
		t.cooldown = max(0, (t.cooldown or 0) - dt * attackSpeed)
		t.windUp = max(0, prevWindUp - dt * attackSpeed)
		t.retargetT = max(0, (t.retargetT or 0) - dt)
		local windUpCompleted = prevWindUp > 0 and t.windUp <= 0

		updateTowerVisuals(t, dt)

		if t.cooldown > 0
			and not t.target
			and (not t.windUp or t.windUp <= 0)
			and t.retargetT > 0 then
			goto continue_tower_update
		end

		refreshTargetModeCache(t)
		if lastStand then t.targetMode = Targeting.MODES.PROGRESS end

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
			target = findTarget(t, t.targetMode)
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
				if t.splash and targetSpeed > SPLASH_LEAD_SPEED_THRESHOLD then
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
	for i = #towers, 1, -1 do
		clearTowerIndex(towers[i])
		towers[i] = nil
	end

	for gx in pairs(towersByCell) do
		towersByCell[gx] = nil
	end
end

return {
	towers = towers,
	TowerDefs = TowerDefs,
	towersByCell = towersByCell,
	addTower = addTower,
	getUpgradeCost = getUpgradeCost,
	upgradeTower = upgradeTower,
	getUpgradePreview = getUpgradePreview,
	sellTower = sellTower,
	findTowerAt = findTowerAt,
	updateTowers = updateTowers,
	clear = clear,
}
