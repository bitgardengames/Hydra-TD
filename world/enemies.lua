local Theme = require("core.theme")
local Sound = require("systems.sound")
local Util = require("core.util")
local State = require("core.state")
local Effects = require("world.effects")
local MapMod = require("world.map")
local Spatial = require("world.spatial_grid")
local EnemyDefs = require("world.enemy_defs")
local Floaters = require("ui.floaters")
local Achievements = require("systems.achievements")
local Towers = require("world.towers")
local L = require("core.localization")

local enemies = {}
local enemyPool = {}

local colorMoney = Theme.ui.money

local cmR, cmG, cmB = colorMoney[1], colorMoney[2], colorMoney[3]

local POISON_TICK = 0.5 -- Seconds per poison tick

local EPS = 1e-6
local BASE_MAX_NUDGE = 10
local MIN_NUDGE_DAMP = 5
local MAX_NUDGE_DAMP = 30
local NUDGE_TARGET_DAMP_MULT = 0.35
local NUDGE_FOLLOW_DAMP_MULT = 1.0
local MIN_NUDGE_RADIUS_SCALE = 0.85
local MAX_NUDGE_RADIUS_SCALE = 1.45
local NUDGE_RADIUS_REF = 16

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
local MAX_HIT_QUERY_RADIUS = 0

for _, def in pairs(EnemyDefs) do
	if def.radius and def.radius > MAX_HIT_QUERY_RADIUS then
		MAX_HIT_QUERY_RADIUS = def.radius
	end
end

local function swapRemove(list, i)
	local last = #list

	list[i] = list[last]
	list[last] = nil
end

local function acquireEnemy()
	local n = #enemyPool
	local e = enemyPool[n]

	if e then
		enemyPool[n] = nil
		return e
	end

	return {}
end

