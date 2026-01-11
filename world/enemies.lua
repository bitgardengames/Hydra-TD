local Constants = require("core.constants")
local Theme = require("core.theme")
local Sound = require("systems.sound")
local Util = require("core.util")
local State = require("core.state")
local MapMod = require("world.map")
local Floaters = require("ui.floaters")

local enemies = {}
local deathFX = {}

local colorGood = Theme.ui.good
local colorBad = Theme.ui.bad

local tick = 0.5 -- seconds per poison tick

local enemyDefs = {
	grunt = {
		name = "Grunt",
		hp = 42,
		speed = 70,
		reward = 7,
		score = 10,
		radius = 10,
	},

	tank = {
		name = "Tank",
		hp = 120,
		speed = 45,
		reward = 14,
		score = 22,
		radius = 12,
	},

	runner = {
		name = "Runner",
		hp = 28,
		speed = 95,
		reward = 7,
		score = 12,
		radius = 9,
	},

	splitter = {
		name = "Splitter",
		hp = 70,
		speed = 60,
		reward = 11,
		score = 18,
		radius = 11,
		split = {
			count = 2,
			child = "runner",
			childHpMult = 0.6,
			childSpdMult = 1.1,
		}
	},

	boss = {
		name = "Boss",
		hp = 7600,
		speed = 45,
		reward = 100,
		score = 300,
		radius = 18,
		boss = true,

		modifiers = {
			slow = 0.5, -- 50% slow effectiveness (movement speed)
			poison = 1.25, -- +25% poison damage taken
		}
	},
}

local function findEnemyAt(x, y)
	for _, e in ipairs(enemies) do
		local dx = x - e.x
		local dy = y - e.y

		if dx * dx + dy * dy <= e.radius * e.radius then
			return e
		end
	end

	return nil
end

local function spawnEnemy(kind, hpMult, spdMult, spawnX, spawnY, pathIndex)
	local def = enemyDefs[kind]

	local x, y, idx

	if spawnX and spawnY and pathIndex then
		x, y = spawnX, spawnY
		idx = pathIndex
	else
		local startGX, startGY = MapMod.map.path[1][1], MapMod.map.path[1][2]
		x, y = MapMod.gridToCenter(startGX, startGY)
		idx = 1
	end

	local e = {
		kind = kind,
		def = def,
		x = x,
		y = y,
		boss = def.boss or false,
		hp = def.hp * hpMult,
		maxHp = def.hp * hpMult,
		baseSpeed = def.speed * spdMult,
		speed = def.speed * spdMult,
		reward = def.reward,
		score = def.score,
		radius = def.radius,
		split = def.split,
		hitFlash = 0,
		dying = false,
		deathT = 0,
		deathDur = 0.3,
		spawnFade = 0.12,
		exitFade = nil,
		alpha = 1,
		animT = 0,
		pathIndex = idx,
		modifiers = def.modifiers,
		slowFactor = 1,
		slowTimer = 0,
		poisonStacks = 0,
		poisonTimer = 0,
		poisonDPS = 0,
	}

	if e.boss then
		State.activeBoss = e
	end

	table.insert(enemies, e)
end

