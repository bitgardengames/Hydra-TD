local Theme = require("core.theme")
local Util = require("core.util")
local State = require("core.state")
local Effects = require("world.effects")
local MapMod = require("world.map")
local Spatial = require("world.spatial_grid")
local hitQueryContext = Spatial.newQueryContext(true)
local enemyQueryContext = Spatial.newQueryContext(false)
local infectionVisitContext = {}
local EnemySupport = require("world.enemy_support")
local EnemyDefs = require("world.enemy_defs")
local Floaters = require("ui.floaters")
local Achievements = require("systems.achievements")
local L = require("core.localization")
local Save = require("core.save")
local RunStats = require("systems.run_stats")
local Difficulty = require("systems.difficulty")
local GameplayOutcome = require("systems.gameplay_outcome")
local EnemyPhase = require("world.enemy_phase")

local enemies = {}
local enemyPool = {}

local colorMoney = Theme.ui.money

local cmR, cmG, cmB = colorMoney[1], colorMoney[2], colorMoney[3]

local POISON_TICK = 0.5 -- Seconds per poison tick
local HIT_SQUASH_DUR = 0.12
local HEALTH_BAR_HIT_DURATION = 1.0
local MAX_ACTIVE_ENEMIES = 180

local EPS = 1e-6
local BASE_MAX_NUDGE = 10
local MIN_NUDGE_DAMP = 5
local MAX_NUDGE_DAMP = 30
local NUDGE_TARGET_DAMP_MULT = 0.35
local NUDGE_FOLLOW_DAMP_MULT = 1.0
local MIN_NUDGE_RADIUS_SCALE = 0.85
local MAX_NUDGE_RADIUS_SCALE = 1.45
local NUDGE_RADIUS_REF = 16

local min = math.min
local max = math.max
local sqrt = math.sqrt
local floor = math.floor
local upper = string.upper
local random = love.math.random

