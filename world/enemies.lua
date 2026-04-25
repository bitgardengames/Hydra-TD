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

local POISON_TICK = 0.5 -- Seconds per poison tick

local EPS = 1e-6
local MAX_NUDGE = 10
local NUDGE_TARGET_DAMP = 8
local NUDGE_FOLLOW_DAMP = 24

local exp = math.exp
local min = math.min
local max = math.max
local sqrt = math.sqrt
local floor = math.floor
local upper = string.upper
local random = love.math.random

local nextID = 0
local INV_SPAWN_FADE_DUR = 1 / 0.12
local INV_EXIT_FADE_DUR = 1 / 0.10

local function swapRemove(list, i)
	local last = #list

	list[i] = list[last]
	list[last] = nil
end

local function updateEnemyPathPosition(e, pathWorld)
	local seg = e.pathSeg or 1
	local t = e.pathT or 0
	local pathCount = #pathWorld

	if pathCount <= 1 then
		e.x, e.y = 0, 0
		return
	end

	if seg >= pathCount then
		local p = pathWorld[pathCount]
		e.pathSeg = pathCount
		e.pathT = 0
		e.x, e.y = p[1], p[2]
		return
	end

	local a = pathWorld[seg]
	local b = pathWorld[seg + 1]
	e.pathSeg = seg
	e.pathT = t
	e.x = a[1] + (b[1] - a[1]) * t
	e.y = a[2] + (b[2] - a[2]) * t
end

local function advanceEnemyAlongPath(e, moveDist, pathWorld, totalLen)
	if moveDist <= EPS or e.dist >= totalLen then
		return false
	end

	local remaining = moveDist
	local seg = e.pathSeg or 1
	local t = e.pathT or 0
	local moved = false
	local pathCount = #pathWorld

	while remaining > EPS and seg < pathCount do
		local a = pathWorld[seg]
		local b = pathWorld[seg + 1]
		local dx = b[1] - a[1]
		local dy = b[2] - a[2]
		local segLen = sqrt(dx * dx + dy * dy)

		if segLen <= EPS then
			seg = seg + 1
			t = 0
		else
			local leftT = 1 - t
			local leftDist = segLen * leftT

			if remaining + EPS < leftDist then
				t = t + remaining / segLen
				remaining = 0
			else
				remaining = remaining - leftDist
				seg = seg + 1
				t = 0
			end

			moved = true
		end
	end

	if seg >= pathCount then
		seg = pathCount
		t = 0
	end

	e.pathSeg = seg
	e.pathT = t
	e.dist = min(totalLen, e.dist + moveDist)
	updateEnemyPathPosition(e, pathWorld)

	return moved
