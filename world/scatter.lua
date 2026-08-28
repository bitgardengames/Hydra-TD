local Rocks = require("world.scatter_rocks")
local Trees = require("world.scatter_trees")
local Cacti = require("world.scatter_cactus")
local Mushrooms = require("world.scatter_mushrooms")

local Scatter = {}

local function rebuild(decoration, config, map, mapIndex, list, occupied)
	if config and config.enabled then
		local generated, generatedOccupied = decoration.generate(map, mapIndex, list, occupied, config)
		return generated or decoration.list or list,
			generatedOccupied or decoration.occupied or occupied
	end
	return list, occupied
end

function Scatter.generate(map, mapIndex, destination, biome)
	destination = destination or {
		rocks = {}, trees = {}, treeOccupied = {}, cacti = {}, mushrooms = {},
	}
	biome = biome or (map and map.biome)
	local config = biome and biome.scatter or {}

	-- Keep this order stable: existing placement rules can consult decoration
	-- state produced by an earlier generator.
	destination.rocks = rebuild(Rocks, config.rocks, map, mapIndex, destination.rocks)
	destination.trees, destination.treeOccupied = rebuild(
		Trees, config.trees, map, mapIndex, destination.trees, destination.treeOccupied)
	destination.cacti = rebuild(Cacti, config.cactus, map, mapIndex, destination.cacti, destination.treeOccupied)
	destination.mushrooms = rebuild(Mushrooms, config.mushrooms, map, mapIndex, destination.mushrooms)
	return destination
end

function Scatter.generateForBiome(biome)
	local Map = require("world.map")
	local State = require("core.state")
	local config = biome and biome.scatter or {}
	local bundle = Scatter.generate(Map.map, State.worldMapIndex, nil, biome)
	Rocks.list = bundle.rocks
	Trees.list, Trees.occupied = bundle.trees, bundle.treeOccupied
	Cacti.list, Mushrooms.list = bundle.cacti, bundle.mushrooms
	-- Preserve clear() calls and their module-specific semantics for disabled live state.
	if not (config.rocks and config.rocks.enabled) then Rocks.clear() end
	if not (config.trees and config.trees.enabled) then Trees.clear() end
	if not (config.cactus and config.cactus.enabled) then Cacti.clear() end
	if not (config.mushrooms and config.mushrooms.enabled) then Mushrooms.clear() end
	return bundle
end

return Scatter