local nextID = 0
local EMPTY_SPAWN_OPTIONS = {}
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
	local supportAffected = e.supportAffected
	local supportContributions = e.supportContributions
	if supportAffected then Util.clearTable(supportAffected) end
	if supportContributions then Util.clearTable(supportContributions) end
	Util.clearTable(e)
	-- Retain the cleared membership maps on the pooled object so respawns do not
	-- allocate replacements.
	e.supportAffected = supportAffected
	e.supportContributions = supportContributions
	enemyPool[#enemyPool + 1] = e
end

local computeNudgeParams

Spatial.setEnemyLifecycleHooks(EnemySupport.onEnemyCellChanged, EnemySupport.onEnemyRemoved)

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

-- Move by path distance rather than by a single segment's interpolation. This
-- is shared by ordinary movement and instantaneous mechanics so neither can
-- skip corners, leave the spatial grid stale, or overshoot the exit.
local function advanceEnemyByDistance(e, moveDist, pathWorld, pathSegLen, totalLen)
	local map = MapMod.map
	pathWorld = pathWorld or map.pathWorld
	pathSegLen = pathSegLen or map.pathSegLen
	totalLen = totalLen or map.totalWorldLength
	local moved = advanceEnemyAlongPath(e, max(0, moveDist or 0), pathWorld, pathSegLen, totalLen)
	if moved then
		if e.supportSourceIndex then EnemySupport.markSourceDirty(e) end
		Spatial.updateEnemy(e)
	end
	return moved, e.dist >= totalLen
end

local function triggerHealthThresholds(e)
	local thresholds = e.healthThresholds
	if not e.lunge or type(thresholds) ~= "table" then return 0 end
	local crossed = 0
	while e.nextHealthThreshold <= #thresholds do
		local value = thresholds[e.nextHealthThreshold]
		if type(value) == "table" then value = value.hpFraction or value.fraction or value.hp end
		local thresholdHp = value and (value <= 1 and e.maxHp * value or value)
		if not thresholdHp or e.hp > thresholdHp then break end
		e.nextHealthThreshold = e.nextHealthThreshold + 1
		crossed = crossed + 1
	end
	if crossed > 0 then
		-- Queueing rule: every crossed threshold contributes exactly one lunge;
		-- simultaneous crossings play sequentially rather than being coalesced.
		e.lungesPending = e.lungesPending + crossed
		if not e.lungeWindup then
			e.lungeWindup = e.lunge.windupDuration
			e.lungeActiveThreshold = e.nextHealthThreshold - crossed
		end
	end
	return crossed
end

local function findEnemyAt(x, y)
	local candidates, candidateCount = Spatial.querySquareCandidatesLocal(x, y, MAX_HIT_QUERY_RADIUS, hitQueryContext)

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

local function spawnEnemy(kind, hpScale, spdScale, spawnX, spawnY, pathIndex, opts, pathDistance, pathT, summoned)
	local def = EnemyDefs[kind]
	opts = opts or EMPTY_SPAWN_OPTIONS
	assert(def, "unknown enemy kind: " .. tostring(kind))

	Save.markEnemyEncountered(kind)

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
	e.dist = pathDistance or opts.pathDistance or 0
	e.prevDist = 0
	e.pathSeg = pathIndex or 1
	e.pathT = pathT or opts.pathT or 0
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
	-- Optional authored health landmarks are consumed by the boss HUD. Keeping
	-- this opt-in avoids presenting arbitrary ticks as encounter phases.
	e.healthThresholds = def.healthThresholds or def.phaseThresholds
	e.lunge = def.lunge
	e.nextHealthThreshold = 1
	e.lungesPending = 0
	e.lungesCompleted = 0
	e.lungeWindup = nil
	e.lungeActiveThreshold = nil
	e.hpScale = hpScale
	e.spdScale = spdScale
	e.hp = (def.hp * hpScale) or 0
	e.maxHp = def.hp * hpScale
	e.baseSpeed = def.speed * spdScale
	e.speed = e.baseSpeed
	-- Kill income is the economic floor for imperfect play; wave number does not
	-- compound it independently of authored counts, compositions, or difficulty.
	e.reward = def.reward
	e.score = def.score or 0
	e.radius = def.radius
	e.radius2 = def.radius * def.radius
	e.hitFlash = 0
	-- Always initialize pooled instances: a prior occupant's recent-hit bar must
	-- never remain visible on a newly spawned, full-health enemy.
	e.healthBarHitTimer = 0
	e.hitSquash = 0
	e.hitSquashStrength = 1
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
	e.modifiers = def.modifiers
	e.armor = def.armor
	e.regeneration = def.regeneration
	e.regenDelay = 0
	e.regenVisualPulse = 0
	e.support = def.support
	e.summon = def.summon
	e.summonTimer = def.summon and (def.summon.initialDelay or def.summon.period) or 0
	e.summonPending = 0
	e.summonStaggerTimer = 0
	e.summonChildIndex = 0
	e.bossShield = def.bossShield
	e.bossShieldTimer = def.bossShield and (def.bossShield.initialDelay or def.bossShield.period) or 0
	e.bossShieldActive = false
	e.suppression = def.suppression
	e.suppressionTimer = def.suppression and (def.suppression.initialDelay or def.suppression.period) or 0
	e.suppressionCasts = 0
	e.enrage = def.enrage
	e.enraged = false
	EnemyPhase.initialize(e, def.phase)
	-- Precomputed authored capabilities keep absent optional mechanics off the hot path.
	e.hasPoisonModifier = def.modifiers ~= nil and def.modifiers.poison ~= nil
	e.hasRegeneration = def.regeneration ~= nil
	e.hasBossShield = def.bossShield ~= nil
	e.hasEnrage = def.enrage ~= nil
	e.hasSummon = def.summon ~= nil
	e.hasSupport = def.support ~= nil
	e.supportBoost = 1
	e.supportContributions = e.supportContributions or {}
	e.supportPulse = 0
	e.combatAge = 0
	-- Wave spawners opt authored enemies into the recap count after creation.
	-- Reset this on every pooled instance so summoned/procedural enemies cannot
	-- inherit the flag from an enemy that previously occupied the table.
	e.scheduledWaveEnemy = false
	e.summoned = summoned == true or opts.summoned == true

	computeNudgeParams(e)

	e.face = "normal"
	e.faceT = 0
	e.faceDur = 0

	updateEnemyPathPosition(e, MapMod.map.pathWorld)

	enemies[#enemies + 1] = e
	EnemySupport.register(e)
	Spatial.updateEnemy(e)

	if e.boss then
		State.activeBoss = e
		State.activeBossKind = e.kind
		Effects.shake(0, 0.35)
	end

	return e
end

local function handleEnemyKilled(e, i, isBoss)
	Save.recordEnemyResult(e.kind, "kill", e.combatAge)
	if isBoss then
		State.activeBoss = nil
		State.activeBossKind = nil
		Effects.spawnBossDeathExplosion(e.x, e.y, e.radius)
		Effects.shake(11, 0.45)
	else
		Effects.spawnEnemyDeath(e.x, e.y, e.radius)
	end

	if State.selectedEnemy == e then
		State.selectedEnemy = nil
	end

	local reward = e.reward
	State.money = State.money + reward
	State.score = State.score + (e.score or 0)
	State.totalKills = (State.totalKills or 0) + 1
	if e.scheduledWaveEnemy then
		State.spawnedKills = (State.spawnedKills or 0) + 1
	end
	Floaters.add(e.x, e.y - 20, "+" .. reward, cmR, cmG, cmB, true)

	Achievements.increment("ENEMIES_KILLED")

	if isBoss then
		Achievements.increment("BOSSES_KILLED")
	end

	require("systems.waves").onScheduledEnemyRemoved(e)
	Spatial.removeEnemy(e)
	releaseEnemy(e)
	swapRemove(enemies, i)
end

local function recordKiller(e)
	local killer = e.lastHitTower
	if not killer then
		return
	end

	killer.kills = killer.kills + 1
	killer._killsStatName = killer._killsStatName or ("TOWER_" .. upper(killer.kind) .. "_KILLS")
	Achievements.increment(killer._killsStatName)
	RunStats.recordKill(killer)
end

local function beginGameOver(reason)
	GameplayOutcome.defeat(reason)
end

local function handleEnemyEscaped(e, i, isBoss)
	require("systems.waves").onScheduledEnemyRemoved(e)
	Save.recordEnemyResult(e.kind, "leak")
	Effects.shake(isBoss and 12 or 5)
	if isBoss then
		State.activeBoss = nil
		State.activeBossKind = nil
		beginGameOver(L("game.bossBreach"))
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

local function incomingDamageMultiplier(e)
	if e.lungeWindup and e.lunge then
		return e.lunge.windupDamageMultiplier or 1
	end
	if e.bossShieldActive and e.bossShield then
		return e.bossShield.damageMultiplier
	end
	return 1
end

local function updatePoison(e, dt)
	if e.poisonStacks <= 0 then
		return
	end

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

		local missingFrac = e.maxHp and e.maxHp > 0 and max(0, (e.maxHp - e.hp) / e.maxHp) or 0
		local damage = e.poisonDPS * e.poisonStacks * ((e.modifiers and e.modifiers.poison) or 1)
			* poisonRamp * POISON_TICK * ticks * (1 + missingFrac * (e.poisonMissingHpMult or 0))
		damage = damage * incomingDamageMultiplier(e)
		e.hp = e.hp - damage
		triggerHealthThresholds(e)
		EnemySupport.detachDead(e)

		if e.poisonSource then
			e.poisonSource.damageDealt = e.poisonSource.damageDealt + damage
			e.lastHitTower = e.poisonSource
		end
		e.hitFlash = 0.03
		e.hitSquash = HIT_SQUASH_DUR
		e.hitSquashStrength = 0.55
		e.healthBarHitTimer = HEALTH_BAR_HIT_DURATION
		State.addDamage("poison", damage, e.boss == true)
		RunStats.recordDamage(e.poisonSource, damage)
	end

	if e.poisonTimer <= 0 then
		e.poisonTimer, e.poisonDuration, e.poisonStacks, e.poisonDPS = 0, 0, 0, 0
		e.poisonSource, e.poisonTickTimer, e.poisonMissingHpMult = nil, 0, 0
		e.poisonRamp, e.poisonRampPerTick, e.poisonRampMax = 1, 0, 1
	end
end

local function spreadInfectionVisitor(other, context)
	local source, infect = context.source, context.infect
	if other ~= source then
		other.poisonStacks = (other.poisonStacks or 0) + context.spreadStacks
		other.poisonDPS = max(other.poisonDPS or 0, source.poisonDPS or 0)
		other.poisonTimer = max(other.poisonTimer or 0, source.poisonTimer or 0)
		other.poisonMissingHpMult = max(other.poisonMissingHpMult or 0, source.poisonMissingHpMult or 0)
		other.poisonRamp = max(other.poisonRamp or 1, source.poisonRamp or 1)
		other.poisonRampPerTick = max(other.poisonRampPerTick or 0, source.poisonRampPerTick or 0)
		other.poisonRampMax = max(other.poisonRampMax or 1, source.poisonRampMax or 1)
		other.poisonSource = source.poisonSource

		if infect.loop == true then
			other._infectSpread = other._infectSpread or {}
			other._infectSpread.radius = infect.radius
			other._infectSpread.stackMult = infect.stackMult
			other._infectSpread.loop = true
			other._infectSpread.source = source.poisonSource
			other._infectDidSpread = false
		end
	end
end

local function spreadInfection(e)
	if not (e._infectSpread and not e._infectDidSpread and e.hp <= 0 and e.poisonStacks and e.poisonStacks > 0) then
		return
	end

	e._infectDidSpread = true
	local infect = e._infectSpread
	local spreadStacks = floor(e.poisonStacks * infect.stackMult)
	if spreadStacks > 0 then
		infectionVisitContext.source = e
		infectionVisitContext.infect = infect
		infectionVisitContext.spreadStacks = spreadStacks
		Spatial.visitRadius(e.x, e.y, infect.radius, spreadInfectionVisitor,
			infectionVisitContext, enemyQueryContext, Spatial.radiusOptions.living)
	end
	Effects.spawnPoisonSplash(e.x, e.y)
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

local function updateAuthoredTraits(e, dt)
	-- Stage 2: update timed statuses and optional authored traits.
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

	if e.hasRegeneration and e.regenDelay > 0 then
		e.regenDelay = max(0, e.regenDelay - dt)
	elseif e.hasRegeneration and e.poisonStacks <= 0 and e.hp < e.maxHp then
		e.hp = min(e.maxHp, e.hp + e.regeneration.hpPerSecond * e.hpScale * dt)
		e.regenVisualPulse = 0.28
	end

	-- Aegis alternates a short, obvious protection window with a longer opening.
	-- Ravager has just one threshold event, making its late sprint predictable.
	if e.hasBossShield then
		e.bossShieldTimer = e.bossShieldTimer - dt
		if e.bossShieldActive and e.bossShieldTimer <= 0 then
			e.bossShieldActive = false
			e.bossShieldTimer = max(EPS, e.bossShield.period - e.bossShield.duration)
		elseif not e.bossShieldActive and e.bossShieldTimer <= 0 then
			e.bossShieldActive = true
			e.bossShieldTimer = e.bossShield.duration
		end
	end
	if e.hasEnrage and not e.enraged and e.hp <= e.maxHp * e.enrage.healthFraction then
		e.enraged = true
		Effects.shake(4, 0.2)
	end
	EnemyPhase.update(e, dt)

	-- Summoned runners join at the caster's current path progress rather than at
	-- the map entrance. Release a cast's children over a short interval so they
	-- separate along the path instead of occupying exactly the same position.
	if e.hasSummon then
		e.summonTimer = e.summonTimer - dt
		if e.summonTimer <= 0 then
			local summon = e.summon
			e.summonTimer = summon.period
			local availableSlots = max(0, MAX_ACTIVE_ENEMIES - #enemies - e.summonPending)
			local queued = min(summon.count, availableSlots)
			if e.summonPending == 0 and queued > 0 then
				e.summonStaggerTimer = 0
			end
			e.summonPending = e.summonPending + queued
			Effects.shake(2.4)
		end

		if e.summonPending > 0 then
			e.summonStaggerTimer = e.summonStaggerTimer - dt
			if e.summonStaggerTimer <= 0 and #enemies < MAX_ACTIVE_ENEMIES then
				local summon = e.summon
				local child = spawnEnemy(summon.kind, e.hpScale, e.spdScale, e.x, e.y,
					e.pathSeg, nil, e.dist, e.pathT, true)
				e.summonChildIndex = e.summonChildIndex + 1
				local side = e.summonChildIndex % 2 == 0 and 1 or -1
				child.nudgeTargetY = side * (summon.spacing or 0)
				child.nudgeY = child.nudgeTargetY
				e.summonPending = e.summonPending - 1
				e.summonStaggerTimer = e.summonStaggerTimer + (summon.stagger or 0)
			end
		end
	end
end

local function updateGatecrasherLunge(e, dt, pathWorld, pathSegLen, totalLen)
	if not e.lungeWindup then return false end
	e.lungeWindup = e.lungeWindup - dt
	if e.lungeWindup > 0 then return false end

	local oldX, oldY = e.x, e.y
	local _, reachedExit = advanceEnemyByDistance(e, e.lunge.distance, pathWorld, pathSegLen, totalLen)
	e.lungesPending = max(0, e.lungesPending - 1)
	e.lungesCompleted = e.lungesCompleted + 1
	Effects.spawnGatecrasherLunge(oldX, oldY, e.x, e.y, e.radius)
	Effects.shake(5, 0.18)
	if e.lungesPending > 0 and not reachedExit then
		e.lungeWindup = e.lunge.windupDuration
		e.lungeActiveThreshold = e.nextHealthThreshold - e.lungesPending
	else
		e.lungeWindup = nil
		e.lungeActiveThreshold = nil
	end
	return reachedExit
end

local function updateEnemies(dt)
	local map = MapMod.map
	local pathWorld = map.pathWorld
	local pathSegLen = map.pathSegLen
	local totalLen = map.totalWorldLength
	local LastSecondThreshold = map.lastSecondThreshold
	-- Aura definitions may be replaced or tuned at runtime. Only changed sources
	-- need to refresh their retained affected-enemy membership.
	EnemySupport.update(dt)
	for i = #enemies, 1, -1 do
		local e = enemies[i]
		e.combatAge = (e.combatAge or 0) + dt
		local isBoss = e.boss

		-- Stage 1: resolve damage-over-time and death.
		if e.poisonStacks > 0 then
			updatePoison(e, dt)
			spreadInfection(e)
		end

		-- Boss death hold (face shown, explosion delayed)
		if isBoss and e.dying then
			e.deathT = e.deathT - dt

			if e.deathT <= 0 then
				recordKiller(e)

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

			recordKiller(e)

			handleEnemyKilled(e, i, isBoss)

			goto continue
		end

		-- Stage 2: update timed statuses and optional authored traits.
		updateAuthoredTraits(e, dt)
		updateGatecrasherLunge(e, dt, pathWorld, pathSegLen, totalLen)
		-- Stage 3: compute the effective movement speed.
		local enrageSpeed = e.enraged and e.enrage.speedMultiplier or 1
		local phaseSpeed = EnemyPhase.movementMultiplier(e)
		e.speed = e.baseSpeed * e.slowFactor * e.supportBoost * enrageSpeed * phaseSpeed

		-- Stage 4: advance gameplay path state and update the spatial index.
		-- Store previous values for interpolation
		e.prevDist = e.dist
		e.prevX = e.x
		e.prevY = e.y

		-- advance along path
		advanceEnemyByDistance(e, e.speed * dt, pathWorld, pathSegLen, totalLen)

		-- Stage 5: presentation timers/impulses are advanced by enemy_render_state.

		-- Stage 6: resolve escape removal.
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

	-- Spatial lifecycle hooks have now seen every movement/removal for this tick.
	-- Sim flushes their deduplicated support-source work before tower targeting.

	if State.lives <= 0 then
		beginGameOver(L("game.outOfLives"))
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
	EnemySupport.clear()
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

-- Single damage gateway for traits. The second return value reports mitigation.
local function applyDamage(e, amount, context)
	if not e or e.hp <= 0 or amount <= 0 then return 0, 0 end
	context = context or {}
	local raw = amount
	amount = amount * incomingDamageMultiplier(e)
	if e.armor then
		local heavy = context.sourceKind == "cannon" or context.sourceKind == "lancer"
			or raw >= (e.armor.heavyThreshold or math.huge)
		if heavy then amount = amount * (e.armor.heavyMultiplier or 1)
		else amount = max(1, amount - (e.armor.flatReduction or 0)) end
	end
	e.hp = e.hp - amount
	triggerHealthThresholds(e)
	EnemySupport.detachDead(e)
	if amount > 0 then
		e.hitSquash = HIT_SQUASH_DUR
		e.hitSquashStrength = 1
		e.healthBarHitTimer = HEALTH_BAR_HIT_DURATION
	end
	if e.regeneration then e.regenDelay = e.regeneration.delay end
	e.lastDamageSourceKind = context.sourceKind
	return amount, 0
end

local function setPathDistance(e, distance)
	local map = MapMod.map
	local lengths = map.pathSegLen or {}
	local path = map.pathWorld or {}
	distance = max(0, min(map.totalWorldLength or distance, distance))
	local remaining, seg = distance, 1
	while seg < #path and remaining > (lengths[seg] or 0) do remaining = remaining - (lengths[seg] or 0); seg = seg + 1 end
	e.dist, e.pathSeg = distance, seg
	local len = lengths[seg] or 0
	e.pathT = len > EPS and min(1, remaining / len) or 0
	updateEnemyPathPosition(e, path)
	Spatial.updateEnemy(e)
end

-- Produces the player-facing, render-agnostic description of every currently
-- active enemy state. Identity traits deliberately do not
-- belong here: callers can therefore present expiring state separately from the
-- mechanics that define an enemy.
local function getDisplayStatuses(e)
	local result = {}
	if not e then return result end

	local function add(labelKey, icon, color, options)
		options = options or {}
		result[#result + 1] = {
			id = options.id,
			label = L(labelKey),
			icon = icon,
			color = color,
			stacks = options.stacks,
			value = options.value,
			remainingFraction = options.remainingFraction,
		}
	end

	local function fraction(remaining, duration)
		if not remaining or not duration or duration <= 0 then return nil end
		return max(0, min(1, remaining / duration))
	end

	if (e.slowTimer or 0) > 0 then
		add("status.slow", "▼", Theme.tower.slow, {
			id = "slow", remainingFraction = fraction(e.slowTimer, e.slowDuration),
		})
	end
	if (e.poisonTimer or 0) > 0 and (e.poisonStacks or 0) > 0 then
		add("status.poison", "●", Theme.tower.poison, {
			id = "poison", stacks = e.poisonStacks,
			remainingFraction = fraction(e.poisonTimer, e.poisonDuration),
		})
	end
	if (e.supportBoost or 1) > 1 then
		add("status.supportBoost", "▲", Theme.ui.good, {
			id = "support_boost", value = L("status.multiplier", e.supportBoost),
		})
	end
	if e.regeneration and (e.regenDelay or 0) > 0 then
		add("status.regenerationSuppressed", "⊘", Theme.ui.bad, {
			id = "regeneration_suppressed",
			remainingFraction = fraction(e.regenDelay, e.regeneration.delay),
		})
	end
	if e.summon and (e.summonTimer or 0) > 0 then
		add("status.summonPreparing", "✦", Theme.ui.money, {
			id = "summon_preparing",
			remainingFraction = fraction(e.summonTimer, e.summon.period),
		})
	end
	if e.phaseActive then
		add("status.phased", "◌", Theme.tower.slow, {
			id = "phased", remainingFraction = fraction(e.phaseTimer, e.phase.duration),
		})
	end

	return result
end

local function applySlow(e, factor, duration)
	if not e or e.hp <= 0 then return false end
	local newFactor = math.max(0, math.min(1, factor))
	if not e.slowFactor or newFactor < e.slowFactor then e.slowFactor = newFactor end
	e.slowTimer = math.max(e.slowTimer or 0, duration or 0)
	e.slowDuration = math.max(e.slowDuration or 0, duration or 0)
	return true
end

return {
	enemies = enemies,
	EnemyDefs = EnemyDefs,
	findEnemyAt = findEnemyAt,
	spawnEnemy = spawnEnemy,
	updateEnemies = updateEnemies,
	applyHitImpulse = applyHitImpulse,
	applyDamage = applyDamage,
	applySlow = applySlow,
	getDisplayStatuses = getDisplayStatuses,
	advanceEnemyByDistance = advanceEnemyByDistance,
	triggerHealthThresholds = triggerHealthThresholds,
	setPathDistance = setPathDistance,
	clear = clear,
}
