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
assert(not first.generation.fallback and first.generation.attempt > 0,
	"random runs must use generated geometry, not an authored-map fallback")

local authored = require("world.map_defs")
local function samePath(a, b)
	if #a ~= #b then return false end
	for i = 1, #a do
		if a[i][1] ~= b[i][1] or a[i][2] ~= b[i][2] then return false end
	end
	return true
end
for seed = 1, 250 do
	local generated = Generator.generate("fixture-" .. seed)
	local seedValid, seedReason = Generator.validate(generated)
	assert(seedValid, "seed " .. seed .. " generated an invalid map: " .. tostring(seedReason))
	assert(not generated.generation.fallback, "seed " .. seed .. " selected from the map pool")
	for _, map in ipairs(authored) do
		assert(not samePath(generated.path, map.path), "seed " .. seed .. " copied an authored map")
	end
end

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
