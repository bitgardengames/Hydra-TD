local Rocks = require("world.scatter_rocks")
local Trees = require("world.scatter_trees")
local Cacti = require("world.scatter_cactus")
local Mushrooms = require("world.scatter_mushrooms")

local Scatter = {}

local function rebuild(decoration, config)
	if config and config.enabled then
		decoration.generate(config)
	else
		decoration.clear()
	end
end

function Scatter.generateForBiome(biome)
	local config = biome and biome.scatter or {}

	-- Keep this order stable: existing placement rules can consult decoration
	-- state produced by an earlier generator.
	rebuild(Rocks, config.rocks)
	rebuild(Trees, config.trees)
	rebuild(Cacti, config.cactus)
	rebuild(Mushrooms, config.mushrooms)
end

return Scatter
