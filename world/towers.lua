local Theme = require("core.theme")
local TowerDefs = require("world.tower_defs")
local Util = require("core.util")
local Sound = require("systems.sound")
local State = require("core.state")
local MapMod = require("world.map")
local Floaters = require("ui.floaters")
local Rumble = require("systems.rumble")
local Targeting = require("world.targeting")
local Difficulty = require("systems.difficulty")
local Enemies = require("world.enemies")
local Effects = require("world.effects")
local Projectiles = require("world.projectiles")
local Shock = require("world.shock")
local L = require("core.localization")
--local Steam = require("luasteam")

local towers = {}

local pi = math.pi
local abs = math.abs
local atan2 = math.atan2
local min = math.min
local max = math.max
local floor = math.floor

local colorGood = Theme.ui.good
local colorWarn = Theme.ui.warn

local cgR, cgG, cgB = colorGood[1], colorGood[2], colorGood[3]
local cwR, cwG, cwB = colorWarn[1], colorWarn[2], colorWarn[3]

local enemies = Enemies.enemies

local findTarget = Targeting.findProgressTarget
local isValidTarget = Targeting.isValidTarget

local FIRE_ANGLE_EPS = math.rad(6)

local shopOrder = {
	"slow",
	"lancer",
	"poison",
	"shock",
	"cannon",
}

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
		range = def.range,
		range2 = def.range * def.range,
		fireRate = def.fireRate,
		fireInterval = 1 / def.fireRate,
		damage = def.damage,
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
		retargetT = 0,
		turnSpeed = def.turnSpeed or 12,
		canRotate = def.canRotate ~= false,
		sellValue = floor(def.cost * 0.75),
		slow = def.onHitSlow and {factor = def.onHitSlow.factor, dur = def.onHitSlow.dur} or nil,
		splash = def.splash and {radius = def.splash.radius, falloff = def.splash.falloff} or nil,
		chain = def.chain and {jumps = def.chain.jumps, radius = def.chain.radius, falloff = def.chain.falloff} or nil,
		poison = def.poison and {dps = def.poison.dps, dur = def.poison.dur, maxStacks = def.poison.maxStacks} or nil,
	}

	State.money = State.money - def.cost
	MapMod.map.blocked[MapMod.makeKey(gx, gy)] = true
	table.insert(towers, t)

	Floaters.add(x, y - 20, "-" .. def.cost, cwR, cwG, cwB)

	Sound.play("towerPlaced")

	Rumble.pulse(0.32, 0.055)

	--[[if Steam then
		Steam.userStats.setAchievement("ACH_TEST")
		Steam.userStats.storeStats()
		print("unlocked steam achievement: ACH_TEST")
	end]]

	return true
end

local function getUpgradeCost(tower)
    local base = tower.def.cost
    local exp = 1.55

    return floor(base * (exp ^ tower.level) + 0.5)
end

local function upgradeTower(t)
	if not t then
		return
	end

	local cost = getUpgradeCost(t)

	if State.money < cost then
		return
	end

	local diff = Difficulty.get()

	State.money = State.money - cost

	t.level = t.level + 1
	t.damage = t.damage * t.def.upgrade.dmgMult
	t.range = t.range + t.def.upgrade.rangeAdd
	t.range2 = t.range * t.range
	t.recoil = t.def.upgrade.recoil or 0
	t.fireRate = t.fireRate * t.def.upgrade.fireMult
	t.fireInterval = 1 / t.fireRate
	t.sellValue = t.sellValue + floor(cost * diff.sellRefund)

	if t.slow and t.def.upgrade.slowDurAdd then
		t.slow.dur = t.slow.dur + t.def.upgrade.slowDurAdd
	end

	if t.splash and t.def.upgrade.splashAdd then
		t.splash.radius = t.splash.radius + t.def.upgrade.splashAdd
	end

	if t.chain and t.def.upgrade.jumpAdd then
		t.chain.jumps = t.chain.jumps + t.def.upgrade.jumpAdd
	end

	if t.poison then
		if t.def.upgrade.poisonDurAdd then
			t.poison.dur = t.poison.dur + t.def.upgrade.poisonDurAdd
		end

		if t.def.upgrade.poisonDpsMult then
			t.poison.dps = t.poison.dps * t.def.upgrade.poisonDpsMult
		end

		if t.def.upgrade.stackAdd then
			t.poison.maxStacks = min(6, t.poison.maxStacks + t.def.upgrade.stackAdd) -- 6 max
		end
	end

	t.levelUpAnim = 1

	Floaters.add(t.x, t.y - 20, L("floater.upgrade"), cgR, cgG, cgB)

	--Sound.play("towerUpgraded")

	Rumble.pulse(0.22, 0.045)
end

local function getUpgradePreview(t)
	if not t or not t.def or not t.def.upgrade then
		return nil
	end

	local u = t.def.upgrade

	-- Start from current effective stats
	local curDamage = t.damage or t.def.damage
	local curFireRate = t.fireRate or t.def.fireRate
	local curRange = t.range or t.def.range

	local preview = {
		damage = curDamage,
		fireRate = curFireRate,
		range = curRange,
	}

	-- Damage
	if u.dmgMult then
		preview.damage = curDamage * u.dmgMult
	end

	-- Fire rate
	if u.fireMult then
		preview.fireRate = curFireRate * u.fireMult
	end

	-- Range
	if u.rangeAdd then
		preview.range = curRange + u.rangeAdd
	end

	return preview