local function updateEnemies(dt)
	for i = #enemies, 1, -1 do
		local e = enemies[i]
		local isBoss = e.boss

		-- Animate
		e.animT = (e.animT or 0) + dt * e.speed * 0.03

		-- Spawn fade-in
		if e.spawnFade and e.spawnFade > 0 then
			e.spawnFade = e.spawnFade - dt
			if e.spawnFade < 0 then
				e.spawnFade = 0
			end
		end

		local alphaIn = 1

		if e.spawnFade and e.spawnFade > 0 then
			alphaIn = 1 - (e.spawnFade / 0.12)
		end

		local alphaOut = 1

		if e.exitFade and e.exitFade > 0 then
			alphaOut = e.exitFade / 0.10
		end

		e.alpha = math.min(alphaIn, alphaOut)

		-- Poison ticks
		if e.poisonStacks > 0 then
			e.poisonTimer = e.poisonTimer - dt
			e.poisonTickTimer = (e.poisonTickTimer or 0) + dt

			while e.poisonTickTimer >= tick do
				e.poisonTickTimer = e.poisonTickTimer - tick

				local poisonMult = (e.modifiers and e.modifiers.poison) or 1.0
				local dmg = e.poisonDPS * e.poisonStacks * poisonMult * tick
				e.hp = e.hp - dmg

				if e.poisonSource then
					e.poisonSource.damageDealt = e.poisonSource.damageDealt + dmg
					e.lastHitTower = e.poisonSource
				end

				e.hitFlash = 0.03
				State.addDamage("poison", dmg, e.boss == true)
			end

			if e.poisonTimer <= 0 then
				e.poisonTimer = 0
				e.poisonDuration = 0
				e.poisonStacks = 0
				e.poisonDPS = 0
				e.poisonSource = nil
				e.poisonTickTimer = 0
			end
		end

		-- Boss death hold (face shown, explosion delayed)
		if isBoss and e.dying then
			e.deathT = e.deathT - dt

			if e.deathT <= 0 then
				if e.lastHitTower then
					e.lastHitTower.kills = e.lastHitTower.kills + 1
				end

				State.money = State.money + e.reward
				State.score = State.score + e.score

				Floaters.addFloater(e.x, e.y - 10, "+" .. e.reward, colorGood[1], colorGood[2], colorGood[3])

				table.insert(deathFX, {
					x = e.x,
					y = e.y,
					r = e.radius,
					t = 0,
				})

				State.activeBoss = nil
				require("world.projectiles").spawnBossDeathExplosion(e.x, e.y, e.radius)

				table.remove(enemies, i)
			end

			goto continue
		end

		-- Death check
		if e.hp <= 0 then
			-- Boss: enter short death hold instead of dying instantly
			if isBoss then
				e.dying = true
				e.deathT = e.deathDur
				e.speed = 0

				-- Clear selection immediately
				if State.selectedEnemy == e then
					State.selectedEnemy = nil
				end

				goto continue
			end

			-- Non-boss: immediate death
			if e.lastHitTower then
				e.lastHitTower.kills = e.lastHitTower.kills + 1
			end

			if State.selectedEnemy == e then
				State.selectedEnemy = nil
			end

			if e.split then
				for j = 1, e.split.count do
					spawnEnemy(e.split.child, e.split.childHpMult or 1.0, e.split.childSpdMult or 1.0, e.x, e.y, e.pathIndex)
				end
			end

			State.money = State.money + e.reward
			State.score = State.score + e.score

			Floaters.addFloater(e.x, e.y - 10, "+" .. e.reward, colorGood[1], colorGood[2], colorGood[3])

			table.insert(deathFX, {
				x = e.x,
				y = e.y,
				r = e.radius,
				t = 0,
			})

			table.remove(enemies, i)

			goto continue
		end

		-- Slow
		if e.slowTimer > 0 then
			e.slowTimer = e.slowTimer - dt
			if e.slowTimer <= 0 then
				e.slowTimer = 0
				e.slowDuration = 0
				e.slowFactor = 1.0
			end
		end

		e.speed = e.baseSpeed * e.slowFactor

		-- Hit flash
		if e.hitFlash > 0 then
			e.hitFlash = e.hitFlash - dt
			if e.hitFlash < 0 then e.hitFlash = 0 end
		end

		-- Path movement
		local nextIndex = math.min(e.pathIndex + 1, #MapMod.map.path)
		local gx, gy = MapMod.map.path[nextIndex][1], MapMod.map.path[nextIndex][2]
		local tx, ty = MapMod.gridToCenter(gx, gy)
		local dx, dy = tx - e.x, ty - e.y
		local d = Util.len(dx, dy)

		if d < 1e-6 then
			e.pathIndex = nextIndex
		else
			local step = e.speed * dt

			if step >= d then
				e.x, e.y = tx, ty
				e.pathIndex = nextIndex
			else
				e.x = e.x + (dx / d) * step
				e.y = e.y + (dy / d) * step
			end
		end

		-- Reached end
		if e.pathIndex >= #MapMod.map.path then
			if not e.exitFade then
				e.exitFade = 0.10
				e.speed = 0
			end

			e.exitFade = e.exitFade - dt

			if e.exitFade <= 0 then
				if isBoss then
					State.lives = 0
					State.gameOver = true
					State.victory = false

					State.endT = 0
					State.endReady = false
					State.endTitle  = "GAME OVER"
					State.endReason = "Boss breach"

					Sound.play("gameOver")
					Floaters.addFloater(e.x, e.y - 14, "BOSS BREACH!", colorBad[1], colorBad[2], colorBad[3])

					return
				end

				State.lives = State.lives - 1
				local livesAnim = State.livesAnim or 0
				State.livesAnim = livesAnim + (1 - livesAnim) * 0.6

				Floaters.addFloater(e.x, e.y - 10, "-1", colorBad[1], colorBad[2], colorBad[3])

				table.remove(enemies, i)

				if State.lives <= 0 then
					State.lives = 0
					State.gameOver = true
					State.victory = false

					State.endT = 0
					State.endReady = false
					State.endTitle  = "GAME OVER"
					State.endReason = "Out of lives"

					Sound.play("gameOver")
				end

				goto continue
			end
		end

		::continue::
	end

	-- Death ring
	for i = #deathFX, 1, -1 do
		local d = deathFX[i]
		d.t = d.t + dt

		if d.t > 0.12 then
			table.remove(deathFX, i)
		end
	end
end

local function clear()
	for i = #enemies, 1, -1 do
		enemies[i] = nil
	end
end

return {
	enemies = enemies,
	deathFX = deathFX,
	enemyDefs = enemyDefs,
	findEnemyAt = findEnemyAt,
	spawnEnemy = spawnEnemy,
	updateEnemies = updateEnemies,
	clear = clear,
}