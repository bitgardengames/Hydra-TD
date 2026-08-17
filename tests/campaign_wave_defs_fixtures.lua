-- Dependency-free campaign curriculum fixtures. Run from the repository root.
package.path = "./?.lua;./?/init.lua;" .. package.path

local Maps = require("world.map_defs")
local CampaignWaveDefs = require("systems.campaign_wave_defs")
local EnemyDefs = require("world.enemy_defs")

local available = { boss = true }
local requiredRoles = { demonstration = true, controlledPractice = true, complication = true, finalExam = true }

for _, map in ipairs(Maps) do
	for _, kind in ipairs(map.introducesEnemies or {}) do available[kind] = true end

	local waves = CampaignWaveDefs.wavesByMapId[map.id]
	assert(waves, map.id .. " has no campaign encounters")
	assert(#waves == 10, map.id .. " must author exactly ten waves")
	local roles = {}
	local featured = false

	for waveIndex = 1, 10 do
		local wave = waves[waveIndex]
		assert(type(wave.beatKey) == "string" and type(wave.beatName) == "string",
			map.id .. " wave " .. waveIndex .. " has no named beat")
		assert(type(wave.objectiveProgressKey) == "string",
			map.id .. " wave " .. waveIndex .. " has no lesson objective")
		roles[wave.beatRole] = true
		for _, group in ipairs(wave) do
			assert(EnemyDefs[group.kind], map.id .. " uses unknown enemy " .. tostring(group.kind))
			assert(available[group.kind], map.id .. " uses unavailable enemy " .. group.kind)
			if group.kind == wave.featuredThreat then featured = true end
		end
	end

	for role in pairs(requiredRoles) do
		assert(roles[role], map.id .. " is missing the " .. role .. " beat")
	end
	assert(featured, map.id .. " never fields its featured lesson threat")
	local final = waves[10]
	assert(final[1].kind == "boss" and EnemyDefs[final.bossArchetype],
		map.id .. " final exam has no legal explicit boss selection")
	assert(type(final.bossIntent) == "string", map.id .. " final exam has no boss intent")
end

print("campaign wave definition fixtures passed")
