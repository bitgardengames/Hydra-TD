local Constants = require("core.constants")
local Theme = require("core.theme")
local Util = require("core.util")
local Sound = require("systems.sound")
local State = require("core.state")
local MapMod = require("world.map")
local Floaters = require("ui.floaters")

local towers = {}

local pi = math.pi
local exp = math.exp
local atan2 = math.atan2
local min = math.min
local max = math.max

local colorGood = Theme.ui.good
local colorWarn = Theme.ui.warn

local shopOrder = {
	"lancer",
	"slow",
	"poison",
	"shock",
	"cannon",
}

local towerDefs = {
	lancer = {
		name = "Lancer",
		cost = 40,
		range = 4.2 * Constants.TILE,
		fireRate = 2.0, -- shots/sec
		damage = 11,
		recoilStrength = Constants.TILE * 0.08,
		recoilDecay = 18,
		projSpeed = 460,
		turnSpeed = 15,
		color = Theme.tower.lancer,
		upgrade = {
			cost = 60,
			dmgMult = 1.15,
			rangeAdd = 0.30 * Constants.TILE,
			fireMult = 1.02,
		}
	},

	slow = {
		name = "Slow",
		cost = 50,
		range = 3.8 * Constants.TILE,
		fireRate = 1.4,
		damage = 6,
		recoilStrength = Constants.TILE * 0.06,
		recoilDecay = 18,
		projSpeed = 370,
		turnSpeed = 10,
		color = Theme.tower.slow,
		onHitSlow = {factor = 0.55, dur = 1.4},
		upgrade = {
			cost = 55,
			dmgMult = 1.2,
			rangeAdd = 0.2 * Constants.TILE,
			fireMult = 1.02,
			slowDurAdd = 0.35,
		}
	},

	cannon = {
		name = "Cannon",
		cost = 70,
		range = 3.2 * Constants.TILE,
		fireRate = 0.8, -- slow
		damage = 20, -- high base hit
		recoilStrength = Constants.TILE * 0.14,
		recoilDecay = 12,
		projSpeed = 320,
		turnSpeed = 6,
		color = Theme.tower.cannon,
		splash = {
			radius = 42, -- AoE radius in pixels
			falloff = 0.65, -- % damage applied at edge
		},
		upgrade = {
			cost = 82,
			dmgMult = 1.14,
			rangeAdd = 0.08 * Constants.TILE,
			fireMult = 1.05,
			splashAdd = 4, -- increase AoE radius per upgrade
		}
	},

	shock = {
		name = "Shock",
		cost = 65,
		range = 3.6 * Constants.TILE,
		fireRate = 1.2,
		damage = 9,
		recoilStrength = 0,
		recoilDecay = 0,
		turnSpeed = 20,
		color = Theme.tower.shock,
		chain = {
			jumps = 3, -- number of additional enemies
			radius = 48, -- max distance between jumps
			falloff = 0.75 -- damage multiplier per jump
		},
		upgrade = {
			cost = 78,
			dmgMult = 1.22,
			rangeAdd = 0.12 * Constants.TILE,
			fireMult = 1.08,
		}
	},

	poison = {
		name = "Poison",
		cost = 60,
		range = 3.8 * Constants.TILE,
		fireRate = 1.6,
		damage = 5,
		recoilStrength = Constants.TILE * 0.06,
		recoilDecay = 18,
		projSpeed = 360,
		turnSpeed = 10,
		color = Theme.tower.poison,
		poison = {
			dps = 8, -- damage per second per stack
			dur = 4, -- duration per application
			maxStacks = 4,
		},
		upgrade = {
			cost = 72,
			dmgMult = 1.1,
			rangeAdd = 0.25 * Constants.TILE,
			fireMult = 1.02,
			poisonDurAdd = 0.35,
			poisonDpsMult = 1.08,
			stackAdd = 1,
		}
	},
}

local function addTower(kind, gx, gy)
	local def = towerDefs[kind]

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
	Floaters.addFloater(x,y - 10, "-"..def.cost, colorWarn[1], colorWarn[2], colorWarn[3])

	Sound.play("towerPlaced")

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

	State.money = State.money - cost

	t.level = t.level + 1
	t.damage = t.damage * t.def.upgrade.dmgMult
	t.range = t.range + t.def.upgrade.rangeAdd
	t.recoil = t.def.upgrade.recoil or 0
	t.fireRate = t.fireRate * t.def.upgrade.fireMult
	t.sellValue = t.sellValue + math.floor(cost * 0.6)

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

	Floaters.addFloater(t.x, t.y - 10, "Upgrade!", colorGood[1], colorGood[2], colorGood[3])
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

	Floaters.addFloater(t.x, t.y - 10, "+"..t.sellValue, colorGood[1], colorGood[2], colorGood[3])
	State.selectedTower = nil
end

local function findTowerAt(gx, gy)
	for _, t in ipairs(towers) do
		if t.gx == gx and t.gy == gy then
			return t
		end
	end

	return nil
end

local function findTarget(tower, enemies)
	local best = nil
	local bestProg = -1
	local r2 = tower.range * tower.range

	for _, e in ipairs(enemies) do
		local d = Util.dist2(tower.x, tower.y, e.x, e.y)

		if d <= r2 then
			local prog = e.pathIndex + (1.0 - (e.slowTimer > 0 and 0.1 or 0.0))

			if prog > bestProg then
				bestProg = prog
				best = e
			end
		end
	end

	return best
end

local function zapChain(target, enemies, chain, baseDamage, tower)
	local hit = {}
	local order = {}

	local function zapEnemy(e, dmg)
		e.hp = e.hp - dmg
		table.insert(order, {from = target, to = e})
		hit[e] = true

		-- attribute damage
		tower.damageDealt = tower.damageDealt + dmg
		e.lastHitTower = tower

		-- Track damage
		State.addDamage("shock", dmg, e.boss == true)
	end

	-- first hit
	zapEnemy(target, baseDamage)

	local last = target
	local damage = baseDamage

	for i = 1, chain.jumps do
		damage = damage * chain.falloff
		local best = nil
		local bestDist = chain.radius * chain.radius

		for _, e in ipairs(enemies) do
			if not hit[e] and e.hp > 0 then
				local d = Util.dist2(last.x, last.y, e.x, e.y)

				if d <= bestDist then
					bestDist = d
					best = e
				end
			end
		end

		if not best then
			break
		end

		zapEnemy(best, damage)
		last = best
	end

	return order
end

local function updateTowers(dt)
	local Enemies = require("world.enemies")
	local Projectiles = require("world.projectiles")

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
			t.charge = math.max(0, math.min(1, pct))
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
					local zapOrder = zapChain(t.target, Enemies.enemies, t.chain, t.damage, t)
					Projectiles.spawnZapEffect(t.x, t.y, zapOrder)
				else
					Projectiles.spawnProjectile(t, t.target)
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
	towerDefs = towerDefs,
	addTower = addTower,
	towerUpgradeCost = towerUpgradeCost,
	upgradeTower = upgradeTower,
	sellTower = sellTower,
	findTowerAt = findTowerAt,
	updateTowers = updateTowers,
	clear = clear,
}