local function releaseEnemy(e)
	Util.clearTable(e)
	enemyPool[#enemyPool + 1] = e
end

local computeNudgeParams

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

local function advanceEnemyAlongPath(e, moveDist, pathWorld, pathSegLen, totalLen)
	if moveDist <= EPS or e.dist >= totalLen then
		return false
	end

	local remaining = moveDist
	local seg = e.pathSeg or 1
	local t = e.pathT or 0
	local moved = false
	local pathCount = #pathWorld

	while remaining > EPS and seg < pathCount do
		local segLen = pathSegLen[seg] or 0

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
	local candidates, candidateCount = Spatial.queryCellsLocal(x, y, MAX_HIT_QUERY_RADIUS, true)

	if candidateCount == 0 then
		return nil
	end

	for i = 1, candidateCount do
		local e = candidates[i]
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

	local e = acquireEnemy()

	e.kind = kind
	e.def = def

	-- World position
	e.x = x
	e.y = y
	e.prevX = x
	e.prevY = y

	-- Path driver
	e.dist = 0
	e.prevDist = 0
	e.pathSeg = pathIndex or 1
	e.pathT = 0
	e.anchorX = x
	e.anchorY = y

	-- Velocity
	e.vx = 0
	e.vy = 0

	e.nudgeX = 0
	e.nudgeY = 0
	e.nudgeTargetX = 0
	e.nudgeTargetY = 0
	e.prevNudgeX = 0
	e.prevNudgeY = 0

	e.boss = def.boss or false
	e.hpScale = hpScale
	e.spdScale = spdScale
	e.hp = (def.hp * hpScale) or 0
	e.maxHp = def.hp * hpScale
	e.baseSpeed = def.speed * spdScale
	e.speed = def.speed * spdScale
	e.reward = def.reward * (1.0 + State.wave * 0.01)
	e.score = def.score or 0
	e.radius = def.radius
	e.radius2 = def.radius * def.radius
	e.hitFlash = 0
	e.dying = false
	e.deathT = 0
	e.deathDur = 0.4
	e.spawnFade = 0.12
	e.exitFade = nil
	e.alpha = 1
	e.animT = 0
	e.prevAnimT = 0
	e.slowFactor = 1
	e.slowTimer = 0
	e.poisonStacks = 0
	e.poisonTimer = 0
	e.poisonTickTimer = 0
	e.poisonDPS = 0
	e.poisonMissingHpMult = 0
	e.poisonRamp = 1
	e.poisonRampPerTick = 0
	e.poisonRampMax = 1
	e.shadow = true
	e.id = nextID
	e.shockID = 0
	e.jamCooldown = def.jamCooldown or 0
	e.jamTimer = def.jamCooldown or 0
	e.jamPulseTimer = 0
	e.shieldTimer = def.shieldCooldown or 0
	e.shieldPulse = 0
	e.hasteTimer = 0
	e.hasteSpeedMultiplier = 1
	e.hasteMaxSpeedMult = def.hasteMaxSpeedMult or 1.7
	e.hasteCooldown = def.hasteCooldown or 0
	e.hastePulseTimer = 0
	e.hasteCastPulse = 0
	e.shieldHp = 0
	e.shieldMax = 0
	e.shieldExpire = 0
	e.shieldHitFlash = 0
	e.linkTimer = 0
	e.linkCooldown = def.linkCooldown or 0
	e.linkTarget = nil

	computeNudgeParams(e)

	e.face = "normal"
	e.faceT = 0
	e.faceDur = 0

	updateEnemyPathPosition(e, MapMod.map.pathWorld)

	enemies[#enemies + 1] = e

	if e.boss then
		State.activeBoss = e
		State.activeBossKind = e.kind
	end
end

local function handleEnemyKilled(e, i, isBoss)
	if isBoss then
		State.activeBoss = nil
		State.activeBossKind = nil
		Effects.spawnBossDeathExplosion(e.x, e.y, e.radius)
	else
		Effects.spawnEnemyDeath(e.x, e.y, e.radius)
	end

	if State.selectedEnemy == e then
		State.selectedEnemy = nil
	end

	local reward = floor(e.reward + 0.5)
	State.money = State.money + reward
	State.score = State.score + (e.score or 0)
	Floaters.add(e.x, e.y - 20, "+" .. reward, cmR, cmG, cmB, true)

	Achievements.increment("ENEMIES_KILLED")

	if isBoss then
		Achievements.increment("BOSSES_KILLED")
	end

	Spatial.removeEnemy(e)
	releaseEnemy(e)
	swapRemove(enemies, i)
end

local function handleEnemyEscaped(e, i, isBoss)
	if isBoss then
		State.activeBoss = nil
		State.activeBossKind = nil
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
	else
		State.lives = State.lives - 1
		State.waveLeaks = State.waveLeaks + 1
		State.totalLeaks = State.totalLeaks + 1
		State.livesAnim = 1
	end

	if State.selectedEnemy == e then
		State.selectedEnemy = nil
	end

	Spatial.removeEnemy(e)
	releaseEnemy(e)
	swapRemove(enemies, i)
end

computeNudgeParams = function(e)
	local speed = max(EPS, e.baseSpeed or 0)
	local speedTier = speed / (speed + 100)
	local baseDamp = MIN_NUDGE_DAMP + (MAX_NUDGE_DAMP - MIN_NUDGE_DAMP) * speedTier
	e.nudgeTargetK = baseDamp * NUDGE_TARGET_DAMP_MULT
	e.nudgeFollowK = baseDamp * NUDGE_FOLLOW_DAMP_MULT

	local radiusScale = (e.radius or NUDGE_RADIUS_REF) / NUDGE_RADIUS_REF
	radiusScale = min(MAX_NUDGE_RADIUS_SCALE, max(MIN_NUDGE_RADIUS_SCALE, radiusScale))
	local maxNudge = BASE_MAX_NUDGE * radiusScale
	e.maxNudge2 = maxNudge * maxNudge
end

local function updateEnemies(dt)
	local map = MapMod.map
	local pathWorld = map.pathWorld
	local pathSegLen = map.pathSegLen
	local totalLen = map.totalWorldLength
	local LastSecondThreshold = map.lastSecondThreshold
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
				local poisonRamp = e.poisonRamp or 1
				local poisonRampPerTick = e.poisonRampPerTick or 0
				local poisonRampMax = e.poisonRampMax or 1

				if poisonRampPerTick > 0 and poisonRamp < poisonRampMax then
					poisonRamp = min(poisonRamp + poisonRampPerTick * ticks, poisonRampMax)
					e.poisonRamp = poisonRamp
				end

				local poisonMult = (e.modifiers and e.modifiers.poison) or 1.0
				local baseDmg = e.poisonDPS * e.poisonStacks * poisonMult * poisonRamp * POISON_TICK * ticks
				local missingFrac = 0
				if e.maxHp and e.maxHp > 0 then
					missingFrac = max(0, (e.maxHp - e.hp) / e.maxHp)
				end
				local missingBonus = 1 + (missingFrac * (e.poisonMissingHpMult or 0))
				local dmg = baseDmg * missingBonus

				local leftover = absorbShieldDamage(e, dmg)
				e.hp = e.hp - leftover

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
				e.poisonRamp = 1
				e.poisonRampPerTick = 0
				e.poisonRampMax = 1
			end
		end

		-- Infect: spread poison once on death
		if e._infectSpread and not e._infectDidSpread and e.hp <= 0 and e.poisonStacks and e.poisonStacks > 0 then
			e._infectDidSpread = true

			local infect = e._infectSpread
			local radius = infect.radius
			local stackMult = infect.stackMult
			local radius2 = radius * radius
			local spreadStacks = floor(e.poisonStacks * stackMult)

			if spreadStacks > 0 then
				local ex, ey = e.x, e.y
				local sourcePoisonDPS = e.poisonDPS or 0
				local sourcePoisonTimer = e.poisonTimer or 0
				local sourcePoisonMissingHpMult = e.poisonMissingHpMult or 0
				local sourcePoisonRamp = e.poisonRamp or 1
				local sourcePoisonRampPerTick = e.poisonRampPerTick or 0
				local sourcePoisonRampMax = e.poisonRampMax or 1
				local poisonSource = e.poisonSource
				local nearby, nearbyCount = Spatial.queryCells(ex, ey, radius)

				for i = 1, nearbyCount do
					local other = nearby[i]

					if other ~= e and other.hp > 0 then
						local dx = other.x - ex
						local dy = other.y - ey

						if dx * dx + dy * dy <= radius2 then
							-- transfer poison, NOT damage
							other.poisonStacks = (other.poisonStacks or 0) + spreadStacks
							other.poisonDPS = max(other.poisonDPS or 0, sourcePoisonDPS)
							other.poisonTimer = max(other.poisonTimer or 0, sourcePoisonTimer)
							other.poisonMissingHpMult = max(other.poisonMissingHpMult or 0, sourcePoisonMissingHpMult)
							other.poisonRamp = max(other.poisonRamp or 1, sourcePoisonRamp)
							other.poisonRampPerTick = max(other.poisonRampPerTick or 0, sourcePoisonRampPerTick)
							other.poisonRampMax = max(other.poisonRampMax or 1, sourcePoisonRampMax)
							other.poisonSource = poisonSource

							if infect.loop == true then
								local spread = other._infectSpread
								if not spread then
									spread = {}
									other._infectSpread = spread
								end

								spread.radius = radius
								spread.stackMult = stackMult
								spread.loop = true
								spread.source = poisonSource
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

				handleEnemyKilled(e, i, isBoss)
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

			if e.lastHitTower then
				local killer = e.lastHitTower
				killer.kills = killer.kills + 1
				killer._killsStatName = killer._killsStatName or ("TOWER_" .. upper(killer.kind) .. "_KILLS")
				Achievements.increment(killer._killsStatName)
			end

			handleEnemyKilled(e, i, isBoss)

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

		local buffMult = (e.hasteTimer or 0) > 0 and (e.hasteSpeedMultiplier or 1) or 1
		local speedCap = e.baseSpeed * (e.hasteMaxSpeedMult or 1.7)
		e.speed = min(speedCap, e.baseSpeed * e.slowFactor * buffMult)
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


		if e.kind == "jammer" and e.jamCooldown > 0 then
			e.jamTimer = (e.jamTimer or e.jamCooldown) - dt
			e.jamPulseTimer = max(0, (e.jamPulseTimer or 0) - dt)
			if e.jamTimer <= 0 then
				e.jamTimer = e.jamCooldown
				e.jamPulseTimer = 0.35
				local affected = Towers.getTowersInRadius(e.x, e.y, e.def.jamRadius or 0)
				for j = 1, #affected do
					local t = affected[j]
					Towers.applyDisabled(t, e.def.jamDuration or 0, e.x, e.y)
					Effects.spawnZapLine(e.x, e.y, t.x, t.renderY or t.y)
					Floaters.add(t.x, (t.renderY or t.y) - 16, "⛔", 0.72, 0.95, 1.0)
				end
			end
		end

		if e.hasteTimer and e.hasteTimer > 0 then
			e.hasteTimer = max(0, e.hasteTimer - dt)
		end

		if e.kind == "overcharger" and e.hasteCooldown > 0 then
			e.hasteCastPulse = max(0, (e.hasteCastPulse or 0) - dt)
			e.hasteTimer = max(0, (e.hasteTimer or 0) - dt)
			e.hastePulseTimer = (e.hastePulseTimer or e.hasteCooldown) - dt
			if e.hastePulseTimer <= 0 then
				e.hastePulseTimer = e.hasteCooldown
				e.hasteCastPulse = 0.45
				Effects.spawnHastePulse(e.x, e.y, e.def.hasteRadius or 0)
				local nearby, count = Spatial.queryCells(e.x, e.y, e.def.hasteRadius or 0)
				local hasteDuration = e.def.hasteDuration or 0
				local hasteMultiplier = e.def.hasteSpeedMultiplier or 1
				for j = 1, count do
					local other = nearby[j]
					if other ~= e and other.hp > 0 then
						other.hasteTimer = max(other.hasteTimer or 0, hasteDuration)
						other.hasteSpeedMultiplier = max(other.hasteSpeedMultiplier or 1, hasteMultiplier)
						other.hasteMaxSpeedMult = max(other.hasteMaxSpeedMult or 1.7, e.def.hasteMaxSpeedMult or 1.7)
					end
				end
			end
		end


		if e.kind == "leech_beacon" then
			e.linkTimer = max(0, (e.linkTimer or 0) - dt)
			e.linkCooldown = max(0, (e.linkCooldown or e.def.linkCooldown or 0) - dt)
			local target = e.linkTarget
			local valid = target and (e.linkTimer or 0) > 0
			if valid then
				local dx = target.x - e.x
				local dy = target.y - e.y
				local r = e.def.linkRange or 0
				valid = target ~= nil and (dx * dx + dy * dy) <= (r * r)
			end
			if not valid then
				e.linkTarget = nil
				e.linkTimer = 0
			else
				Towers.applyLeechDebuff(target, e, dt + 0.12, e.def.fireRateMultiplier or 1)
			end

			if not e.linkTarget and e.linkCooldown <= 0 then
				local candidates = Towers.getTowersInRadius(e.x, e.y, e.def.linkRange or 0)
				local best, bestD2 = nil, 1e30
				for j = 1, #candidates do
					local t = candidates[j]
					local dx = t.x - e.x
					local dy = t.y - e.y
					local d2 = dx * dx + dy * dy
					if d2 < bestD2 then
						best = t
						bestD2 = d2
					end
				end
				if best then
					e.linkTarget = best
					e.linkTimer = e.def.linkDuration or 0
					e.linkCooldown = e.def.linkCooldown or 0
					Floaters.add(best.x, (best.renderY or best.y) - 18, "🜂", 0.95, 0.25, 0.95)
				end
			end
		end

		if e.kind == "projector" then
			e.shieldPulse = (e.shieldPulse or 0) + dt
			e.shieldTimer = (e.shieldTimer or e.def.shieldCooldown or 0) - dt
			if e.shieldTimer <= 0 then
				e.shieldTimer = e.def.shieldCooldown or 6.0
				local nearby, count = Spatial.queryCells(e.x, e.y, e.def.shieldRadius or 0)
				for j = 1, count do
					local other = nearby[j]
					if other ~= e and other.hp > 0 then
						other.shieldMax = e.def.shieldAmount or 0
						other.shieldHp = other.shieldMax
						other.shieldExpire = e.def.shieldDuration or 0
						other.shieldSource = e
					end
				end
			end
		end

		if (e.shieldHp or 0) > 0 then
			e.shieldExpire = (e.shieldExpire or 0) - dt
			if e.shieldExpire <= 0 then
				e.shieldHp = 0
				e.shieldExpire = 0
			end
		end
		if (e.shieldHitFlash or 0) > 0 then
			e.shieldHitFlash = max(0, e.shieldHitFlash - dt)
		end

		-- store previous values for interpolation
		e.prevDist = e.dist
		e.prevX = e.x
		e.prevY = e.y
		e.prevNudgeX = e.nudgeX
		e.prevNudgeY = e.nudgeY

		-- advance along path
		local moved = advanceEnemyAlongPath(e, e.speed * dt, pathWorld, pathSegLen, totalLen)

		-- visual-only nudge smoothing:
		-- 1) target eases back to path
		-- 2) rendered nudge follows target for softer hit finish
		local targetDecay = exp(-e.nudgeTargetK * dt)
		local follow = 1 - exp(-e.nudgeFollowK * dt)
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
					handleEnemyEscaped(e, i, isBoss)
					return
				end

				handleEnemyEscaped(e, i, isBoss)

				goto continue
			end
		end

		::continue::
	end



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
end

local function clear()
	for i = #enemies, 1, -1 do
		local e = enemies[i]

		Spatial.removeEnemy(e)
		releaseEnemy(e)
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

	if n2 > e.maxNudge2 then
		local s = sqrt(e.maxNudge2 / n2)
		e.nudgeTargetX = e.nudgeTargetX * s
		e.nudgeTargetY = e.nudgeTargetY * s
	end
end

local function absorbShieldDamage(e, amount)
	local shieldHp = e.shieldHp or 0
	if amount <= 0 or shieldHp <= 0 then
		return amount, 0
	end
	local absorbed = min(shieldHp, amount)
	e.shieldHp = shieldHp - absorbed
	e.shieldHitFlash = 0.08
	if e.shieldHp <= 0 then
		e.shieldHp = 0
		e.shieldExpire = 0
	end
	return amount - absorbed, absorbed
end

return {
	enemies = enemies,
	EnemyDefs = EnemyDefs,
	findEnemyAt = findEnemyAt,
	spawnEnemy = spawnEnemy,
	updateEnemies = updateEnemies,
	applyHitImpulse = applyHitImpulse,
	absorbShieldDamage = absorbShieldDamage,
	clear = clear,
}
