local Maps = require("world.map_defs")
local Biomes = require("world.biomes")

local ashSpiral
for i = 1, #Maps do
	if Maps[i].id == "ashspiral" then
		ashSpiral = Maps[i]
		break
	end
end

assert(ashSpiral, "Ash Spiral map definition is missing")
assert(ashSpiral.biome == "rainbowRoad", "Ash Spiral must use the Rainbow Road biome")
assert(#ashSpiral.path == 6, "Ash Spiral should keep the simplified six-point route")
assert(not ashSpiral.water or #ashSpiral.water == 0, "space maps should not contain terrestrial water")

local biome = Biomes.resolve(ashSpiral)
assert(biome.terrain.backgroundStyle == "space")
assert(biome.terrain.pathStyle == "rainbow")
assert(#biome.terrain.rainbow == 7, "Rainbow Road must render all seven colour bands")
assert(next(biome.scatter) == nil, "space biome must not scatter terrestrial decorations")

print("ash spiral map fixtures passed")
