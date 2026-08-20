-- Dependency-free campaign curriculum fixtures. Run from the repository root.
package.path = "./?.lua;./?/init.lua;" .. package.path

local Maps = require("world.map_defs")
local CampaignWaveDefs = require("systems.campaign_wave_defs")
local EnemyDefs = require("world.enemy_defs")

local available = { boss = true }
local minimumSpawnSpacing = 0.5

for _, map in ipairs(Maps) do
	for _, kind in ipairs(map.introducesEnemies or {}) do available[kind] = true end

	local waves = CampaignWaveDefs.wavesByMapId[map.id]
	assert(waves, map.id .. " has no campaign encounters")
	assert(#waves == 20, map.id .. " must author exactly twenty waves")
	local authoredTotal = 0

	for waveIndex = 1, 20 do
		local wave = waves[waveIndex]
		for _, group in ipairs(wave) do
			authoredTotal = authoredTotal + group.count
			assert(EnemyDefs[group.kind], map.id .. " uses unknown enemy " .. tostring(group.kind))
			assert(available[group.kind], map.id .. " uses unavailable enemy " .. group.kind)
			assert(group.count == 1 or group.spacing >= minimumSpawnSpacing,
				map.id .. " places consecutive enemies too close together")
		end
	end
	assert(CampaignWaveDefs.getTotalEnemyCount(map) == authoredTotal,
		map.id .. " enemy-count summary must match authored groups")

	local midpoint = waves[10]
	assert(midpoint[1].kind == "boss" and EnemyDefs[midpoint.bossArchetype],
		map.id .. " midpoint exam has no legal explicit boss selection")

	local final = waves[20]
	assert(final[1].kind == "boss" and EnemyDefs[final.bossArchetype],
		map.id .. " final exam has no legal explicit boss selection")
end

print("campaign wave definition fixtures passed")
