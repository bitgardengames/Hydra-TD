local State = require("core.state")
local Maps = require("world.map_defs")
local Enemies = require("world.enemies")
local Difficulty = require("systems.difficulty")
local DifficultyCurve = require("systems.difficulty_curve")
local WaveBuilder = require("systems.wave_builder")
local Steam = require("core.steam")
local L = require("core.localization")
local EnemyDefs = require("world.enemy_defs")
local Spatial = require("world.spatial_grid")

local Waves = {}

local max = math.max

local function mergeInto(dst, src)
	if not src then
		return dst
	end

	for k, v in pairs(src) do
		dst[k] = v
	end

	return dst
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
	local biomeOverride = nil
	local mapKeyedOverride = nil
	local mapIndexedOverride = nil

	local biomeOverrides = biomeTemplateOverrides[biome]
	if biomeOverrides then
		biomeOverride = biomeOverrides[bossKind]
	end

	if map and map.waves and map.waves.encounters then
		local mapDefs = map.waves.encounters
		mapKeyedOverride = mapDefs[bossKind]
		mapIndexedOverride = mapDefs[bossIndex]
	end

	local resolved = {}
	mergeInto(resolved, base)
	mergeInto(resolved, biomeOverride)
	mergeInto(resolved, mapKeyedOverride)
	mergeInto(resolved, mapIndexedOverride)

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

-- Keep spawner table shape so nothing else breaks (UI, debug, etc.)
local spawnerDefaults = {
	active = false,
	remaining = 0,
	gap = 0.6,
	timer = 0,
	hpMult = 1.0,
	spdMult = 1.0,
	kind = nil,
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

local function resetFromDefaults(targetTable, defaultsTable, overridesTable, explicitKeys)
	overridesTable = overridesTable or {}

	for k, v in pairs(defaultsTable) do
		targetTable[k] = (overridesTable[k] ~= nil) and overridesTable[k] or v
	end

	if explicitKeys then
		for k, isExplicit in pairs(explicitKeys) do
			if isExplicit then
				targetTable[k] = overridesTable[k]
			end
		end
	end
end

local function resetSpawner(active, remaining, gap, timer, hpMult, spdMult, kind)
	local overrides = {
		active = active and active or nil,
		remaining = remaining and remaining or nil,
		gap = gap and gap or nil,
		timer = timer and timer or nil,
		hpMult = hpMult and hpMult or nil,
		spdMult = spdMult and spdMult or nil,
		kind = kind,
	}
	local explicit = nil
	if select("#", active, remaining, gap, timer, hpMult, spdMult, kind) >= 7 then
		explicit = { kind = true }
	end

	resetFromDefaults(spawner, spawnerDefaults, overrides, explicit)
end

local function resetBossAdds(active, kind, burst, timer, interval, maxAlive, maxTotal, totalSpawned, hpMult, spdMult)
	local overrides = {
		active = active and active or nil,
		kind = kind,
		burst = burst and burst or nil,
		timer = timer and timer or nil,
		interval = interval and interval or nil,
		maxAlive = maxAlive and maxAlive or nil,
		maxTotal = maxTotal and maxTotal or nil,
		totalSpawned = totalSpawned and totalSpawned or nil,
		hpMult = hpMult and hpMult or nil,
		spdMult = spdMult and spdMult or nil,
	}
	local explicit = nil
	if select("#", active, kind, burst, timer, interval, maxAlive, maxTotal, totalSpawned, hpMult, spdMult) >= 2 then
		explicit = { kind = true }
	end

	resetFromDefaults(bossAdds, bossAddsDefaults, overrides, explicit)
end

resetSpawner()
resetBossAdds()

local function beginSpawner(kind, count, gap, hpMult, spdMult)
	resetSpawner(true, count or 0, gap or spawnerDefaults.gap, 0, hpMult or spawnerDefaults.hpMult, spdMult or spawnerDefaults.spdMult, kind)

	State.inPrep = false
end

-- Wave start
function Waves.startWave()
	local map = Maps[State.mapIndex]
	local mapMult = State.mapCoverageMult or 1.0

	State.waveLeaks = 0

	if State.mode == "game" then -- Make sure the background scene doesn't set the status
		local diffKey = Difficulty.key()
		local diffText = L("difficulty." .. diffKey)

		Steam.setRichPresence(L("presence.gameStatus", State.wave, diffText))
	end

	-- WaveBuilder enforces boss invariant and returns a simple descriptor
	local wave = WaveBuilder.build(State.wave)

	-- Boss waves
	if wave.boss then
		local bossKind = wave.enemy or "boss"
		local bossIndex = math.floor(State.wave / 10)

		if map and map.waves and map.waves.bosses then
			local bossDef = map.waves.bosses[bossIndex]

			if bossDef and bossDef.type then
				bossKind = bossDef.type
			end
		else
			bossKind = getBossByArchetype(map, bossIndex)
		end

		local hpMult = DifficultyCurve.getBossHpMultiplier(State.wave) * mapMult
		local spdMult = DifficultyCurve.getEnemySpeedMultiplier(State.wave)

		State.activeBoss = nil
		State.activeBossKind = bossKind
		beginSpawner(bossKind, 1, 0, hpMult, spdMult)

		local template = resolveBossEncounterTemplate(map, bossKind, bossIndex)
		if template and template.flankKind then
			local interval = max(1.2, template.interval or 6.0)
			local maxAlive = max(1, template.maxAliveAdds or 10)
			resetBossAdds(
				true,
				template.flankKind,
				max(1, template.flankBurst or 1),
				max(0.6, template.initialDelay or (interval * 0.5)),
				interval,
				maxAlive,
				max(maxAlive, template.maxTotalAdds or maxAlive),
				0,
				(template.addHpMult or 1.0) * DifficultyCurve.getEnemyHpMultiplier(State.wave) * mapMult,
				(template.addSpdMult or 1.0) * DifficultyCurve.getEnemySpeedMultiplier(State.wave)
			)
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

	local hpMult = DifficultyCurve.getEnemyHpMultiplier(State.wave) * mapMult
	local spdMult = DifficultyCurve.getEnemySpeedMultiplier(State.wave)

	local gap = wave.spacing or 1.0

	beginSpawner(kind, count, gap, hpMult, spdMult)
end

-- Spawning update
function Waves.updateSpawner(dt)
	if not spawner.active then
		return
	end

	spawner.timer = spawner.timer - dt

	if spawner.timer <= 0 and spawner.remaining > 0 then
		local kind = spawner.kind

		if not kind then
			spawner.remaining = 0
			spawner.active = false

			return
		end

		Enemies.spawnEnemy(kind, spawner.hpMult, spawner.spdMult)

		spawner.remaining = spawner.remaining - 1
		spawner.timer = spawner.gap
	end

	if spawner.remaining <= 0 then
		spawner.active = false
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

			local available = bossAdds.maxAlive - aliveAdds
			if available > 0 then
				local toSpawn = max(0, math.min(bossAdds.burst, available, bossAdds.maxTotal - bossAdds.totalSpawned))
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
	resetSpawner()
	resetBossAdds()
end

function Waves.getSpawner()
	return spawner
end

return Waves
