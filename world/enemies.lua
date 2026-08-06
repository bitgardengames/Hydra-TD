local Theme = require("core.theme")
local Sound = require("systems.sound")
local Util = require("core.util")
local State = require("core.state")
local Effects = require("world.effects")
local MapMod = require("world.map")
local Spatial = require("world.spatial_grid")
local EnemyDefs = require("world.enemy_defs")
local EnemyAffixDefs = require("world.enemy_affix_defs")
local Floaters = require("ui.floaters")
local Achievements = require("systems.achievements")
local L = require("core.localization")
local Save = require("core.save")
local Onboarding = require("systems.onboarding")
local RunStats = require("systems.run_stats")
local Difficulty = require("systems.difficulty")

local enemies = {}
local enemyPool = {}

local colorMoney = Theme.ui.money

local cmR, cmG, cmB = colorMoney[1], colorMoney[2], colorMoney[3]

local POISON_TICK = 0.5 -- Seconds per poison tick
local HIT_SQUASH_DUR = 0.12

local EPS = 1e-6
local BASE_MAX_NUDGE = 10
local NUDGE_IDLE_EPS = 1e-3
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
local supportSources = {}
local supportSourceCount = 0

local function removeSupportContribution(source, target)
	local contributions = target.supportContributions
	if contributions then
		contributions[source.id] = nil
	end
	if source.supportAffected then
		source.supportAffected[target] = nil
	end
end

local function recomputeSupportBoost(target)
	local boost = 1
	local contributions = target.supportContributions
	if contributions then
		for sourceID, contribution in pairs(contributions) do
			local source = contribution.source
			if not source or source.id ~= sourceID or source.hp <= 0 or source._supportRemoved then
				contributions[sourceID] = nil
				if source and source.supportAffected then
					source.supportAffected[target] = nil
				end
			else
				boost = max(boost, contribution.multiplier)
			end
		end
	end
	target.supportBoost = boost
end

local function clearSupportSource(source, removed)
	local affected = source.supportAffected
	if affected then
		for target in pairs(affected) do
			removeSupportContribution(source, target)
			recomputeSupportBoost(target)
		end
	end
	source._supportRemoved = removed == true
	source._supportAura = source.support
	source._supportRadius = source.support and source.support.radius or nil
	source._supportMultiplier = source.support and source.support.speedMultiplier or nil
end

local function removeSupportSource(source)
	clearSupportSource(source, true)
	local index = source.supportSourceIndex
	if index then
		local last = supportSources[supportSourceCount]
		supportSources[index] = last
		supportSources[supportSourceCount] = nil
		supportSourceCount = supportSourceCount - 1
		if last and last ~= source then
			last.supportSourceIndex = index
		end
		source.supportSourceIndex = nil
	end
end

local function removeDeadSupportSource(source)
	if source.supportSourceIndex and source.hp <= 0 then
		-- Damage can happen while updateEnemies is walking the enemy list. Detach
		-- the source now so targets on either side of it in the reverse walk see
		-- the same boost state.
		removeSupportSource(source)
	end
end

local function updateSupportSource(source)
	local aura = source.support
	if not aura or source.hp <= 0 or source._supportRemoved then
		clearSupportSource(source, source._supportRemoved or source.hp <= 0)
		return
	end

	local affected = source.supportAffected
	for target in pairs(affected) do
		affected[target] = false
	end
	local nearby, count = Spatial.queryCells(source.x, source.y, aura.radius)
	for i = 1, count do
		local target = nearby[i]
		if target ~= source and target.hp > 0 then
			affected[target] = true
			local contributions = target.supportContributions
			if not contributions then
				contributions = {}
				target.supportContributions = contributions
			end
			local contribution = contributions[source.id]
			if not contribution then
				contribution = {source = source}
				contributions[source.id] = contribution
			end
			contribution.multiplier = aura.speedMultiplier
			recomputeSupportBoost(target)
		end
	end
	for target, present in pairs(affected) do
		if not present then
			removeSupportContribution(source, target)
			recomputeSupportBoost(target)
		end
	end
	source._supportAura = aura
	source._supportRadius = aura.radius
	source._supportMultiplier = aura.speedMultiplier
end

local function syncSupportSourceDefinition(source)
	local aura = source.def.support
	if aura ~= source.support then
		source.support = aura
	end
	if source.hp <= 0 then
		removeDeadSupportSource(source)
	elseif aura ~= source._supportAura or (aura and (aura.radius ~= source._supportRadius
		or aura.speedMultiplier ~= source._supportMultiplier)) then
		updateSupportSource(source)
	end
end

local function sourceTouchesCell(source, cx, cy)
	local aura = source.support
	if not aura or cx == nil then return false end
	return Spatial.queryIncludesCell(source.x, source.y, aura.radius, cx, cy)
end

