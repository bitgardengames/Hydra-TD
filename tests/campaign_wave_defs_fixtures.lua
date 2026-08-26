-- Dependency-free campaign curriculum fixtures. Run from the repository root.
package.path = "./?.lua;./?/init.lua;" .. package.path

local Maps = require("world.map_defs")
local CampaignWaveDefs = require("systems.campaign_wave_defs")
local EnemyDefs = require("world.enemy_defs")

local available = { boss = true }
local minimumSpawnSpacing = 0.5

for _, map in ipairs(Maps) do
	for _, kind in ipairs(map.introducesEnemies or {}) do available[kind] = true end
	local introducedEnemyAppearances = {}
	local lateWaveCompositions = {}

	assert(CampaignWaveDefs.getFinalWave(map) == 20, map.id .. " must author exactly twenty waves")
	local authoredTotal = 0

	for waveIndex = 1, 20 do
		local wave = CampaignWaveDefs.get(map, waveIndex)
		assert(wave.boss == (waveIndex == 10 or waveIndex == 20),
			map.id .. " must reserve bosses for waves 10 and 20")
		local counted = 0
		local composition = {}
		for _, group in ipairs(wave.groups) do
			authoredTotal = authoredTotal + group.count
			counted = counted + group.count
			assert(EnemyDefs[group.kind], map.id .. " uses unknown enemy " .. tostring(group.kind))
			assert(available[group.kind], map.id .. " uses unavailable enemy " .. group.kind)
			assert(group.count == 1 or group.spacing >= minimumSpawnSpacing,
				map.id .. " places consecutive enemies too close together")
			if group.kind ~= "boss" then composition[group.kind] = true end
		end
		if waveIndex >= 4 then
			local kinds = {}
			for kind in pairs(composition) do
				kinds[#kinds + 1] = kind
				introducedEnemyAppearances[kind] = (introducedEnemyAppearances[kind] or 0) + 1
			end
			table.sort(kinds)
			lateWaveCompositions[table.concat(kinds, "+")] = true
		end
		assert(wave.count == counted, map.id .. " wave count must match its groups")
	end
	assert(CampaignWaveDefs.getTotalEnemyCount(map) == authoredTotal,
		map.id .. " enemy-count summary must match authored groups")

	for _, bossWaveIndex in ipairs({10, 20}) do
		local bossWave = CampaignWaveDefs.get(map, bossWaveIndex)
		assert(bossWave.boss and EnemyDefs[bossWave.bossArchetype],
			map.id .. " wave " .. bossWaveIndex .. " has no legal explicit boss selection")
	end

	local final = CampaignWaveDefs.get(map, 20)
	assert(final.boss and EnemyDefs[final.bossArchetype],
		map.id .. " final exam has no legal explicit boss selection")

	for _, kind in ipairs(map.introducesEnemies or {}) do
		assert((introducedEnemyAppearances[kind] or 0) >= 4,
			map.id .. " must revisit introduced enemy " .. kind .. " throughout later waves")
	end
	if map.campaignStage > 1 then
		local compositionCount = 0
		for _ in pairs(lateWaveCompositions) do compositionCount = compositionCount + 1 end
		assert(compositionCount >= 3, map.id .. " needs at least three distinct late-wave compositions")
	end
end

print("campaign wave definition fixtures passed")
