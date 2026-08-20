-- Dependency-free boss-wave startup regression fixture. Run from the repository root.
package.path = "./?.lua;./?/init.lua;" .. package.path

local state = {
	wave = 20,
	mapIndex = 1,
	mode = "game",
	inPrep = true,
}
local map = {
	id = "boss-startup-fixture",
	biome = "default",
	hpScalar = 1,
	path = {{1, 1}, {2, 1}},
}
local bossWave = {
	boss = true,
	bossArchetype = "boss_summoner",
	count = 1,
	groups = {{kind = "boss", count = 1, spacing = 0}},
}

package.loaded["core.state"] = state
package.loaded["world.map_defs"] = {map}
package.loaded["world.enemies"] = {enemies = {}}
package.loaded["systems.difficulty"] = {key = function() return "normal" end}
package.loaded["systems.difficulty_curve"] = {
	getBossHpMultiplier = function() return 1 end,
	getEnemyHpMultiplier = function() return 1 end,
	getEnemySpeedMultiplier = function() return 1 end,
}
package.loaded["systems.campaign_wave_defs"] = {get = function() return bossWave end}
package.loaded["core.steam"] = {setRichPresence = function() end}
package.loaded["core.localization"] = function(key) return key end
package.loaded["world.enemy_defs"] = {}
package.loaded["world.enemy_traits"] = {get = function() return nil end}
package.loaded["world.spatial_grid"] = {}
package.loaded["world.effects"] = {presentationEvent = function() end}
package.loaded["ui.messages"] = {presentationEvent = function() end}
package.loaded["ui.boss_hp"] = {presentationEvent = function() end}
package.loaded["core.constants"] = {TILE = 32}
package.loaded["core.development_counters"] = {}

local Waves = require("systems.waves")

assert(Waves.startWave() == true, "boss wave should start successfully")
assert(state.activeBossKind == "boss_summoner", "boss archetype should be activated")
assert(state.inPrep == false, "starting the boss wave should leave preparation")

print("boss wave startup fixtures passed")