end

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

	local x, y

	if spawnX and spawnY then
		x, y = spawnX, spawnY
	else
		local startGX, startGY = MapMod.map.path[1][1], MapMod.map.path[1][2]
		x, y = MapMod.gridToCenter(startGX, startGY)
	end

	nextID = nextID + 1

	local e = {
		kind = kind,
		def = def,

		-- World position
		x = x,
		y = y,
		prevX = x,
		prevY = y,

		-- Path driver
		dist = 0,
		prevDist = 0,
		pathSeg = pathIndex or 1,
		pathT = 0,
		anchorX = x,
		anchorY = y,

		-- Velocity
		vx = 0,
		vy = 0,

		nudgeX = 0,
		nudgeY = 0,
		nudgeTargetX = 0,
		nudgeTargetY = 0,
		prevNudgeX = 0,
		prevNudgeY = 0,

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
		dying = false,
		deathT = 0,
		deathDur = 0.4,
		spawnFade = 0.12,
		exitFade = nil,
		alpha = 1,
		animT = 0,
		prevAnimT = 0,
		slowFactor = 1,
		slowTimer = 0,
		poisonStacks = 0,
		poisonTimer = 0,
		poisonTickTimer = 0,
		poisonDPS = 0,
		poisonMissingHpMult = 0,
		shadow = true,
		id = nextID,
		shockID = 0,

		face = "normal",
		faceT = 0,
		faceDur = 0,
	}

	updateEnemyPathPosition(e, MapMod.map.pathWorld)

	enemies[#enemies + 1] = e
end

local function updateEnemies(dt)
	local map = MapMod.map
	local pathWorld = map.pathWorld
	local totalLen = map.totalWorldLength
	local LastSecondThreshold = map.lastSecondThreshold
	local targetDecay = exp(-NUDGE_TARGET_DAMP * dt)
	local follow = 1 - exp(-NUDGE_FOLLOW_DAMP * dt)

	for i = #enemies, 1, -1 do
		local e = enemies[i]
		local isBoss = e.boss

		-- Spawn fade-in
		local spawnFade = e.spawnFade
		if spawnFade and spawnFade > 0 then
			spawnFade = spawnFade - dt

			if spawnFade < 0 then
				spawnFade = 0
			end

			e.spawnFade = spawnFade
		end

		local alphaIn = 1

		if spawnFade and spawnFade > 0 then
			alphaIn = 1 - (spawnFade * INV_SPAWN_FADE_DUR)
		end

		local alphaOut = 1
		local exitFade = e.exitFade

		if exitFade and exitFade > 0 then
			alphaOut = exitFade * INV_EXIT_FADE_DUR
		end

		e.alpha = min(alphaIn, alphaOut)

		-- Poison ticks
		if e.poisonStacks > 0 then
			e.poisonTimer = e.poisonTimer - dt
			e.poisonTickTimer = e.poisonTickTimer + dt

			if e.poisonTickTimer >= POISON_TICK then
				local ticks = floor(e.poisonTickTimer / POISON_TICK)
				e.poisonTickTimer = e.poisonTickTimer - ticks * POISON_TICK

				local poisonMult = (e.modifiers and e.modifiers.poison) or 1.0
				local baseDmg = e.poisonDPS * e.poisonStacks * poisonMult * POISON_TICK * ticks
				local missingFrac = 0
				if e.maxHp and e.maxHp > 0 then
					missingFrac = max(0, (e.maxHp - e.hp) / e.maxHp)
				end
				local missingBonus = 1 + (missingFrac * (e.poisonMissingHpMult or 0))
				local dmg = baseDmg * missingBonus

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
				e.poisonMissingHpMult = 0
			end
		end

		-- Infect: spread poison once on death
		if e._infectSpread and not e._infectDidSpread and e.hp <= 0 and e.poisonStacks and e.poisonStacks > 0 then
			e._infectDidSpread = true

			local radius = e._infectSpread.radius
			local stackMult = e._infectSpread.stackMult
			local radius2 = radius * radius
			local spreadStacks = floor(e.poisonStacks * stackMult)

			if spreadStacks > 0 then
				local nearby = Spatial.queryCells(e.x, e.y, radius)
				local nearbyCount = Spatial.queryCellsCount()

				for i = 1, nearbyCount do
					local other = nearby[i]

					if other ~= e and other.hp > 0 then
						local dx = other.x - e.x
						local dy = other.y - e.y

						if dx * dx + dy * dy <= radius2 then
							-- transfer poison, NOT damage
							other.poisonStacks = (other.poisonStacks or 0) + spreadStacks
							other.poisonDPS = max(other.poisonDPS or 0, e.poisonDPS or 0)
							other.poisonTimer = max(other.poisonTimer or 0, e.poisonTimer or 0)
							other.poisonMissingHpMult = max(other.poisonMissingHpMult or 0, e.poisonMissingHpMult or 0)
							other.poisonSource = e.poisonSource

							if e._infectSpread.loop == true then
								local spread = other._infectSpread
								if not spread then
									spread = {}
									other._infectSpread = spread
								end

								spread.radius = e._infectSpread.radius
								spread.stackMult = e._infectSpread.stackMult
								spread.loop = true
								spread.source = e.poisonSource
								other._infectDidSpread = false
							end
						end
					end
				end
			end

			Effects.spawnPoisonSplash(e.x, e.y)
		end

		-- Boss death hold (face shown, explosion delayed)
		if isBoss and e.dying then
			e.deathT = e.deathT - dt

			if e.deathT <= 0 then
				if e.lastHitTower then
					local killer = e.lastHitTower
					killer.kills = killer.kills + 1
					killer._killsStatName = killer._killsStatName or ("TOWER_" .. upper(killer.kind) .. "_KILLS")
					Achievements.increment(killer._killsStatName)
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

			if e.dist >= LastSecondThreshold then
				Achievements.unlock("LAST_SECOND")
			end

			-- Non-boss: immediate death
			if e.lastHitTower then
				local killer = e.lastHitTower
				killer.kills = killer.kills + 1
				killer._killsStatName = killer._killsStatName or ("TOWER_" .. upper(killer.kind) .. "_KILLS")
				Achievements.increment(killer._killsStatName)
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
		local slowTimer = e.slowTimer
		if slowTimer > 0 then
			slowTimer = slowTimer - dt

			if slowTimer <= 0 then
				slowTimer = 0
				e.slowDuration = 0
				e.slowFactor = 1.0
			end

			e.slowTimer = slowTimer
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

		-- Faces
		if e.face ~= "normal" then
			e.faceT = e.faceT + dt

			if e.faceT >= e.faceDur then
				e.face = "normal"
			end
		end

		-- store previous values for interpolation
		e.prevDist = e.dist
		e.prevX = e.x
		e.prevY = e.y
		e.prevNudgeX = e.nudgeX
		e.prevNudgeY = e.nudgeY

		-- advance along path
		local moved = advanceEnemyAlongPath(e, e.speed * dt, pathWorld, totalLen)

		-- visual-only nudge smoothing:
		-- 1) target eases back to path
		-- 2) rendered nudge follows target for softer hit finish
		e.nudgeTargetX = e.nudgeTargetX * targetDecay
		e.nudgeTargetY = e.nudgeTargetY * targetDecay
		e.nudgeX = e.nudgeX + (e.nudgeTargetX - e.nudgeX) * follow
		e.nudgeY = e.nudgeY + (e.nudgeTargetY - e.nudgeY) * follow

		-- gameplay queries use path position only
		if moved then
			Spatial.updateEnemy(e)
		end

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
				State.totalLeaks = State.totalLeaks + 1

				State.livesAnim = 1

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

	nextID = 0
end

local function applyHitImpulse(e, dx, dy, strength)
	local len2 = dx * dx + dy * dy

	if len2 <= EPS then
		return
	end

	local inv = 1 / sqrt(len2)

	e.nudgeTargetX = e.nudgeTargetX + dx * inv * strength
	e.nudgeTargetY = e.nudgeTargetY + dy * inv * strength

	local n2 = e.nudgeTargetX * e.nudgeTargetX + e.nudgeTargetY * e.nudgeTargetY

	if n2 > MAX_NUDGE * MAX_NUDGE then
		local s = MAX_NUDGE / sqrt(n2)
		e.nudgeTargetX = e.nudgeTargetX * s
		e.nudgeTargetY = e.nudgeTargetY * s
	end
end

return {
	enemies = enemies,
	EnemyDefs = EnemyDefs,
	findEnemyAt = findEnemyAt,
	spawnEnemy = spawnEnemy,
	updateEnemies = updateEnemies,
	applyHitImpulse = applyHitImpulse,
	clear = clear,
}
