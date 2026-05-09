local Constants = require("core.constants")
local Theme = require("core.theme")
local TowerDefs = require("world.tower_defs")
local Sound = require("systems.sound")
local State = require("core.state")
local MapMod = require("world.map")
local Floaters = require("ui.floaters")
local Rumble = require("systems.rumble")
local Targeting = require("world.targeting")
local Difficulty = require("systems.difficulty")
local Enemies = require("world.enemies")
local Effects = require("world.effects")
local Achievements = require("systems.achievements")
local Emissions = require("world.emissions")
local L = require("core.localization")
local Modules = require("systems.modules")
local TowerBranchDefs = require("world.tower_branch_defs")
--local Steam = require("luasteam")

local towers = {}
local towersByCell = {}

local pi = math.pi
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
local isValidTarget = Targeting.isValidTarget
local sampleFast = MapMod.sampleFast
local getTargetMode = Modules.getTargetMode

local FIRE_ANGLE_EPS = math.rad(6)
local RETARGET_INTERVAL = Constants.TOWER_RETARGET_INTERVAL or 0.10
local MAX_BRANCH_UPGRADES = 4

local function swapRemove(list, index)
	local last = #list
	list[index] = list[last]
	list[last] = nil
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
	t.targetMode = Modules.getTargetMode(t) or Targeting.MODES.PROGRESS
	t._targetModeVersion = Modules.version
end

local function refreshTargetModeCache(t)
	local modulesVersion = Modules.version

	if t._targetModeVersion ~= modulesVersion then
		t.targetMode = getTargetMode(t) or Targeting.MODES.PROGRESS
		t._targetModeVersion = modulesVersion
	end
end

local function addTower(kind, gx, gy)
	local def = TowerDefs[kind]

	if State.money < def.cost then
		return false, "money"
	end

	local ok, why = MapMod.canPlaceAt(gx, gy)

	if not ok then
		return false, why
	end

	local x, y = MapMod.gridToCenter(gx, gy)

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
		targetMode = nil,
		_targetModeVersion = nil,
		retargetT = 0,
		turnSpeed = def.turnSpeed or 12,
		canRotate = def.canRotate ~= false,
		color = def.color,
		sellValue = floor(def.cost * 0.75),
		slow = def.onHitSlow,
		splash = def.splash,
		chain = def.chain,
		poison = def.poison,
		plasma = def.plasma,
		specializationId = nil,
		branchSelections = {},
		_upgradePreview = {
			specializationId = nil,
			nextLevel = 2,
		},
	}

	recomputeTowerStats(t)

	State.money = State.money - def.cost

	MapMod.setBlocked(gx, gy)

	towers[#towers + 1] = t
	setTowerIndex(t)

	Floaters.add(x, t.renderY - 30, "-" .. def.cost, cwR, cwG, cwB)

	Effects.spawnPlacePuff(x, y)

	Sound.play("towerPlaced")

	Rumble.pulse(0.32, 0.055)

	return true
end

local function getUpgradeCost(tower)
    local base = tower.def.cost
    local exp = 1.55

    return floor(base * (exp ^ tower.level) + 0.5)
end

local function upgradeTower(t, specializationId)
	if not t then
		return false, "missing_tower"
	end

	if not specializationId then
		return false, "missing_choice"
	end

	local cost = getUpgradeCost(t)

	if State.money < cost then
		return false, "money"
	end

	local diff = Difficulty.get()
	local nextLevel = (t.level or 1) + 1

	if not TowerBranchDefs.isValidChoice(t.kind, nextLevel, specializationId) then
		return false, "invalid_choice"
	end

	State.money = State.money - cost

	t.level = t.level + 1
	t.prevHeight = t.height
	t.height = (t.level - 1) * 4
	t.levelUpAnim = 1
	t.specializationId = specializationId
	t.branchSelections = t.branchSelections or {}
	t.branchSelections[#t.branchSelections + 1] = specializationId
	recomputeTowerStats(t)
	Modules.invalidateTower(t)
	t.sellValue = t.sellValue + floor(cost * diff.sellRefund)
	t._upgradePreview = t._upgradePreview or {}
	t._upgradePreview.specializationId = specializationId
	t._upgradePreview.nextLevel = t.level + 1

	Floaters.add(t.x, t.renderY - 30, L("floater.upgrade"), cgR, cgG, cgB)

	Sound.play("towerUpgraded")

	Achievements.increment("TOWER_UPGRADES")

	Rumble.pulse(0.22, 0.045)

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

	Rumble.pulse(0.18, 0.04)
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

		local prevWindUp = t.windUp or 0
		t.cooldown = max(0, (t.cooldown or 0) - dt)
		t.windUp = max(0, prevWindUp - dt)
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

		local target = t.target

		-- Keep existing target if still valid
		if target then
			if not isValidTarget(t, target) then
				target = nil
			end
		end

		-- Only search when we need a new target
		local canRetarget = t.retargetT <= 0
		if not target and canRetarget then
			target = findTarget(t, t.targetMode)
			t.retargetT = RETARGET_INTERVAL
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
			local ax, ay = target.x, target.y

			if t.splash then
				local speedFactor = min((target.speed or 0) / 120, 0.18)
				local leadTime = 0.28 + speedFactor

				if target.slowTimer and target.slowTimer > 0 then
					leadTime = leadTime * 0.85
				end

				local futureDist = (target.dist or 0) + (target.speed or 0) * leadTime
				local nx, ny = sampleFast(futureDist)

				ax = ax + (nx - target.x)
				ay = ay + (ny - target.y)
			end

			t.aimX = ax
			t.aimY = ay

			local dx = ax - tx
			local dy = ay - ty

			local targetAngle = atan2(dy, dx)

			if targetAngle then
				t.targetAngle = targetAngle
			else
				t.targetAngle = nil
			end

			-- Shortest angle difference
			local diff = (targetAngle - t.angle + pi) % (pi * 2) - pi

			aimDiff = diff

			if canRotate then
				local recoilT = t.recoil / recoilStrength
				local recoilDamp = 1 - min(1, recoilT)
				local turnSpeed = turnSpeedBase * (1 + t.fireAnim * 0.35) * recoilDamp

				if abs(aimDiff) > 0.001 then
					t.angle = t.angle + aimDiff * min(1, turnSpeed * dt)
				end
			else
				aimDiff = 0
			end
		end

		-- Wind-up / fire
		if windUpCompleted and target then
				local canFire = true

				if canRotate then
					local ax = t.aimX or target.x
					local ay = t.aimY or target.y

					local dx = ax - tx
					local dy = ay - ty
					local targetAngle = t.targetAngle
					local diff = (targetAngle - t.angle + pi) % (pi * 2) - pi

					canFire = abs(diff) <= FIRE_ANGLE_EPS
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
