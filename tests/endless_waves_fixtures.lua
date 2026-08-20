-- Procedural endless composition fixtures. Runtime-heavy wave dependencies are
-- replaced because generation itself must remain simulation and renderer free.
package.loaded["core.state"] = {runMode = "endless", buildSeed = 777, wave = 21}
package.loaded["world.map_defs"] = {{id = "fixture", path = {{1, 1}, {2, 1}}}}
package.loaded["world.enemies"] = {enemies = {}}
package.loaded["systems.difficulty"] = {get = function() return {
	enemyHpBias = 1, bossHpBias = 1, enemySpeedBias = 1, perfectWaveBonus = 1,
} end, key = function() return "normal" end}
package.loaded["systems.campaign_wave_defs"] = {}
package.loaded["core.steam"] = {}
package.loaded["core.localization"] = setmetatable({}, {__call = function(_, key) return key end})
package.loaded["world.enemy_defs"] = {}
package.loaded["world.enemy_traits"] = {get = function() end}
package.loaded["world.spatial_grid"] = {}
package.loaded["world.effects"] = {}
package.loaded["ui.messages"] = {}
package.loaded["ui.boss_hp"] = {}
package.loaded["core.constants"] = {TILE = 32}
package.loaded["core.development_counters"] = {}

local Waves = require("systems.waves")
local function signature(wave)
	local parts = {tostring(wave.boss), tostring(wave.count)}
	for _, group in ipairs(wave.groups) do
		parts[#parts + 1] = table.concat({group.kind, group.count, group.spacing,
			group.eliteTrait or "-"}, ":")
	end
	return table.concat(parts, "|")
end

local a = Waves.generateEndlessWave(21, 12345)
local b = Waves.generateEndlessWave(21, 12345)
assert(signature(a) == signature(b), "the saved seed must reproduce wave 21")
assert(signature(a) ~= signature(Waves.generateEndlessWave(21, 54321)),
	"different build seeds should change composition")
assert(not a.boss and Waves.generateEndlessWave(30, 12345).boss,
	"endless bosses must use a predictable ten-wave cadence")
assert(Waves.generateEndlessWave(25, 12345).groups[1].eliteTrait == "veteran",
	"five-wave milestones must introduce an elite trait")
for wave = 21, 10000 do
	local generated = Waves.generateEndlessWave(wave, 12345)
	assert(generated.count <= 96, "composition exceeded the bounded density budget")
	assert(#generated.groups <= 4, "composition exceeded the bounded group budget")
end

print("endless wave fixtures passed")
