local State = require("core.state")
local Maps = require("world.map_defs")
local Enemies = require("world.enemies")
local Difficulty = require("systems.difficulty")
local DifficultyCurve = require("systems.difficulty_curve")
local WaveBuilder = require("systems.wave_builder")
local CampaignWaveDefs = require("systems.campaign_wave_defs")
local Steam = require("core.steam")
local L = require("core.localization")
local EnemyDefs = require("world.enemy_defs")
local EnemyTraits = require("world.enemy_traits")
local Spatial = require("world.spatial_grid")
local Effects = require("world.effects")
local Messages = require("ui.messages")
local BossHP = require("ui.boss_hp")
local Constants = require("core.constants")
local DevelopmentCounters = require("core.development_counters")

local Waves = {}

local max = math.max
local min = math.min

-- Runtime budgets complement WaveBuilder's per-wave budget. The active cap is
-- intentionally lower than several queued endless groups, applying backpressure
-- rather than allowing a slow frame to turn into an unbounded spawn burst.
local BASE_ACTIVE_ENEMY_CAP = 140
local MAX_ACTIVE_ENEMY_CAP = 180
local MAX_SPAWN_CATCHUP_PER_FRAME = 12
local SPAWN_BACKPRESSURE_DELAY = 0.10

local function getActiveEnemyCap(waveNumber)
	local tier = WaveBuilder.getIntensityTier(waveNumber)
	return min(MAX_ACTIVE_ENEMY_CAP, BASE_ACTIVE_ENEMY_CAP + tier * 4)
end

local function copyValues(dst, src)
	for k, v in pairs(src) do
		dst[k] = v
	end
end

local function copyNonNilValues(dst, src)
	if not src then
		return
	end

	for k, v in pairs(src) do
		if v ~= nil then
			dst[k] = v
		end
	end
end

local function mergeTemplateLayers(...)
	local merged = {}
	for i = 1, select("#", ...) do
		copyNonNilValues(merged, select(i, ...))
	end
	return merged
end

local biomeBossArchetypes = {
	default = {"boss_summoner", "boss_displacement", "boss_suppression"},
	autumn = {"boss_displacement", "boss_suppression", "boss_summoner"},
	drylands = {"boss_suppression", "boss_displacement", "boss_summoner"},
	winter = {"boss_summoner", "boss_suppression", "boss_displacement"},
	highlands = {"boss_displacement", "boss_summoner", "boss_suppression"},
}

local mapBossOverrides = {
	roundabout = { [1] = "boss_displacement", [2] = "boss_summoner" },
	gauntlet = { [1] = "boss_suppression", [2] = "boss_displacement" },
	terrace = { [1] = "boss_summoner", [2] = "boss_suppression" },
}

local bossEncounterTemplates = {
	boss_displacement = {
		flankKind = "runner",
		flankBurst = 2,
		interval = 6.5,
		initialDelay = 3.0,
		maxAliveAdds = 14,
		maxTotalAdds = 26,
		addHpMult = 0.95,
		addSpdMult = 1.15,
	},
	boss_suppression = {
		flankKind = "tank",
		flankBurst = 1,
		interval = 7.2,
		initialDelay = 4.0,
		maxAliveAdds = 10,
		maxTotalAdds = 18,
		addHpMult = 1.2,
		addSpdMult = 0.9,
	},
	boss_summoner = {
		flankKind = "grunt",
		flankBurst = 4,
		interval = 5.8,
		initialDelay = 2.4,
		maxAliveAdds = 20,
		maxTotalAdds = 34,
		addHpMult = 0.9,
		addSpdMult = 1.0,
	},
}

local biomeTemplateOverrides = {
	autumn = {
		boss_displacement = { flankBurst = 3, interval = 5.7, addSpdMult = 1.2 },
		boss_suppression = { interval = 6.6, maxAliveAdds = 11 },
		boss_summoner = { flankBurst = 5, interval = 5.0, maxTotalAdds = 38 },
	},
	drylands = {
		boss_displacement = { initialDelay = 2.3, maxAliveAdds = 12 },
		boss_suppression = { flankBurst = 2, interval = 7.8, addHpMult = 1.3 },
		boss_summoner = { flankKind = "runner", flankBurst = 3, interval = 6.8 },
	},
	winter = {
		boss_displacement = { interval = 7.4, addSpdMult = 1.05 },
		boss_suppression = { interval = 6.9, maxTotalAdds = 22 },
		boss_summoner = { flankBurst = 4, interval = 6.2, addHpMult = 1.0 },
	},
	highlands = {
		boss_displacement = { flankKind = "runner", flankBurst = 2, interval = 5.9 },
		boss_suppression = { flankKind = "tank", flankBurst = 1, interval = 6.5, maxAliveAdds = 12 },
		boss_summoner = { flankKind = "runner", flankBurst = 4, interval = 5.4 },
	},
}

