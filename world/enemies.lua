local Theme = require("core.theme")
local Constants = require("core.constants")
local Sound = require("systems.sound")
local Util = require("core.util")
local State = require("core.state")
local Effects = require("world.effects")
local MapMod = require("world.map")
local Spatial = require("world.spatial_grid")
local EnemyDefs = require("world.enemy_defs")
local Floaters = require("ui.floaters")
local DifficultyCurve = require("systems.difficulty_curve")
local Steam = require("core.steam")
local Achievements = require("systems.achievements")
local L = require("core.localization")

local enemies = {}

local colorMoney = Theme.ui.money

local cmR, cmG, cmB = colorMoney[1], colorMoney[2], colorMoney[3]

local POISON_TICK = 0.5 -- seconds per poison tick
local EPS = 0.0001

local abs = math.abs
local min = math.min
local max = math.max
local sqrt = math.sqrt
local floor = math.floor
local upper = string.upper

local function swapRemove(list, i)
	local last = #list

	list[i] = list[last]
	list[last] = nil
end

local sampleFast = MapMod.sampleFast

local function findEnemyAt(x, y)
	for i = 1, #enemies do
		local e = enemies[i]
		local dx = x - e.x
		local dy = y - e.y

		if dx * dx + dy * dy <= e.radius2 then
			return e
		end
	end

	return nil
end

