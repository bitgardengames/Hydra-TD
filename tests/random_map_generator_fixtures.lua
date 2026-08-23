local Generator = require("world.random_map_generator")
local Modifiers = require("systems.daily_modifiers")

local function signature(map)
	local parts = {map.id, map.biome, tostring(map.generation.seed), tostring(map.generation.attempt)}
	for _, p in ipairs(map.path) do parts[#parts + 1] = p[1] .. "," .. p[2] end
	for _, w in ipairs(map.water) do parts[#parts + 1] = table.concat(w, ",") end
	return table.concat(parts, "|")
end

local first = Generator.generate("2026-08-23", {mode = "daily", modifierSet = "blitz"})
local repeated = Generator.generate("2026-08-23", {mode = "daily", modifierSet = "blitz"})
assert(signature(first) == signature(repeated), "the same tuple must reproduce the map")
assert(signature(first) ~= signature(Generator.generate("2026-08-24", {mode = "daily", modifierSet = "blitz"})),
	"different dates should produce different definitions")
local valid, reason = Generator.validate(first)
assert(valid, "generated map was invalid: " .. tostring(reason))

math.randomseed(918273)
local globalBefore = math.random()
Generator.generate("does-not-touch-global-rng")
local globalAfter = math.random()
math.randomseed(918273)
assert(globalBefore == math.random() and globalAfter == math.random(), "generation changed Lua's global RNG")

local group = Modifiers.applyToGroup({kind = "grunt", count = 10, spacing = 0.5}, {modifiers = {"swarm"}})
assert(group.count == 16 and group.spacing >= 0.10, "swarm did not transform a group")
local enemy = Modifiers.applyToEnemy({hp = 100, maxHp = 100, baseSpeed = 40, speed = 40},
	{modifiers = {"fortified", "blitz"}})
assert(enemy.hp == 140 and enemy.maxHp == 140 and enemy.speed == 50, "enemy modifiers used the wrong stage")
assert(not Modifiers.validate({modifiers = {"swarm", "fortified"}}), "opposed modifiers must be rejected")
local state = {lives = 20, maxLives = 20, runRules = {modifiers = {"one_life", "relentless"}}}
local rules = Modifiers.configureRun(state)
assert(state.lives == 1 and rules.automaticWaves and not rules.earlyStartReward, "run behavior was not configured")

print("random map generator fixtures passed")
