local Biomes = require("world.biomes")
local Maps = require("world.map_defs")

local highlands = Biomes.defs.highlands
assert(highlands, "the highlands biome must be registered")
assert(highlands.terrain.grass ~= Biomes.defs.default.terrain.grass,
	"highlands must own a distinct grass palette")
assert(highlands.terrain.grass[1] ~= Biomes.defs.default.terrain.grass[1]
	or highlands.terrain.grass[2] ~= Biomes.defs.default.terrain.grass[2]
	or highlands.terrain.grass[3] ~= Biomes.defs.default.terrain.grass[3],
	"highlands grass tones must differ from the default biome")
assert(highlands.scatter.trees.enabled and highlands.scatter.rocks.enabled,
	"highlands must retain both trees and stone scatter")
assert(#highlands.world.tree.styles >= 3 and #highlands.world.rock.styles >= 3,
	"highlands trees and stones must have varied tone sets")

local assigned = {}
for _, map in ipairs(Maps) do
	if map.biome == "highlands" then
		assigned[map.id] = true
	end
end

assert(assigned.highpass and assigned.highridge,
	"the mountain campaign maps must showcase the highlands biome")

local resolved = Biomes.resolve({biome = "highlands"})
resolved.terrain.grass[1] = 1
assert(highlands.terrain.grass[1] ~= 1,
	"resolved highlands palettes must not mutate the shared definition")

print("highlands biome fixtures passed")