local function spawnEnemy(kind, hpScale, spdScale, spawnX, spawnY, pathIndex, opts)
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
		prevX = x,
		prevY = y,
		boss = def.boss or false,
		hpScale = hpScale,
		spdScale = spdScale,
		hp = def.hp * hpScale,
		maxHp = def.hp * hpScale,
		baseSpeed = def.speed * spdScale,
		speed = def.speed * spdScale,
		reward = def.reward * (1.0 + State.wave * 0.01),
		score = def.score,
		radius = def.radius,
		radius2 = def.radius * def.radius,
		hitFlash = 0,
		hitOffsetX = 0,
		hitOffsetY = 0,
		hitVelX = 0,
		hitVelY = 0,
		dying = false,
		deathT = 0,
		deathDur = 0.4,
		spawnFade = 0.12,
		exitFade = nil,
		alpha = 1,
		animT = 0,
		prevAnimT = 0,
		dist = 0,
		prevDist = 0,
		modifiers = def.modifiers,
		slowFactor = 1,
		slowTimer = 0,
		poisonStacks = 0,
		poisonTimer = 0,
		poisonDPS = 0,
		shadow = true,
	}

	if e.boss then
		State.activeBoss = e
	end

	enemies[#enemies + 1] = e
end

local function updateEnemies(dt)
	local map = MapMod.map
	local path = map.path
	local pathWorld = map.pathWorld
	local pathDist = map.pathDist
	local totalLen = map.totalWorldLength
	local pathLen = #path

	for i = #enemies, 1, -1 do
		local e = enemies[i]
		local isBoss = e.boss

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

			if e.poisonTickTimer >= POISON_TICK then
				local ticks = floor(e.poisonTickTimer / POISON_TICK)
				e.poisonTickTimer = e.poisonTickTimer - ticks * POISON_TICK

				local poisonMult = (e.modifiers and e.modifiers.poison) or 1.0
				local dmg = e.poisonDPS * e.poisonStacks * poisonMult * POISON_TICK * ticks

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

					local statName = "TOWER_" .. upper(e.lastHitTower.kind) .. "_KILLS"

					Achievements.increment(statName)
				end

				Achievements.increment("BOSSES_KILLED")
				Achievements.increment("ENEMIES_KILLED") -- Bosses still count as an enemy

				local reward = floor(e.reward + 0.5)

				State.money = State.money + reward
				State.score = State.score + e.score

				Floaters.add(e.x, e.y - 20, "+" .. reward, cmR, cmG, cmB, true)

				--Effects.spawnEnemyDeath(e.x, e.y, e.radius)

				State.activeBoss = nil
				Effects.spawnBossDeathExplosion(e.x, e.y, e.radius)

				Spatial.removeEnemy(e)

				swapRemove(enemies, i)
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

				local statName = "TOWER_" .. upper(e.lastHitTower.kind) .. "_KILLS"

				Achievements.increment(statName)
			end

			Achievements.increment("ENEMIES_KILLED")

			if State.selectedEnemy == e then
				State.selectedEnemy = nil
			end

			local reward = floor(e.reward + 0.5)

			State.money = State.money + reward
			State.score = State.score + e.score

			Floaters.add(e.x, e.y - 20, "+" .. reward, cmR, cmG, cmB, true)

			Effects.spawnEnemyDeath(e.x, e.y, e.radius)

			Spatial.removeEnemy(e)

			swapRemove(enemies, i)

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
		e.prevAnimT = e.animT
		e.animT = e.animT + dt * e.speed * 0.03

		-- Hit flash
		if e.hitFlash > 0 then
			e.hitFlash = e.hitFlash - dt

			if e.hitFlash < 0 then
				e.hitFlash = 0
			end
		end

		-- Hit offset (impulse + critically damped return)
		e.hitVelX = e.hitVelX or 0
		e.hitVelY = e.hitVelY or 0
		e.hitOffsetX = e.hitOffsetX or 0
		e.hitOffsetY = e.hitOffsetY or 0

		e.prevHitOffsetX = e.hitOffsetX
		e.prevHitOffsetY = e.hitOffsetY

		-- Integrate velocity
		e.hitOffsetX = e.hitOffsetX + e.hitVelX
		e.hitOffsetY = e.hitOffsetY + e.hitVelY

		-- damping (kills energy)
		local damping = 0.9
		e.hitVelX = e.hitVelX * damping
		e.hitVelY = e.hitVelY * damping

		-- soft return to center
		local returnStrength = 0.2
		e.hitOffsetX = e.hitOffsetX * (1 - returnStrength)
		e.hitOffsetY = e.hitOffsetY * (1 - returnStrength)

		-- deadzone
		if abs(e.hitOffsetX) < 0.01 then e.hitOffsetX = 0 end
		if abs(e.hitOffsetY) < 0.01 then e.hitOffsetY = 0 end
		if abs(e.hitVelX) < 0.01 then e.hitVelX = 0 end
		if abs(e.hitVelY) < 0.01 then e.hitVelY = 0 end

		-- Store previous position for interpolation
		e.prevX = e.x
		e.prevY = e.y

		-- Store previous distance/segment (render will interpolate distance, then sample)
		e.prevDist = e.dist
		e.dist = e.dist + e.speed * dt

		if e.dist > map.totalWorldLength then
			e.dist = map.totalWorldLength
		end

		e.x, e.y = sampleFast(e.dist)

		Spatial.updateEnemy(e)

		-- Reached end of path
		if e.dist >= totalLen then
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

					Achievements.onGameOver()

					State.mode = "game_over"

					State.endT = 0
					State.endReady = false
					State.endTitle = L("game.gameOver")
					State.endReason = L("game.bossBreach")

					Sound.play("gameOver")
					Sound.playMusic("gameOver")

					return
				end

				State.lives = State.lives - 1
				State.waveLeaks = State.waveLeaks + 1

				local livesAnim = State.livesAnim or 0
				State.livesAnim = livesAnim + (1 - livesAnim) * 0.6

				--Floaters.add(e.x, e.y - 10, "-1", colorBad[1], colorBad[2], colorBad[3])

				Spatial.removeEnemy(e)

				swapRemove(enemies, i)

				if State.lives <= 0 then
					State.lives = 0
					State.gameOver = true
					State.victory = false

					Achievements.onGameOver()

					State.mode = "game_over"

					State.endT = 0
					State.endReady = false
					State.endTitle = L("game.gameOver")
					State.endReason = L("game.outOfLives")

					Sound.play("gameOver")
					Sound.playMusic("gameOver")
				end

				goto continue
			end
		end

		::continue::
	end
end

local function clear()
	for i = #enemies, 1, -1 do
		local e = enemies[i]

		Spatial.removeEnemy(e)
		enemies[i] = nil
	end
end

return {
	enemies = enemies,
	EnemyDefs = EnemyDefs,
	findEnemyAt = findEnemyAt,
	spawnEnemy = spawnEnemy,
	updateEnemies = updateEnemies,
	clear = clear,
}