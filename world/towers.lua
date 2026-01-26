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

local towers = {}

local pi = math.pi
local exp = math.exp
local atan2 = math.atan2
local min = math.min
local max = math.max

local colorGood = Theme.ui.good
local colorWarn = Theme.ui.warn

local findTarget = Targeting.findProgressTarget

local shopOrder = {
	"lancer",
	"slow",
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
		fireRate = def.fireRate,
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
		recoilDecay = def.recoilDecay or 0,
		angle = -pi / 2,
		levelUpAnim = 0,
		sellValue = math.floor(def.cost * 0.75),
		slow = def.onHitSlow and {factor = def.onHitSlow.factor, dur = def.onHitSlow.dur} or nil,
		splash = def.splash and {radius = def.splash.radius, falloff = def.splash.falloff} or nil,
		chain = def.chain and {jumps = def.chain.jumps, radius = def.chain.radius, falloff = def.chain.falloff} or nil,
		poison = def.poison and {dps = def.poison.dps, dur = def.poison.dur, maxStacks = def.poison.maxStacks} or nil,
	}

	State.money = State.money - def.cost
	MapMod.map.blocked[MapMod.makeKey(gx, gy)] = true
	table.insert(towers, t)

	Floaters.add(x, y - 10, "-" .. def.cost, colorWarn[1], colorWarn[2], colorWarn[3])

	Sound.play("towerPlaced")

	Rumble.pulse(0.32, 0.055)

	return true
end

local function towerUpgradeCost(t)
	return t.def.upgrade.cost + (t.level - 1) * math.floor(t.def.upgrade.cost * 0.6)
end

local function upgradeTower(t)
	if not t then
		return
	end

	local cost = towerUpgradeCost(t)

	if State.money < cost then
		return
	end

	local diff = Difficulty.get()

	State.money = State.money - cost

	t.level = t.level + 1
	t.damage = t.damage * t.def.upgrade.dmgMult
	t.range = t.range + t.def.upgrade.rangeAdd
	t.recoil = t.def.upgrade.recoil or 0
	t.fireRate = t.fireRate * t.def.upgrade.fireMult
	t.sellValue = t.sellValue + math.floor(cost * diff.sellRefund)

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
			t.poison.maxStacks = t.poison.maxStacks + t.def.upgrade.stackAdd
		end
	end

	t.levelUpAnim = 1

	Floaters.add(t.x, t.y - 10, L("floater.upgrade"), colorGood[1], colorGood[2], colorGood[3])

	Rumble.pulse(0.22, 0.045)
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

	Floaters.add(t.x, t.y - 10, "+" .. t.sellValue, colorGood[1], colorGood[2], colorGood[3])
	State.selectedTower = nil

	Rumble.pulse(0.18, 0.04)
end

local function findTowerAt(gx, gy)
	for _, t in ipairs(towers) do
		if t.gx == gx and t.gy == gy then
			return t
		end
	end

	return nil
end

local function updateTowers(dt)
	for _, t in ipairs(towers) do
		local target = findTarget(t, Enemies.enemies)
		local decay = t.def.recoilDecay or 18

		t.cooldown = t.cooldown - dt
		t.fireAnim = max(0, t.fireAnim - dt * 8)
		t.levelUpAnim = max(0, t.levelUpAnim - dt * 3.5)
		t.target = target

		if decay and decay > 0 then
			t.recoil = t.recoil * exp(-dt * decay)
		else
			t.recoil = 0
		end

		local cd = t.cooldown
		local cdMax = 1 / t.fireRate

		-- Charge builds as we approach next shot
		if t.cooldown > 0 then
			local pct = 1 - (t.cooldown * t.fireRate)

			t.charge = max(0, min(1, pct))
		else
			t.charge = 1
		end

		if target then
			local dx = target.x - t.x
			local dy = target.y - t.y
			local targetAngle = atan2(dy, dx)

			-- Rotation speed (radians per second)
			local turnSpeed = (t.def.turnSpeed or 12) * (1 + t.fireAnim * 0.35)

			-- Shortest-angle interpolation
			local diff = (targetAngle - t.angle + pi) % (pi * 2) - pi
			t.angle = t.angle + diff * min(1, turnSpeed * dt)
		end

		-- Wind-up phase
		if t.windUp and t.windUp > 0 then
			t.windUp = t.windUp - dt

			if t.windUp <= 0 and t.target then
				-- Pew
				if t.chain then
					local zapOrder = Shock.fire(t, t.target, Enemies.enemies)

					if zapOrder then
						Effects.spawnZapEffect(t.x, t.y, zapOrder)
					end
				else
					Projectiles.spawn(t, t.target)
				end

				t.fireAnim = 1
				t.recoil = t.recoilStrength or 0
				t.cooldown = 1.0 / t.fireRate
			end

		-- Start wind-up
		elseif t.cooldown <= 0 and t.target then
			t.windUp = 0.08
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
	towerUpgradeCost = towerUpgradeCost,
	upgradeTower = upgradeTower,
	sellTower = sellTower,
	findTowerAt = findTowerAt,
	updateTowers = updateTowers,
	clear = clear,
}