-- Dependency-free campaign wave fixtures. Run from the repository root.
package.path = "./?.lua;./?/init.lua;" .. package.path

local Maps = require("world.map_defs")
local CampaignWaveDefs = require("systems.campaign_wave_defs")
local EnemyDefs = require("world.enemy_defs")

local available = { boss = true }
local minimumSpawnSpacing = 0.5
local bossAppearances = {}

-- Introduction metadata must name exactly the map containing each kind's first
-- authored appearance. Riverbend previews Runners late while remaining free of
-- armor; specialist previews stay sparse.
assert(Maps[1].introducesEnemies[1] == "grunt" and Maps[1].introducesEnemies[2] == "runner"
	and Maps[1].introducesEnemies[3] == nil, "Riverbend must declare only its baseline enemies")
assert(Maps[4].introducesEnemies[1] == "regenerator"
	and Maps[4].introducesEnemies[2] == "bulwark", "Outerloop must own its specialist introductions")
assert(Maps[5].introducesEnemies[1] == "warcaller", "Gauntlet must own the Warcaller introduction")

local declaredIntroductions = {}
for _, map in ipairs(Maps) do
	for _, kind in ipairs(map.introducesEnemies or {}) do
		assert(not declaredIntroductions[kind], kind .. " is introduced more than once")
		declaredIntroductions[kind] = map.id
	end
end
local firstActualAppearance = {}
assert(not EnemyDefs.tank, "the retired tank archetype must not resolve")

for _, map in ipairs(Maps) do
	for _, kind in ipairs(map.introducesEnemies or {}) do available[kind] = true end
	local introducedEnemyAppearances = {}

	assert(CampaignWaveDefs.getFinalWave(map) == 20, map.id .. " must author exactly twenty waves")
	local authoredTotal = 0

	for waveIndex = 1, 20 do
		local wave = CampaignWaveDefs.get(map, waveIndex)
		assert(wave.boss == (waveIndex == 10 or waveIndex == 20),
			map.id .. " must reserve bosses for waves 10 and 20")
		local counted = 0
		local composition = {}
		for _, group in ipairs(wave.groups) do
			assert(group.kind ~= "tank", map.id .. " wave " .. waveIndex .. " references retired tank")
			authoredTotal = authoredTotal + group.count
			counted = counted + group.count
			assert(EnemyDefs[group.kind], map.id .. " uses unknown enemy " .. tostring(group.kind))
			if group.kind ~= "boss" and not firstActualAppearance[group.kind] then
				firstActualAppearance[group.kind] = map.id
			end
			assert(available[group.kind], map.id .. " uses unavailable enemy " .. group.kind)
			assert(group.count == 1 or group.spacing >= minimumSpawnSpacing,
				map.id .. " places consecutive enemies too close together")
			if group.kind ~= "boss" then composition[group.kind] = true end
		end
		if waveIndex >= 4 then
			for kind in pairs(composition) do
				introducedEnemyAppearances[kind] = (introducedEnemyAppearances[kind] or 0) + 1
			end
		end
		assert(wave.count == counted, map.id .. " wave count must match its groups")
	end
	assert(CampaignWaveDefs.getTotalEnemyCount(map) == authoredTotal,
		map.id .. " enemy-count summary must match authored groups")

	for _, bossWaveIndex in ipairs({10, 20}) do
		local bossWave = CampaignWaveDefs.get(map, bossWaveIndex)
		assert(bossWave.boss and EnemyDefs[bossWave.bossArchetype],
			map.id .. " wave " .. bossWaveIndex .. " has no legal explicit boss selection")
		bossAppearances[bossWave.bossArchetype] = (bossAppearances[bossWave.bossArchetype] or 0) + 1
	end
	assert(CampaignWaveDefs.get(map, 10).bossArchetype ~= CampaignWaveDefs.get(map, 20).bossArchetype,
		map.id .. " must feature different bosses on waves 10 and 20")

	local final = CampaignWaveDefs.get(map, 20)
	assert(final.boss and EnemyDefs[final.bossArchetype],
		map.id .. " final wave has no legal explicit boss selection")

	for _, kind in ipairs(map.introducesEnemies or {}) do
		assert((introducedEnemyAppearances[kind] or 0) >= 1,
			map.id .. " must reuse introduced enemy " .. kind .. " after its first appearance")
	end
end

assert(firstActualAppearance.bulwark == "outerloop", "Outerloop must remain the first Bulwark encounter")

for kind, mapId in pairs(declaredIntroductions) do
	assert(firstActualAppearance[kind] == mapId,
		kind .. " metadata says " .. mapId .. " but first appears on " .. tostring(firstActualAppearance[kind]))
end
for kind, mapId in pairs(firstActualAppearance) do
	assert(declaredIntroductions[kind] == mapId,
		kind .. " first appears on " .. mapId .. " without matching introduction metadata")
end

local expectedBossAppearances = {
	boss_summoner = 8,
	boss_phasewalker = 6,
	boss_suppression = 6,
	boss_ravager = 5,
	boss_gatecrasher = 5,
}
for bossKind, definition in pairs(EnemyDefs) do
	if definition.boss and bossKind ~= "boss" then
		local appearances = bossAppearances[bossKind] or 0
		assert(appearances == expectedBossAppearances[bossKind],
			bossKind .. " must follow the authored campaign cadence")
	end
end

print("campaign wave definition fixtures passed")