end


local function sellTower(t)
	if not t then
		return
	end

	State.money = State.money + t.sellValue
	MapMod.map.blocked[MapMod.makeKey(t.gx, t.gy)] = nil

	for i = #towers, 1, -1 do
		if towers[i] == t then
			table.remove(towers, i)

			break
		end
	end

	Floaters.add(t.x, t.y - 20, "+" .. t.sellValue, cgR, cgG, cgB)
	State.selectedTower = nil

	Sound.play("towerSold")

	Rumble.pulse(0.18, 0.04)
end

local function findTowerAt(gx, gy)
	for i = 1, #towers do
		local t = towers[i]

		if t.gx == gx and t.gy == gy then
			return t
		end
	end

	return nil
end

local function updateTowers(dt)
	for i = 1, #towers do
		local t = towers[i]

		t.cooldown = t.cooldown - dt
		t.fireAnim = max(0, t.fireAnim - dt * 8)
		t.spawnAnim = max(0, (t.spawnAnim or 0) - dt * 5)
		t.levelUpAnim = max(0, t.levelUpAnim - dt * 3.5)

		-- Retarget cooldown
		t.retargetT = (t.retargetT or 0) - dt

		local target = t.target

		-- Validate existing target
		if target and not isValidTarget(t, target) then
			target = nil
		end

		-- Only rescan if needed
		if not target and t.retargetT <= 0 then
			target = findTarget(t, enemies)
			t.retargetT = 0.10
		end

		t.target = target

		-- Recoil decay (magnitude only)
		local decay = t.recoilDecay or 18
		t.recoil = max(0, t.recoil - decay * dt)

		-- Charge builds as we approach next shot
		if t.cooldown > 0 then
			local pct = 1 - (t.cooldown * t.fireInterval)
			t.charge = max(0, min(1, pct))
		else
			t.charge = 1
		end

		-- Aim + rotation
		local aimDiff = nil

		if target then
			local ax, ay = target.x, target.y

			if t.splash then
				local speedFactor = min((target.speed or 0) / 120, 0.18)
				local leadTime = 0.28 + speedFactor

				if target.slowTimer and target.slowTimer > 0 then
					leadTime = leadTime * 0.85
				end

				local futureDist = (target.dist or 0) + (target.speed or 0) * leadTime
				local nx, ny = MapMod.sampleAtDist(futureDist) -- careful: MapMod vs WorldMap (see note below)

				ax = ax + (nx - target.x)
				ay = ay + (ny - target.y)
			end

			t.aimX = ax
			t.aimY = ay

			local dx = ax - t.x
			local dy = ay - t.y
			local targetAngle = atan2(dy, dx)

			aimDiff = (targetAngle - t.angle + pi) % (pi * 2) - pi

			if t.canRotate then
				local recoilT = t.recoil / (t.recoilStrength or 1)
				local recoilDamp = 1 - min(1, recoilT)
				local turnSpeed = (t.turnSpeed or 12) * (1 + t.fireAnim * 0.35) * recoilDamp

				if abs(aimDiff) > 0.001 then
					t.angle = t.angle + aimDiff * min(1, turnSpeed * dt)
				end
			else
				aimDiff = 0
			end
		end

		-- Wind-up / fire
		if t.windUp and t.windUp > 0 then
			t.windUp = t.windUp - dt

			if t.windUp <= 0 and target then
				local canFire = true

				if t.canRotate then
					local ax = t.aimX or target.x
					local ay = t.aimY or target.y

					local dx = ax - t.x
					local dy = ay - t.y
					local targetAngle = atan2(dy, dx)
					local diff = (targetAngle - t.angle + pi) % (pi * 2) - pi

					canFire = abs(diff) <= FIRE_ANGLE_EPS
				end

				if canFire then
					-- Fire
					if t.chain and target and target.hp > 0 then
						local zapOrder = Shock.fire(t, target, enemies)

						-- Always show feedback for a Shock fire
						if zapOrder and #zapOrder > 0 then
							Effects.spawnZapEffect(t.x, t.y, zapOrder)
						else
							-- Fallback: single-target zap
							Effects.spawnZapEffect(t.x, t.y, {{from = t, to = target}})
						end
					else
						Projectiles.spawn(t, target)
					end

					t.fireAnim = 1
					t.recoil = t.recoilStrength or 0

					t.cooldown = t.fireInterval
				end

				t.windUp = 0
			end

		elseif t.cooldown <= 0 and target then
			if not t.canRotate or (aimDiff and abs(aimDiff) <= FIRE_ANGLE_EPS) then
				t.windUp = 0.08
			end
		end
	end
end

local function clear()
	for i = #towers, 1, -1 do
		towers[i] = nil
	end
end

return {
	towers = towers,
	shopOrder = shopOrder,
	TowerDefs = TowerDefs,
	addTower = addTower,
	getUpgradeCost = getUpgradeCost,
	upgradeTower = upgradeTower,
	getUpgradePreview = getUpgradePreview,
	sellTower = sellTower,
	findTowerAt = findTowerAt,
	updateTowers = updateTowers,
	clear = clear,
}