local function onEnemyCellChanged(e, oldCX, oldCY, newCX, newCY)
	if e.supportSourceIndex then
		syncSupportSourceDefinition(e)
	end
	if e.supportSourceIndex then
		updateSupportSource(e)
	end
	local i = 1
	while i <= supportSourceCount do
		local source = supportSources[i]
		syncSupportSourceDefinition(source)
		if source.supportSourceIndex and source ~= e
			and (sourceTouchesCell(source, oldCX, oldCY) or sourceTouchesCell(source, newCX, newCY)) then
			updateSupportSource(source)
		end
		if supportSources[i] == source then i = i + 1 end
	end
end

local function onEnemyRemoved(e, oldCX, oldCY)
	if e.supportSourceIndex then
		removeSupportSource(e)
	end
	local i = 1
	while i <= supportSourceCount do
		local source = supportSources[i]
		syncSupportSourceDefinition(source)
		if source.supportSourceIndex and sourceTouchesCell(source, oldCX, oldCY) then
			updateSupportSource(source)
		end
		if supportSources[i] == source then i = i + 1 end
	end
	local contributions = e.supportContributions
	if contributions then
		for _, contribution in pairs(contributions) do
			local source = contribution.source
			if source and source.supportAffected then source.supportAffected[e] = nil end
		end
		Util.clearTable(contributions)
	end
end

Spatial.setEnemyLifecycleHooks(onEnemyCellChanged, onEnemyRemoved)

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
	opts = opts or {}

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
	e.affixes = {}
	e.affixById = {}
	local hpAffixMult, speedAffixMult, rewardAffixMult = 1, 1, 1
	for _, id in ipairs(opts.affixes or {}) do
		local affix = EnemyAffixDefs[id]
		if affix and not e.affixById[id] then
			e.affixes[#e.affixes + 1] = affix
			e.affixById[id] = affix
			local behavior = affix.behavior or {}
			hpAffixMult = hpAffixMult * (behavior.hpMultiplier or 1)
			speedAffixMult = speedAffixMult * (behavior.speedMultiplier or 1)
			rewardAffixMult = rewardAffixMult * (behavior.rewardMultiplier or 1)
			Save.markAffixEncountered(id)
		end
	end
	e.elite = #e.affixes > 0

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
	e.hp = (def.hp * hpScale * hpAffixMult) or 0
	e.maxHp = def.hp * hpScale * hpAffixMult
	e.baseSpeed = def.speed * spdScale * speedAffixMult
	e.speed = e.baseSpeed
	-- Kill income is the economic floor for imperfect play; wave number does not
	-- compound it independently of authored counts and compositions.
	e.reward = def.reward * Difficulty.get().rewardBias * rewardAffixMult
	e.score = def.score or 0
	e.radius = def.radius
	e.radius2 = def.radius * def.radius
	e.hitFlash = 0
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
	e.shieldDef = def.shield
	e.shieldMax = def.shield and def.shield.hp * hpScale or 0
	e.shieldHp = e.shieldMax
	e.shieldBreakFlash = 0
	e.support = def.support
	e.supportBoost = 1
	e.supportContributions = e.supportContributions or {}
	e.supportPulse = 0
	e.combatAge = 0

	computeNudgeParams(e)

	e.face = "normal"
	e.faceT = 0
	e.faceDur = 0

	updateEnemyPathPosition(e, MapMod.map.pathWorld)

	enemies[#enemies + 1] = e
	if e.support then
		e.supportAffected = e.supportAffected or {}
		e._supportRemoved = false
		supportSourceCount = supportSourceCount + 1
		supportSources[supportSourceCount] = e
		e.supportSourceIndex = supportSourceCount
	end
	Spatial.updateEnemy(e)

	if e.boss then
		State.activeBoss = e
		State.activeBossKind = e.kind
		Effects.trigger("boss_entrance", {intensity = 4, shake = 7, duration = 0.35, hitStop = 0.06, criticalTell = true})
	end
end

local function handleEnemyKilled(e, i, isBoss)
	Save.recordEnemyResult(e.kind, "kill", e.combatAge)
	if isBoss then
		State.activeBoss = nil
		State.activeBossKind = nil
		Effects.spawnBossDeathExplosion(e.x, e.y, e.radius)
		Effects.trigger("boss_defeat", {intensity = 4, shake = 11, duration = 0.45, hitStop = 0.10})
	else
		Effects.spawnEnemyDeath(e.x, e.y, e.radius)
	end

	if State.selectedEnemy == e then
		State.selectedEnemy = nil
	end

	local reward = floor(e.reward + 0.5)
	State.money = State.money + reward
	RunStats.recordIncome(reward, "kill")
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
	Save.recordEnemyResult(e.kind, "leak")
	RunStats.recordLeak(e.kind)
	Effects.trigger("enemy_leak", {intensity = isBoss and 4 or 3, shake = isBoss and 12 or 5, hitStop = isBoss and 0.10 or 0.04})
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
		Onboarding.event("enemy_leaked")
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
	-- Aura definitions may be replaced or tuned at runtime. Only changed sources
	-- need to refresh their retained affected-enemy membership.
	local supportIndex = 1
	while supportIndex <= supportSourceCount do
		local source = supportSources[supportIndex]
		syncSupportSourceDefinition(source)
		local aura = source.support
		if aura and source.hp > 0 then
			source.supportPulse = ((source.supportPulse or 0) + dt) % aura.pulsePeriod
		end
		if supportSources[supportIndex] == source then supportIndex = supportIndex + 1 end
	end
	for i = #enemies, 1, -1 do
		local e = enemies[i]
		e.combatAge = (e.combatAge or 0) + dt
		local isBoss = e.boss
		e.hitSquash = max(0, (e.hitSquash or 0) - dt)

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

				e.hp = e.hp - dmg
				removeDeadSupportSource(e)

				if e.poisonSource then
					e.poisonSource.damageDealt = e.poisonSource.damageDealt + dmg
					e.lastHitTower = e.poisonSource
				end

				e.hitFlash = 0.03
				e.hitSquash = HIT_SQUASH_DUR
				e.hitSquashStrength = 0.55

				State.addDamage("poison", dmg, e.boss == true)
				RunStats.recordDamage(e.poisonSource, "poison", dmg)
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
					RunStats.recordKill(killer)
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
				RunStats.recordKill(killer)
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

		if e.regenDelay and e.regenDelay > 0 then
			e.regenDelay = max(0, e.regenDelay - dt)
		elseif e.regeneration and e.poisonStacks <= 0 and e.hp < e.maxHp then
			e.hp = min(e.maxHp, e.hp + e.regeneration.hpPerSecond * e.hpScale * dt)
		end
		if e.shieldBreakFlash > 0 then e.shieldBreakFlash = max(0, e.shieldBreakFlash - dt) end

		e.speed = e.baseSpeed * e.slowFactor * e.supportBoost
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
		local moved = advanceEnemyAlongPath(e, e.speed * dt, pathWorld, pathSegLen, totalLen)

		-- visual-only nudge smoothing:
		-- 1) target eases back to path
		-- 2) rendered nudge follows target for softer hit finish
		local targetX, targetY = e.nudgeTargetX, e.nudgeTargetY
		local nudgeX, nudgeY = e.nudgeX, e.nudgeY
		local epsilon = NUDGE_IDLE_EPS

		if targetX > epsilon or targetX < -epsilon
			or targetY > epsilon or targetY < -epsilon
			or nudgeX > epsilon or nudgeX < -epsilon
			or nudgeY > epsilon or nudgeY < -epsilon then
			local targetDecay = exp(-e.nudgeTargetK * dt)
			local follow = 1 - exp(-e.nudgeFollowK * dt)
			targetX = targetX * targetDecay
			targetY = targetY * targetDecay
			e.nudgeTargetX = targetX
			e.nudgeTargetY = targetY
			e.nudgeX = nudgeX + (targetX - nudgeX) * follow
			e.nudgeY = nudgeY + (targetY - nudgeY) * follow
		else
			e.nudgeTargetX = 0
			e.nudgeTargetY = 0
			e.nudgeX = 0
			e.nudgeY = 0
		end

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
	supportSourceCount = 0
	Util.clearTable(supportSources)
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

