-- Boss selection and encounter mechanics must not depend on a map's biome or
-- legacy per-map encounter configuration. Run from the repository root.
package.path = "./?.lua;./?/init.lua;" .. package.path

package.loaded["systems.campaign_wave_defs"] = {get = function() end}
package.loaded["systems.difficulty_curve"] = {}

local Resolver = require("systems.wave_resolver")
local maps = {
	{id = "temperate", biome = "default"},
	{id = "desert", biome = "drylands"},
	{id = "snow", biome = "winter", waves = {encounters = {
		boss_summoner = {flankKind = "runner", flankBurst = 99},
	}}},
}

for bossIndex = 1, 10 do
	local expected = Resolver.getBossByArchetype(maps[1], bossIndex)
	for _, map in ipairs(maps) do
		assert(Resolver.getBossByArchetype(map, bossIndex) == expected,
			"biomes must not change the boss rotation")
	end
end

local expected = Resolver.resolveBossEncounterTemplate(maps[1], "boss_summoner", 1)
for _, map in ipairs(maps) do
	local encounter = Resolver.resolveBossEncounterTemplate(map, "boss_summoner", 1)
	for key, value in pairs(expected) do
		assert(encounter[key] == value, "maps must not change boss encounter mechanics")
	end
	assert(encounter.flankKind == "grunt" and encounter.flankBurst == 4,
		"legacy map encounter overrides must be ignored")
end

print("boss map consistency fixtures passed")