local function getMapWaveDefs(map)
	return map and map.waves or nil
end

local function getBossByArchetype(map, bossIndex)
	local mapOverrides = map and mapBossOverrides[map.id]
	if mapOverrides and mapOverrides[bossIndex] then
		return mapOverrides[bossIndex]
	end

	local biome = (map and map.biome) or "default"
	local archetypes = biomeBossArchetypes[biome] or biomeBossArchetypes.default
	local slot = ((bossIndex - 1) % #archetypes) + 1

	return archetypes[slot]
end

local function resolveBossEncounterTemplate(map, bossKind, bossIndex)
	local base = bossEncounterTemplates[bossKind]
	if not base then
		return nil
	end

	local biome = (map and map.biome) or "default"
	local biomeOverride = biomeTemplateOverrides[biome] and biomeTemplateOverrides[biome][bossKind] or nil

	local mapWaveDefs = getMapWaveDefs(map)
	local mapDefs = mapWaveDefs and mapWaveDefs.encounters or nil
	local resolved = mergeTemplateLayers(
		base,
		biomeOverride,
		mapDefs and mapDefs[bossKind] or nil,
		mapDefs and mapDefs[bossIndex] or nil
	)

	return {
		flankKind = resolved.flankKind,
		flankBurst = resolved.flankBurst,
		interval = resolved.interval,
		initialDelay = resolved.initialDelay,
		maxAliveAdds = resolved.maxAliveAdds,
		maxTotalAdds = resolved.maxTotalAdds,
		addHpMult = resolved.addHpMult,
		addSpdMult = resolved.addSpdMult,
	}
end

local function getWaveMultipliers(waveNumber, mapIndex, map, isBoss)
	local authoredScalar = map and map.hpScalar
	local hpMult = isBoss
		and DifficultyCurve.getBossHpMultiplier(waveNumber, mapIndex, authoredScalar)
		or DifficultyCurve.getEnemyHpMultiplier(waveNumber, mapIndex, authoredScalar)
	local spdMult = DifficultyCurve.getEnemySpeedMultiplier(waveNumber)
	return hpMult, spdMult
end

-- Campaign definitions use the generic "boss" kind so the same authored wave
-- can select the appropriate archetype for each map. Resolve that placeholder
-- once and use the resulting roster for both the preview and live spawner.
-- Keeping this transformation shared prevents the HUD from advertising one
-- enemy while startWave silently substitutes (or drops) it.
local function resolveWaveGroups(wave, map, waveNumber)
	if not wave.groups then return nil end

	local bossIndex = math.max(1, math.floor(waveNumber / 10))
	local groups = {}
	for i, group in ipairs(wave.groups) do
		groups[i] = {
			kind = group.kind == "boss" and (wave.bossArchetype or getBossByArchetype(map, bossIndex)) or group.kind,
			count = group.count,
			spacing = group.spacing,
			delay = group.delay,
			hpMult = group.hpMult,
			spdMult = group.spdMult,
		}
	end
	return groups
end

-- Keep spawner table shape so nothing else breaks (UI, debug, etc.)
local spawnerDefaults = {
	active = false,
	remaining = 0,
	gap = 0.6,
	timer = 0,
	hpMult = 1.0,
	spdMult = 1.0,
	kind = nil,
	composition = nil,
	compositionIndex = 1,
	groups = nil,
	groupIndex = 1,
	groupRemaining = 0,
	totalScheduled = 0,
	spawned = 0,
	waitingGroupDelay = false,
}

local bossAddsDefaults = {
	active = false,
	kind = nil,
	burst = 0,
	timer = 0,
	interval = 0,
	maxAlive = 0,
	maxTotal = 0,
	totalSpawned = 0,
	queued = 0,
	queueTimer = 0,
	queueGap = 0.18,
	hpMult = 1.0,
	spdMult = 1.0,
}
local spawner = {}
local bossAdds = {}
local bossSpawnPresented = false
local lastBossPosition = nil

local function resetTable(target, defaults, overrides)
	copyValues(target, defaults)
	copyNonNilValues(target, overrides)
end

resetTable(spawner, spawnerDefaults)
resetTable(bossAdds, bossAddsDefaults)

local function describeEnemyGroup(kind, count, spacing, delay)
	local def = EnemyDefs[kind]
	local group = {
		kind = kind,
		name = L((def and def.nameKey) or ("enemy." .. kind)),
		count = count,
		spacing = spacing or 0,
		delay = delay or 0,
		tags = {},
		counterHints = {},
		traitIds = {},
	}

	for _, traitId in ipairs((def and def.traits) or {}) do
		local trait = EnemyTraits.get(traitId)
		if trait then
			group.traitIds[#group.traitIds + 1] = traitId
			group.tags[#group.tags + 1] = L("enemyTrait." .. traitId .. ".tag")
			group.counterHints[#group.counterHints + 1] = L("enemyTrait." .. traitId .. ".counter")
		end
	end

	return group
end

local function describeAuthoredGroups(groups)
	local descriptions = {}
	for _, group in ipairs(groups or {}) do
		local previous = descriptions[#descriptions]
		if previous and previous.kind == group.kind then
			previous.count = previous.count + group.count
		else
			descriptions[#descriptions + 1] = describeEnemyGroup(
				group.kind, group.count, group.spacing, group.delay)
		end
	end
	return descriptions
end

local function describeComposition(composition, spacing)
	local descriptions = {}
	for _, item in ipairs(composition or {}) do
		local kind = item
		local previous = descriptions[#descriptions]

		-- Coalesce only adjacent identical entries so the preview preserves spawn
		-- order while avoiding a row for every enemy in an endless wave.
		if previous and previous.kind == kind then
			previous.count = previous.count + 1
		else
			descriptions[#descriptions + 1] = describeEnemyGroup(kind, 1, spacing, 0)
		end
	end
	return descriptions
end

-- Build a display-only description of a wave.  Keep this independent of the
-- live spawner tables so callers (notably the prep HUD) can safely look ahead.
function Waves.getWavePreview(waveNumber)
	local map = Maps[State.mapIndex]
	local wave = WaveBuilder.build(waveNumber, map, State.endless)
	local resolvedGroups = resolveWaveGroups(wave, map, waveNumber)
	local groups

	if resolvedGroups then
		groups = describeAuthoredGroups(resolvedGroups)
	else
		groups = describeComposition(wave.composition, wave.spacing)
	end

	local counts = {}
	for _, group in ipairs(groups) do
		counts[group.kind] = (counts[group.kind] or 0) + group.count
	end

	return {
		count = wave.count or 0,
		total = wave.count or 0,
		totalCount = wave.count or 0,
		counts = counts,
		composition = groups,
		beatKey = wave.beatKey,
		beatName = wave.beatName,
		beatRole = wave.beatRole,
		objectiveProgressKey = wave.objectiveProgressKey,
		featuredThreat = wave.featuredThreat,
		bossArchetype = wave.bossArchetype,
		bossIntent = wave.bossIntent,
	}
end

local function beginSpawner(kind, count, gap, hpMult, spdMult, composition, groups)
	local firstGroup = groups and groups[1]
	resetTable(spawner, spawnerDefaults, {
		active = true,
		remaining = count or 0,
		gap = gap or spawnerDefaults.gap,
		timer = (firstGroup and firstGroup.delay) or 0,
		hpMult = hpMult or spawnerDefaults.hpMult,
		spdMult = spdMult or spawnerDefaults.spdMult,
		kind = kind,
		composition = composition,
		compositionIndex = 1,
		groups = groups,
		groupIndex = 1,
		groupRemaining = firstGroup and firstGroup.count or 0,
		totalScheduled = count or 0,
		spawned = 0,
		waitingGroupDelay = firstGroup ~= nil and (firstGroup.delay or 0) > 0,
	})

	State.inPrep = false
end

local function presentationPath(map)
	local result = {}
	for i, point in ipairs((map and map.path) or {}) do
		result[i] = {(point[1] - 0.5) * Constants.TILE, (point[2] - 0.5) * Constants.TILE}
	end
	return result
end

-- Presentation events are explicit and fan out synchronously to UI, sound and
-- playfield feedback. They only enqueue visual state; simulation never waits.
function Waves.presentationEvent(kind, payload)
	payload = payload or {}
	Messages.presentationEvent(kind, payload)
	BossHP.presentationEvent(kind, payload)
	Effects.presentationEvent(kind, payload)
end

local function startBossWave(wave, map)
	bossSpawnPresented = false
	lastBossPosition = nil
	local path = presentationPath(map)
	Waves.presentationEvent("boss_incoming", {wave = State.wave, path = path})
	local bossIndex = math.max(1, math.floor(State.wave / 10))
	local bossKind = wave.bossArchetype or getBossByArchetype(map, bossIndex)
	local encounter = resolveBossEncounterTemplate(map, bossKind, bossIndex)
	local tier = WaveBuilder.getIntensityTier(State.wave)
	local hpMult, spdMult = getWaveMultipliers(State.wave, State.mapIndex, map, true)
	local addHpMult = DifficultyCurve.getEnemyHpMultiplier(State.wave, State.mapIndex, map and map.hpScalar)
	local groups = resolveWaveGroups(wave, map, State.wave)

	State.activeBoss = nil
	State.activeBossKind = bossKind
	for i, group in ipairs(groups or {}) do
		group.hpMult = i == 1 and hpMult or addHpMult
		group.spdMult = spdMult
	end
	beginSpawner(bossKind, wave.count or 1, 0, hpMult, spdMult, nil, groups)

	if not encounter then
		resetTable(bossAdds, bossAddsDefaults)
		return
	end

	resetTable(bossAdds, bossAddsDefaults, {
		active = true,
		kind = encounter.flankKind,
		burst = min(8, encounter.flankBurst + math.floor(tier / 2)),
		timer = max(1.5, encounter.initialDelay - tier * 0.12),
		interval = max(3.0, encounter.interval * (0.96 ^ tier)),
		maxAlive = min(32, encounter.maxAliveAdds + tier * 2),
		maxTotal = min(72, encounter.maxTotalAdds + tier * 5),
		hpMult = addHpMult * encounter.addHpMult,
		spdMult = spdMult * encounter.addSpdMult,
	})
end

local function startNormalWave(wave, map)
	State.activeBoss = nil
	State.activeBossKind = nil
	resetTable(bossAdds, bossAddsDefaults)
	local count = max(1, wave.count or 1)
	local kind = wave.enemy or "grunt"
	local hpMult, spdMult = getWaveMultipliers(State.wave, State.mapIndex, map, false)
	local gap = wave.spacing or 1.0

	beginSpawner(kind, count, gap, hpMult, spdMult, wave.composition, wave.groups)
end

-- Wave start
function Waves.startWave()
	local map = Maps[State.mapIndex]
	State.waveLeaks = 0

	if State.mode == "game" then -- Make sure the background scene doesn't set the status
		local diffText = L("difficulty." .. Difficulty.key())
		Steam.setRichPresence(L("presence.gameStatus", State.wave, diffText))
	end

	-- WaveBuilder enforces the boss invariant, leaving startup as a simple dispatch.
	local wave = WaveBuilder.build(State.wave, map, State.endless)
	local start = map and map.path and map.path[1]
	Waves.presentationEvent("wave_start", {
		wave = State.wave,
		x = start and (start[1] - 0.5) * Constants.TILE,
		y = start and (start[2] - 0.5) * Constants.TILE,
	})
	if wave.boss then
		startBossWave(wave, map)
	else
		startNormalWave(wave, map)
	end

	return true
end

-- Both spawn queues share the same simulation-tick and population budgets. Centralizing
-- their scheduling keeps either queue from bypassing catch-up or cap protection.
local function spawnWhileReady(owner, timerKey, pending, activeCap, spawnLoops, spawnOne)
	while owner[timerKey] <= 0 and pending() > 0
		and spawnLoops < MAX_SPAWN_CATCHUP_PER_FRAME and #Enemies.enemies < activeCap do
		if spawnOne() == false then
			return spawnLoops, false
		end
		spawnLoops = spawnLoops + 1
	end

	if spawnLoops == MAX_SPAWN_CATCHUP_PER_FRAME and owner[timerKey] <= 0 then
		DevelopmentCounters.add("spawnBackpressureEvents")
		-- Drop catch-up debt once this frame has spent its spawn budget.
		owner[timerKey] = 0
	elseif #Enemies.enemies >= activeCap and pending() > 0 then
		DevelopmentCounters.add("spawnBackpressureEvents")
		-- Do not accumulate catch-up debt while the population cap is full.
		owner[timerKey] = max(owner[timerKey], SPAWN_BACKPRESSURE_DELAY)
	end

	return spawnLoops, true
end

local function currentSpawnEntry()
	local group = spawner.groups and spawner.groups[spawner.groupIndex]
	local item = spawner.composition and spawner.composition[spawner.compositionIndex]
	return group, group and group.kind or item or spawner.kind
end

local function advanceSpawner(group)
	spawner.remaining = spawner.remaining - 1
	spawner.spawned = spawner.spawned + 1
	if not group then
		spawner.timer = spawner.timer + spawner.gap
		return
	end

	spawner.groupRemaining = spawner.groupRemaining - 1
	if spawner.groupRemaining > 0 or spawner.remaining <= 0 then
		spawner.timer = spawner.timer + (group.spacing or spawner.gap)
		return
	end

	spawner.groupIndex = spawner.groupIndex + 1
	local nextGroup = spawner.groups[spawner.groupIndex]
	if nextGroup then
		spawner.groupRemaining = nextGroup.count
		spawner.timer = spawner.timer + (nextGroup.delay or 0)
		spawner.waitingGroupDelay = (nextGroup.delay or 0) > 0
	else
		-- Groups are authoritative; never fill a mismatched count with fallback enemies.
		spawner.remaining = 0
		spawner.active = false
	end
end

local function updateWaveSpawner(dt, activeCap, spawnLoops)
	if not spawner.active then
		return spawnLoops, false
	end

	spawner.timer = spawner.timer - dt
	local sequenceValid
	spawnLoops, sequenceValid = spawnWhileReady(spawner, "timer", function()
		return spawner.active and spawner.remaining or 0
	end, activeCap, spawnLoops, function()
		spawner.waitingGroupDelay = false
		local group, kind = currentSpawnEntry()
		if not kind then
			spawner.remaining = 0
			spawner.active = false
			return false
		end

		local enemy = Enemies.spawnEnemy(kind, (group and group.hpMult) or spawner.hpMult,
			(group and group.spdMult) or spawner.spdMult)
		enemy.scheduledWaveEnemy = true
		if enemy.boss and not bossSpawnPresented then
			bossSpawnPresented = true
			lastBossPosition = {x = enemy.x, y = enemy.y}
			Waves.presentationEvent("boss_spawn", {wave = State.wave, x = enemy.x, y = enemy.y})
			-- A modest cue replaces the previous zero-strength call; Effects.shake
			-- becomes a no-op under either motion accessibility setting.
			Effects.shake(1.1, 0.22)
		end
		spawner.compositionIndex = spawner.compositionIndex + 1
		advanceSpawner(group)
	end)

	spawner.active = spawner.remaining > 0
	return spawnLoops, not sequenceValid
end

local function countNearbyBossAdds(boss)
	local nearbyAdds, nearbyCount = Spatial.queryCells(boss.x, boss.y, 320, true)
	local aliveAdds = 0
	for i = 1, nearbyCount do
		local enemy = nearbyAdds[i]
		if not enemy.boss and enemy.kind == bossAdds.kind and enemy.hp > 0 then
			aliveAdds = aliveAdds + 1
		end
	end
	return aliveAdds
end

local function queueBossReinforcements(boss, activeCap)
	if bossAdds.timer > 0 or bossAdds.totalSpawned >= bossAdds.maxTotal then
		return
	end

	-- Queued adds reserve both the nearby and global capacity budgets.
	local aliveAdds = countNearbyBossAdds(boss)
	local available = min(bossAdds.maxAlive - aliveAdds - bossAdds.queued,
		activeCap - #Enemies.enemies - bossAdds.queued)
	local totalRemaining = bossAdds.maxTotal - bossAdds.totalSpawned - bossAdds.queued
	local toSpawn = max(0, min(bossAdds.burst, available, totalRemaining))
	bossAdds.queued = bossAdds.queued + toSpawn
	bossAdds.timer = bossAdds.interval
end

local function updateBossAdds(dt, activeCap, spawnLoops)
	if not bossAdds.active then return end

	local boss = State.activeBoss
	if not (boss and boss.hp and boss.hp > 0 and not boss.dying) then
		bossAdds.active = false
		bossAdds.queued = 0
		return
	end
	lastBossPosition = {x = boss.x, y = boss.y}

	bossAdds.timer = bossAdds.timer - dt
	bossAdds.queueTimer = bossAdds.queueTimer - dt
	queueBossReinforcements(boss, activeCap)

	-- Reinforcements keep their own queue, but consume the shared spawn budget.
	spawnWhileReady(bossAdds, "queueTimer", function()
		return bossAdds.queued
	end, activeCap, spawnLoops, function()
		Enemies.spawnEnemy(bossAdds.kind, bossAdds.hpMult, bossAdds.spdMult)
		bossAdds.queued = bossAdds.queued - 1
		bossAdds.totalSpawned = bossAdds.totalSpawned + 1
		bossAdds.queueTimer = bossAdds.queueTimer + bossAdds.queueGap
	end)
end

-- Spawning update
function Waves.updateSpawner(dt)
	local activeCap = getActiveEnemyCap(State.wave)
	local spawnLoops, invalidSequence = updateWaveSpawner(dt, activeCap, 0)
	if not invalidSequence then
		updateBossAdds(dt, activeCap, spawnLoops)
	end
end

function Waves.allEnemiesCleared()
	return #Enemies.enemies == 0 and not spawner.active and bossAdds.queued == 0
end

function Waves.getWaveCompletionBonus(wave, waveLeaks)
	if waveLeaks ~= 0 then
		return 0
	end

	-- Flawless income acknowledges clean play without outrunning purchase anchors.
	local base = Difficulty.get().perfectWaveBonus
	local bossKind = State.activeBossKind
	local def = bossKind and EnemyDefs[bossKind] or nil
	local mechanicWeight = (def and def.mechanicWeight) or 1.0
	local archetypeBonus = (def and def.boss and def.mechanicPackage) and 0.2 or 0
	local milestoneBonus = (wave % 5 == 0) and 0.10 or 0
	local mult = 1.0 + archetypeBonus + milestoneBonus + ((mechanicWeight - 1.0) * 0.75)

	return math.floor((base * mult) + 0.5)
end

function Waves.resetSpawner()
	resetTable(spawner, spawnerDefaults)
	resetTable(bossAdds, bossAddsDefaults)
end

function Waves.presentWaveCleared()
	if State.activeBossKind then
		Waves.presentationEvent("boss_defeated", {
			wave = State.wave,
			x = lastBossPosition and lastBossPosition.x,
			y = lastBossPosition and lastBossPosition.y,
		})
	end
	local map = Maps[State.mapIndex]
	local finish = map and map.path and map.path[#map.path]
	Waves.presentationEvent("wave_cleared", {
		wave = State.wave,
		x = finish and (finish[1] - 0.5) * Constants.TILE,
		y = finish and (finish[2] - 0.5) * Constants.TILE,
	})
end

function Waves.getSpawner()
	return spawner
end

-- Return a snapshot rather than the mutable spawner table. Presentation and
-- diagnostics can observe combat pacing without being able to alter it.
function Waves.getProgress()
	local group = spawner.groups and spawner.groups[spawner.groupIndex] or nil
	local living = #Enemies.enemies
	local scheduledLiving = 0
	for i = 1, living do
		if Enemies.enemies[i].scheduledWaveEnemy then
			scheduledLiving = scheduledLiving + 1
		end
	end
	local queued = spawner.remaining
	local currentGroup = nil
	if group then
		currentGroup = {
			index = spawner.groupIndex,
			total = #spawner.groups,
			kind = group.kind,
			remaining = spawner.groupRemaining,
		}
	end

	return {
		totalScheduled = spawner.totalScheduled,
		spawnedCount = spawner.spawned,
		livingCount = living,
		clearedCount = max(0, spawner.spawned - scheduledLiving),
		remainingQueuedCount = queued,
		currentAuthoredGroup = currentGroup,
		waitingOnGroupDelay = spawner.active and spawner.waitingGroupDelay and spawner.timer > 0,
		waitingOnPopulationBackpressure = spawner.active and queued > 0
			and living >= getActiveEnemyCap(State.wave),
	}
end

function Waves.getActiveEnemyCap()
	return getActiveEnemyCap(State.wave)
end

return Waves
