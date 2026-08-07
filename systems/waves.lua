local State = require("core.state")
local Maps = require("world.map_defs")
local Enemies = require("world.enemies")
local Difficulty = require("systems.difficulty")
local DifficultyCurve = require("systems.difficulty_curve")
local WaveBuilder = require("systems.wave_builder")
local Steam = require("core.steam")
local L = require("core.localization")
local EnemyDefs = require("world.enemy_defs")
local EnemyTraits = require("world.enemy_traits")
local EnemyAffixDefs = require("world.enemy_affix_defs")
local Spatial = require("world.spatial_grid")
local Onboarding = require("systems.onboarding")
local Effects = require("world.effects")

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
			kind = group.kind == "boss" and getBossByArchetype(map, bossIndex) or group.kind,
			count = group.count,
			spacing = group.spacing,
			delay = group.delay,
			affixes = group.affixes,
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
	affixes = nil,
	compositionIndex = 1,
	groups = nil,
	groupIndex = 1,
	groupRemaining = 0,
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

local function resetTable(target, defaults, overrides)
	copyValues(target, defaults)
	copyNonNilValues(target, overrides)
end

resetTable(spawner, spawnerDefaults)
resetTable(bossAdds, bossAddsDefaults)

-- Build a display-only description of a wave.  Keep this independent of the
-- live spawner tables so callers (notably the prep HUD) can safely look ahead.
function Waves.getWavePreview(waveNumber)
	local map = Maps[State.mapIndex]
	local wave = WaveBuilder.build(waveNumber, map, State.endless)
	local resolvedGroups = resolveWaveGroups(wave, map, waveNumber)
	local groups = {}

	local function addGroup(kind, count, spacing, delay, affixes)
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
			affixes = affixes or {},
			affixNames = {},
			affixDescriptions = {},
		}
		for _, id in ipairs(group.affixes) do
			local affix = EnemyAffixDefs[id]
			if affix then
				group.affixNames[#group.affixNames + 1] = L(affix.nameKey)
				group.affixDescriptions[#group.affixDescriptions + 1] = L(affix.descriptionKey)
			end
		end
		for _, traitId in ipairs((def and def.traits) or {}) do
			local trait = EnemyTraits.get(traitId)
			if trait then
				group.traitIds[#group.traitIds + 1] = traitId
				group.tags[#group.tags + 1] = L("enemyTrait." .. traitId .. ".tag")
				group.counterHints[#group.counterHints + 1] = L("enemyTrait." .. traitId .. ".counter")
			end
		end
		groups[#groups + 1] = group
	end

	if wave.boss then
		Effects.trigger("boss_wave", {intensity = 4, shake = 5, duration = 0.3, criticalTell = true})
		for _, group in ipairs(resolvedGroups or {}) do
			addGroup(group.kind, group.count, group.spacing, group.delay, group.affixes)
		end
	elseif resolvedGroups then
		for _, group in ipairs(resolvedGroups) do
			addGroup(group.kind, group.count, group.spacing, group.delay)
		end
	else
		-- Endless composition has uniform timing; coalesce adjacent kinds while
		-- preserving their spawn order rather than aggregating the whole wave.
		for _, item in ipairs(wave.composition or {}) do
			local kind = type(item) == "table" and item.kind or item
			local affixes = type(item) == "table" and item.affixes or {}
			local affixKey = table.concat(affixes, ",")
			local group = groups[#groups]
			if group and group.kind == kind and group.affixKey == affixKey then group.count = group.count + 1
			else addGroup(kind, 1, wave.spacing, 0, affixes); groups[#groups].affixKey = affixKey end
		end
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
	})

	State.inPrep = false
end

-- Wave start
function Waves.startWave()
	if not Onboarding.canStartWave() then return false end
	local tutorialWave = Onboarding.isTutorialWave()
	Onboarding.event("wave_started")
	local map = Maps[State.mapIndex]
	local mapWaveDefs = getMapWaveDefs(map)

	State.waveLeaks = 0

	if State.mode == "game" then -- Make sure the background scene doesn't set the status
		local diffKey = Difficulty.key()
		local diffText = L("difficulty." .. diffKey)

		Steam.setRichPresence(L("presence.gameStatus", State.wave, diffText))
	end

	-- WaveBuilder enforces boss invariant and returns a simple descriptor
	local wave = tutorialWave and {
		count = 4, enemy = "grunt", spacing = 0.85,
	} or WaveBuilder.build(State.wave, map, State.endless)

	-- Boss waves
	if wave.boss then
		local bossIndex = math.max(1, math.floor(State.wave / 10))
		local bossKind = getBossByArchetype(map, bossIndex)
		local encounter = resolveBossEncounterTemplate(map, bossKind, bossIndex)
		local tier = WaveBuilder.getIntensityTier(State.wave)

		local hpMult, spdMult = getWaveMultipliers(State.wave, State.mapIndex, map, true)
		local addHpMult = DifficultyCurve.getEnemyHpMultiplier(State.wave, State.mapIndex, map and map.hpScalar)

		State.activeBoss = nil
		State.activeBossKind = bossKind
		local groups = resolveWaveGroups(wave, map, State.wave)
		for i, group in ipairs(groups or {}) do
			group.hpMult = i == 1 and hpMult or addHpMult
			group.spdMult = spdMult
		end
		beginSpawner(bossKind, wave.count or 1, 0, hpMult, spdMult, nil, groups)
		if encounter then
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
		else
			bossAdds.active = false
		end

		return true
	end

	State.activeBoss = nil
	State.activeBossKind = nil
	bossAdds.active = false

	-- Normal waves: single enemy kind with count + spacing
	local count = max(1, wave.count or 1)
	local kind = wave.enemy or "grunt"

	local hpMult, spdMult = getWaveMultipliers(State.wave, State.mapIndex, map, false)

	local gap = wave.spacing or 1.0

	beginSpawner(kind, count, gap, hpMult, spdMult, wave.composition, wave.groups)
	return true
end

-- Spawning update
function Waves.updateSpawner(dt)
	local spawnLoops = 0
	local activeCap = getActiveEnemyCap(State.wave)

	if spawner.active then
		spawner.timer = spawner.timer - dt

		while spawner.active and spawner.timer <= 0 and spawner.remaining > 0
			and spawnLoops < MAX_SPAWN_CATCHUP_PER_FRAME and #Enemies.enemies < activeCap do
			local group = spawner.groups and spawner.groups[spawner.groupIndex]
			local item = spawner.composition and spawner.composition[spawner.compositionIndex]
			local kind = group and group.kind or (type(item) == "table" and item.kind or item) or spawner.kind
			local affixes = group and group.affixes or (type(item) == "table" and item.affixes or nil)

			if not kind then
				spawner.remaining = 0
				spawner.active = false

				return
			end

			Enemies.spawnEnemy(kind, (group and group.hpMult) or spawner.hpMult,
				(group and group.spdMult) or spawner.spdMult, nil, nil, nil, {affixes = affixes})
			spawner.compositionIndex = spawner.compositionIndex + 1

			spawner.remaining = spawner.remaining - 1
			if group then
				spawner.groupRemaining = spawner.groupRemaining - 1
				if spawner.groupRemaining <= 0 and spawner.remaining > 0 then
					spawner.groupIndex = spawner.groupIndex + 1
					local nextGroup = spawner.groups[spawner.groupIndex]
					if nextGroup then
						spawner.groupRemaining = nextGroup.count
						spawner.timer = spawner.timer + (nextGroup.delay or 0)
					else
						-- A group list is the authoritative spawn sequence. If its
						-- advertised total and the spawner count ever disagree, finish
						-- the sequence instead of indexing past it (or duplicating the
						-- fallback kind for the unmatched remainder).
						spawner.remaining = 0
						spawner.active = false
					end
				else
					spawner.timer = spawner.timer + (group.spacing or spawner.gap)
				end
			else
				spawner.timer = spawner.timer + spawner.gap
			end
			spawnLoops = spawnLoops + 1
		end

		if spawnLoops == MAX_SPAWN_CATCHUP_PER_FRAME and spawner.timer <= 0 then
			spawner.timer = 0
		elseif #Enemies.enemies >= activeCap and spawner.remaining > 0 then
			-- Discard accumulated catch-up debt while capped. Once room opens, spawning
			-- resumes smoothly rather than releasing the entire backlog in one frame.
			spawner.timer = max(spawner.timer, SPAWN_BACKPRESSURE_DELAY)
		end

		if spawner.remaining <= 0 then
			spawner.active = false
		end
	end

	if bossAdds.active then
		local boss = State.activeBoss
		local bossAlive = boss and boss.hp and boss.hp > 0 and not boss.dying
		if not bossAlive then
			bossAdds.active = false
			bossAdds.queued = 0
			return
		end

		bossAdds.timer = bossAdds.timer - dt
		bossAdds.queueTimer = bossAdds.queueTimer - dt

		if bossAdds.timer <= 0 and bossAdds.totalSpawned < bossAdds.maxTotal then
			local nearbyAdds, nearbyCount = Spatial.queryCells(boss.x, boss.y, 320, true)
			local aliveAdds = 0
			for i = 1, nearbyCount do
				local e = nearbyAdds[i]
				if not e.boss and e.kind == bossAdds.kind and e.hp > 0 then
					aliveAdds = aliveAdds + 1
				end
			end

			-- Reserve alive/total budget for already queued adds. A slow or capped
			-- frame must not allow repeated encounter timers to overfill the queue.
			local available = min(bossAdds.maxAlive - aliveAdds - bossAdds.queued,
				activeCap - #Enemies.enemies - bossAdds.queued)
			if available > 0 then
				local toSpawn = max(0, min(bossAdds.burst, available,
					bossAdds.maxTotal - bossAdds.totalSpawned - bossAdds.queued))
				if toSpawn > 0 then
					bossAdds.queued = bossAdds.queued + toSpawn
				end
			end

			bossAdds.timer = bossAdds.interval
		end

		-- Boss reinforcements own their queue: never route them through the authored
		-- wave spawner, whose group cursor and remaining count must stay intact.
		while bossAdds.queued > 0 and bossAdds.queueTimer <= 0
			and spawnLoops < MAX_SPAWN_CATCHUP_PER_FRAME and #Enemies.enemies < activeCap do
			Enemies.spawnEnemy(bossAdds.kind, bossAdds.hpMult, bossAdds.spdMult)
			bossAdds.queued = bossAdds.queued - 1
			bossAdds.totalSpawned = bossAdds.totalSpawned + 1
			bossAdds.queueTimer = bossAdds.queueTimer + bossAdds.queueGap
			spawnLoops = spawnLoops + 1
		end

		if spawnLoops == MAX_SPAWN_CATCHUP_PER_FRAME and bossAdds.queueTimer <= 0 then
			bossAdds.queueTimer = 0
		elseif #Enemies.enemies >= activeCap and bossAdds.queued > 0 then
			bossAdds.queueTimer = max(bossAdds.queueTimer, SPAWN_BACKPRESSURE_DELAY)
		end
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

function Waves.getSpawner()
	return spawner
end

function Waves.getActiveEnemyCap()
	return getActiveEnemyCap(State.wave)
end

return Waves
