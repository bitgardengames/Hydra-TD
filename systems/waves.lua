local State = require("core.state")
local Maps = require("world.map_defs")
local Enemies = require("world.enemies")
local Difficulty = require("systems.difficulty")
local DifficultyCurve = require("systems.difficulty_curve")
local Steam = require("core.steam")
local L = require("core.localization")
local EnemyDefs = require("world.enemy_defs")
local EnemyTraits = require("world.enemy_traits")
local Effects = require("world.effects")
local RunModes = require("systems.run_modes")
local Resolver = require("systems.wave_resolver")
local Spawner = require("systems.wave_spawner")
local Outcome = require("systems.wave_outcome")
local Presentation = require("ui.wave_presentation")

local Waves = {}
local max, min = math.max, math.min
local bossSpawnPresented = false
local lastBossPosition

function Waves.generateEndlessWave(waveNumber, seed)
	return Resolver.generateEndlessWave(waveNumber, seed)
end

local function getWave(map, waveNumber)
	return Resolver.getWave(map, waveNumber, RunModes.isEndless(State), State.buildSeed)
end

local function describeEnemyGroup(kind, count, spacing, delay)
	local def = EnemyDefs[kind]
	local group = {kind=kind, name=L((def and def.nameKey) or ("enemy." .. kind)), count=count,
		spacing=spacing or 0, delay=delay or 0, tags={}, traitIds={}}
	for _, traitId in ipairs((def and def.traits) or {}) do
		if EnemyTraits.get(traitId) then
			group.traitIds[#group.traitIds + 1] = traitId
			group.tags[#group.tags + 1] = L("enemyTrait." .. traitId .. ".tag")
		end
	end
	return group
end

function Waves.getWavePreview(waveNumber)
	local map = Maps[State.mapIndex]
	local wave = getWave(map, waveNumber)
	local descriptions = {}
	for _, group in ipairs(Resolver.resolveWaveGroups(wave, map, waveNumber) or {}) do
		local previous = descriptions[#descriptions]
		if previous and previous.kind == group.kind then previous.count = previous.count + group.count
		else descriptions[#descriptions + 1] = describeEnemyGroup(group.kind, group.count, group.spacing, group.delay) end
	end
	local counts = {}
	for _, group in ipairs(descriptions) do counts[group.kind] = (counts[group.kind] or 0) + group.count end
	return {count=wave.count or 0, total=wave.count or 0, totalCount=wave.count or 0, counts=counts, composition=descriptions}
end

function Waves.presentationEvent(kind, payload) Presentation.event(kind, payload) end

local function startBossWave(wave, map)
	bossSpawnPresented, lastBossPosition = false, nil
	Presentation.event("boss_incoming", {wave=State.wave, path=Presentation.path(map)})
	local bossIndex = max(1, math.floor(State.wave / 10))
	local bossKind = wave.bossArchetype or Resolver.getBossByArchetype(map, bossIndex)
	local encounter = Resolver.resolveBossEncounterTemplate(map, bossKind, bossIndex)
	local hpMult, spdMult = Resolver.getWaveMultipliers(State.wave, State.mapIndex, map, true)
	local addHpMult = DifficultyCurve.getEnemyHpMultiplier(State.wave, State.mapIndex, map and map.hpScalar)
	local groups = Resolver.resolveWaveGroups(wave, map, State.wave)
	State.activeBoss, State.activeBossKind = nil, bossKind
	for i, group in ipairs(groups or {}) do
		group.hpMult = (i == 1 and hpMult or addHpMult) * (group.hpMult or 1)
		group.spdMult = spdMult * (group.spdMult or 1)
	end
	Spawner.begin(wave.count or 1, hpMult, spdMult, groups)
	if not encounter then Spawner.configureBossAdds(); return end
	Spawner.configureBossAdds({active=true, kind=encounter.flankKind,
		burst=min(8, encounter.flankBurst + math.floor(bossIndex / 2)),
		timer=max(1.5, encounter.initialDelay - bossIndex * .12), interval=max(3, encounter.interval * (.96 ^ bossIndex)),
		maxAlive=min(32, encounter.maxAliveAdds + bossIndex * 2), maxTotal=min(72, encounter.maxTotalAdds + bossIndex * 5),
		hpMult=addHpMult * encounter.addHpMult, spdMult=spdMult * encounter.addSpdMult})
end

local function startNormalWave(wave, map)
	State.activeBoss, State.activeBossKind = nil, nil
	Spawner.configureBossAdds()
	local hpMult, spdMult = Resolver.getWaveMultipliers(State.wave, State.mapIndex, map, false)
	local groups = Resolver.resolveWaveGroups(wave, map, State.wave)
	if wave.procedural then
		for _, group in ipairs(groups or {}) do
			group.hpMult, group.spdMult = hpMult * (group.hpMult or 1), spdMult * (group.spdMult or 1)
		end
	end
	Spawner.begin(max(1, wave.count or 1), hpMult, spdMult, groups)
end

function Waves.startWave()
	-- Starting again while a wave is active replaces the spawner schedule without
	-- removing enemies already on the map, which makes two waves appear to overlap.
	if not State.inPrep then return false end
	local map = Maps[State.mapIndex]
	State.waveLeaks, State.inPrep = 0, false
	if State.mode == "game" then
		Steam.setRichPresence(L("presence.gameStatus", State.wave, L("difficulty." .. Difficulty.key())))
	end
	local wave = getWave(map, State.wave)
	Presentation.waveStarted(State.wave, map)
	if wave.boss then startBossWave(wave, map) else startNormalWave(wave, map) end
	return true
end

local spawnContext = {}
spawnContext.spawnEnemy = Enemies.spawnEnemy
spawnContext.enemyCount = function() return #Enemies.enemies end
spawnContext.activeBoss = function() return State.activeBoss end
spawnContext.onBossPosition = function(boss) lastBossPosition = {x=boss.x, y=boss.y} end
spawnContext.onBossSpawn = function(enemy)
	if bossSpawnPresented then return end
	bossSpawnPresented = true
	lastBossPosition = {x=enemy.x, y=enemy.y}
	Presentation.event("boss_spawn", {wave=State.wave, x=enemy.x, y=enemy.y})
	Effects.shake(1.1, .22)
end

function Waves.updateSpawner(dt) Spawner.update(dt, spawnContext) end
function Waves.allEnemiesCleared() return Spawner.allEnemiesCleared(#Enemies.enemies) end
function Waves.getWaveCompletionBonus(wave, leaks) return Outcome.getWaveCompletionBonus(wave, leaks, State.activeBossKind) end
function Waves.resetSpawner() Spawner.reset() end
function Waves.presentWaveCleared(bonus)
	Presentation.waveCleared(State.wave, Maps[State.mapIndex], bonus, lastBossPosition, State.activeBossKind ~= nil)
end
function Waves.getSpawner() return Spawner.getState() end
function Waves.onScheduledEnemyRemoved(enemy) Spawner.onScheduledEnemyRemoved(enemy) end
function Waves.getProgress(out) return Spawner.getProgress(#Enemies.enemies, out) end
function Waves.getActiveEnemyCap() return Spawner.getActiveEnemyCap() end

return Waves