-- Single damage gateway for traits. Returns health and shield damage separately
-- so callers can report useful barrier damage without counting mitigation.
local function applyDamage(e, amount, context)
	if not e or e.hp <= 0 or amount <= 0 then return 0, 0 end
	context = context or {}
	for _, affix in ipairs(e.affixes or {}) do
		amount = amount * ((affix.behavior and affix.behavior.damageTakenMultiplier) or 1)
	end
	local raw = amount
	if e.armor then
		local heavy = context.sourceKind == "cannon" or context.sourceKind == "lancer"
			or raw >= (e.armor.heavyThreshold or math.huge)
		if heavy then amount = amount * (e.armor.heavyMultiplier or 1)
		else amount = max(1, amount - (e.armor.flatReduction or 0)) end
	end
	local absorbed = 0
	if e.shieldHp and e.shieldHp > 0 then
		local shieldDamage = amount
		if context.chain then shieldDamage = shieldDamage * (e.shieldDef.chainMultiplier or 1) end
		if raw >= (e.shieldDef.burstThreshold or math.huge) then
			shieldDamage = shieldDamage * (e.shieldDef.burstMultiplier or 1)
		end
		absorbed = min(e.shieldHp, shieldDamage)
		e.shieldHp = e.shieldHp - shieldDamage
		if e.shieldHp <= 0 then e.shieldHp = 0; e.shieldBreakFlash = 0.35 end
		amount = max(0, amount - absorbed)
	end
	e.hp = e.hp - amount
	removeDeadSupportSource(e)
	if amount > 0 or absorbed > 0 then
		e.hitSquash = HIT_SQUASH_DUR
		e.hitSquashStrength = 1
	end
	if e.regeneration then e.regenDelay = e.regeneration.delay end
	return amount, absorbed
end

local function applySlow(e, factor, duration)
	if not e or e.hp <= 0 then return false end
	for _, affix in ipairs(e.affixes or {}) do
		duration = (duration or 0) * ((affix.behavior and affix.behavior.statusDurationMultiplier) or 1)
	end
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
	clear = clear,
}
