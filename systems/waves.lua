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
local Spatial = require("world.spatial_grid")
local Onboarding = require("systems.onboarding")

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

local function getWaveMultipliers(waveNumber, mapMult, isBoss)
	local hpMult = isBoss
		and (DifficultyCurve.getBossHpMultiplier(waveNumber) * mapMult)
		or (DifficultyCurve.getEnemyHpMultiplier(waveNumber) * mapMult)
	local spdMult = DifficultyCurve.getEnemySpeedMultiplier(waveNumber)
	return hpMult, spdMult
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
	local wave = WaveBuilder.build(waveNumber)
	local groups = {}
	local groupsByKind = {}

	local function addKind(kind)
		local group = groupsByKind[kind]
		if not group then
			local def = EnemyDefs[kind]
			group = {
				kind = kind,
				name = L((def and def.nameKey) or ("enemy." .. kind)),
				count = 0,
				tags = {},
				counterHints = {},
			}
			for _, trait in ipairs(EnemyTraits.forEnemy(def)) do
				group.tags[#group.tags + 1] = trait.tag
				group.counterHints[#group.counterHints + 1] = trait.counter
			end
			groupsByKind[kind] = group
			groups[#groups + 1] = group
		end
		group.count = group.count + 1
	end

	if wave.boss then
		local bossIndex = math.max(1, math.floor(waveNumber / 10))
		addKind(getBossByArchetype(Maps[State.mapIndex], bossIndex))
	else
		for i = 1, #(wave.composition or {}) do
			addKind(wave.composition[i])
		end
	end

	local counts = {}
	for kind, group in pairs(groupsByKind) do
		counts[kind] = group.count
	end

	return {
		count = wave.count or 0,
		total = wave.count or 0,
		totalCount = wave.count or 0,
		counts = counts,
		composition = groups,
	}
end

local function beginSpawner(kind, count, gap, hpMult, spdMult, composition)
	resetTable(spawner, spawnerDefaults, {
		active = true,
		remaining = count or 0,
		gap = gap or spawnerDefaults.gap,
		timer = 0,
		hpMult = hpMult or spawnerDefaults.hpMult,
		spdMult = spdMult or spawnerDefaults.spdMult,
		kind = kind,
		composition = composition,
		compositionIndex = 1,
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
	local mapMult = State.mapCoverageMult or 1.0

	State.waveLeaks = 0

	if State.mode == "game" then -- Make sure the background scene doesn't set the status
		local diffKey = Difficulty.key()
		local diffText = L("difficulty." .. diffKey)

		Steam.setRichPresence(L("presence.gameStatus", State.wave, diffText))
	end

	-- WaveBuilder enforces boss invariant and returns a simple descriptor
	local wave = tutorialWave and {
		count = 4, enemy = "grunt", spacing = 0.85,
	} or WaveBuilder.build(State.wave)

	-- Boss waves
	if wave.boss then
		local bossIndex = math.max(1, math.floor(State.wave / 10))
		local bossKind = getBossByArchetype(map, bossIndex)
		local encounter = resolveBossEncounterTemplate(map, bossKind, bossIndex)
		local tier = WaveBuilder.getIntensityTier(State.wave)

		local hpMult, spdMult = getWaveMultipliers(State.wave, mapMult, true)
		local addHpMult = DifficultyCurve.getEnemyHpMultiplier(State.wave) * mapMult

		State.activeBoss = nil
		State.activeBossKind = bossKind
		beginSpawner(bossKind, 1, 0, hpMult, spdMult)
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

		return
	end

	State.activeBoss = nil
	State.activeBossKind = nil
	bossAdds.active = false

	-- Normal waves: single enemy kind with count + spacing
	local count = max(1, wave.count or 1)
	local kind = wave.enemy or "grunt"

	local hpMult, spdMult = getWaveMultipliers(State.wave, mapMult, false)

	local gap = wave.spacing or 1.0

	beginSpawner(kind, count, gap, hpMult, spdMult, wave.composition)
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
			local kind = spawner.composition and spawner.composition[spawner.compositionIndex] or spawner.kind

			if not kind then
				spawner.remaining = 0
				spawner.active = false

				return
			end

			Enemies.spawnEnemy(kind, spawner.hpMult, spawner.spdMult)
			spawner.compositionIndex = spawner.compositionIndex + 1

			spawner.remaining = spawner.remaining - 1
			spawner.timer = spawner.timer + spawner.gap
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
			return
		end

		bossAdds.timer = bossAdds.timer - dt

		if bossAdds.timer <= 0 and bossAdds.totalSpawned < bossAdds.maxTotal then
			local nearbyAdds, nearbyCount = Spatial.queryCells(boss.x, boss.y, 320, true)
			local aliveAdds = 0
			for i = 1, nearbyCount do
				local e = nearbyAdds[i]
				if not e.boss and e.kind == bossAdds.kind and e.hp > 0 then
					aliveAdds = aliveAdds + 1
				end
			end

			local available = min(bossAdds.maxAlive - aliveAdds, activeCap - #Enemies.enemies)
			if available > 0 then
				local toSpawn = max(0, min(bossAdds.burst, available, bossAdds.maxTotal - bossAdds.totalSpawned))
				if toSpawn > 0 then
					beginSpawner(bossAdds.kind, toSpawn, 0.18, bossAdds.hpMult, bossAdds.spdMult)
					bossAdds.totalSpawned = bossAdds.totalSpawned + toSpawn
				end
			end

			bossAdds.timer = bossAdds.interval
		end
	end
end

function Waves.allEnemiesCleared()
	return #Enemies.enemies == 0 and not spawner.active
end

function Waves.getWaveCompletionBonus(wave, waveLeaks)
	if waveLeaks ~= 0 then
		return 0
	end

	local base = 2 * wave
	local bossKind = State.activeBossKind
	local def = bossKind and EnemyDefs[bossKind] or nil
	local mechanicWeight = (def and def.mechanicWeight) or 1.0
	local archetypeBonus = (def and def.boss and def.mechanicPackage) and 0.2 or 0
	local milestoneBonus = (wave % 5 == 0) and 0.12 or 0
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
