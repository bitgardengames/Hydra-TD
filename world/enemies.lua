local Theme = require("core.theme")
local Sound = require("systems.sound")
local Util = require("core.util")
local State = require("core.state")
local Effects = require("world.effects")
local MapMod = require("world.map")
local EnemyDefs = require("world.enemy_defs")
local Floaters = require("ui.floaters")
local L = require("core.localization")

local enemies = {}
local deathFX = {}

local colorGood = Theme.ui.good
local colorBad = Theme.ui.bad

local tick = 0.5 -- seconds per poison tick

local min = math.min
local max = math.max
local sin = math.sin
local cos = math.cos
local atan2 = math.atan2
local sqrt = math.sqrt
local tinsert = table.insert
local tremove = table.remove

local function findEnemyAt(x, y)
	for _, e in ipairs(enemies) do
		local dx = x - e.x
		local dy = y - e.y

		if dx * dx + dy * dy <= e.radius2 then
			return e
		end
	end

	return nil
end

local function spawnEnemy(kind, hpMult, spdMult, spawnX, spawnY, pathIndex, opts)
	local def = EnemyDefs[kind]

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
		radius2 = def.radius * def.radius,
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

		impulseVX = opts and opts.impulseAngle and cos(opts.impulseAngle) * (opts.impulseStrength or 0) or 0,
		impulseVY = opts and opts.impulseAngle and sin(opts.impulseAngle) * (opts.impulseStrength or 0) or 0,
		impulseT = opts and opts.impulseTime or 0,
	}

	if e.boss then
		State.activeBoss = e
	end

	tinsert(enemies, e)
end

local function updateEnemies(dt)
	local path = MapMod.map.path
	local pathWorld = MapMod.map.pathWorld
	local pathLen = #path

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

		e.alpha = min(alphaIn, alphaOut)

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

				tinsert(deathFX, {x = e.x, y = e.y, r = e.radius, t = 0})

				State.activeBoss = nil
				Effects.spawnBossDeathExplosion(e.x, e.y, e.radius)

				tremove(enemies, i)
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
					-- derive movement direction
					local node = pathWorld[e.pathIndex]
					local px = node[1]
					local py = node[2]
					local baseAngle = atan2(e.y - py, e.x - px)

					-- add slight spread
					local spread = (j - (e.split.count + 1) / 2) * 0.35

					spawnEnemy(e.split.child, e.split.childHpMult or 1.0, e.split.childSpdMult or 1.0, e.x, e.y, e.pathIndex, {impulseAngle = baseAngle + spread, impulseStrength = 60, impulseTime = 0.12})
				end
			end

			State.money = State.money + e.reward
			State.score = State.score + e.score

			tinsert(deathFX, {x = e.x, y = e.y, r = e.radius, t = 0})

			tremove(enemies, i)

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

			if e.hitFlash < 0 then
				e.hitFlash = 0
			end
		end

		if e.impulseT and e.impulseT > 0 then
			local p = e.impulseT / 0.12
			local ease = p * p * (3 - 2 * p)

			e.x = e.x + e.impulseVX * dt * ease
			e.y = e.y + e.impulseVY * dt * ease

			e.impulseT = e.impulseT - dt

			goto continue
		end

		-- Path movement
		local remaining = e.speed * dt

		while remaining > 0 and e.pathIndex < pathLen do
			local nextIndex = e.pathIndex + 1
			local node = pathWorld[nextIndex]
			local tx, ty = node[1], node[2]

			local dx = tx - e.x
			local dy = ty - e.y
			local d2 = dx * dx + dy * dy

			if d2 < 0.001 then
				-- Snap to node
				e.x, e.y = tx, ty
				e.pathIndex = nextIndex
			else
				local d = sqrt(d2)

				if remaining >= d then
					-- Consume entire segment
					e.x, e.y = tx, ty
					e.pathIndex = nextIndex
					remaining = remaining - d
				else
					-- Partial move
					local inv = remaining / d

					e.x = e.x + dx * inv
					e.y = e.y + dy * inv
					remaining = 0
				end
			end
		end

		-- Reached end of path
		if e.pathIndex >= pathLen then
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
					State.endTitle = L("game.gameOver")
					State.endReason = L("game.bossBreach")

					Sound.play("gameOver")

					return
				end

				State.lives = State.lives - 1
				local livesAnim = State.livesAnim or 0
				State.livesAnim = livesAnim + (1 - livesAnim) * 0.6

				Floaters.add(e.x, e.y - 10, "-1", colorBad[1], colorBad[2], colorBad[3])

				tremove(enemies, i)

				if State.lives <= 0 then
					State.lives = 0
					State.gameOver = true
					State.victory = false

					State.endT = 0
					State.endReady = false
					State.endTitle = L("game.gameOver")
					State.endReason = L("game.outOfLives")

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
			tremove(deathFX, i)
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
	EnemyDefs = EnemyDefs,
	findEnemyAt = findEnemyAt,
	spawnEnemy = spawnEnemy,
	updateEnemies = updateEnemies,
	clear = clear,
}