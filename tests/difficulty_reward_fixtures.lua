-- Enemy kill values are authored properties, not difficulty modifiers.
local difficultySource = assert(io.open("systems/difficulty.lua", "r")):read("*a")
local enemySource = assert(io.open("world/enemies.lua", "r")):read("*a")

assert(not difficultySource:find("rewardBias", 1, true),
	"difficulty definitions must not alter enemy kill values")
assert(enemySource:find("e.reward = def.reward", 1, true),
	"spawned enemies must retain their authored kill value")
assert(not enemySource:find("def.reward * Difficulty", 1, true),
	"enemy kill values must not be multiplied by difficulty")

print("difficulty reward fixtures passed")
