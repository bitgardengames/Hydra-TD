-- Dependency-free campaign wave fixtures. Run from the repository root.
package.path = "./?.lua;./?/init.lua;" .. package.path

local Maps = require("world.map_defs")
local CampaignWaveDefs = require("systems.campaign_wave_defs")
local EnemyDefs = require("world.enemy_defs")

local minimumSpawnSpacing = 0.5
local bossAppearances = {}

local firstActualAppearance = {}
local expectedFirstAppearance = {
	grunt = "riverbend",
	runner = "riverbend",
	regenerator = "outerloop",
	warcaller = "gauntlet",
	summoner = "twinloop",
}
assert(EnemyDefs.tank and EnemyDefs.tank.hp == 51, "Tank must resolve with its increased base health")
assert(EnemyDefs.regenerator.hp == 42, "Regenerator must use its increased base health")

for _, map in ipairs(Maps) do
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

	for kind, introductionMapId in pairs(expectedFirstAppearance) do
		if introductionMapId == map.id then
			assert((introducedEnemyAppearances[kind] or 0) >= 1,
				map.id .. " must reuse introduced enemy " .. kind .. " after its first appearance")
		end
	end
end

for kind, mapId in pairs(expectedFirstAppearance) do
	assert(firstActualAppearance[kind] == mapId,
		kind .. " must first appear on " .. mapId .. ", not " .. tostring(firstActualAppearance[kind]))
end
for kind, mapId in pairs(firstActualAppearance) do
	assert(expectedFirstAppearance[kind] == mapId,
		kind .. " first appears on unexpected map " .. mapId)
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
