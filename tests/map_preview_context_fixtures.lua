-- Preview construction must be completely isolated from live world singletons,
-- both on success and when the renderer aborts midway through a build.
love = {graphics = {}}
local graphics = love.graphics
function graphics.newCanvas()
	return {setFilter = function() end, release = function() end,
		getDimensions = function() return 160, 90 end}
end

local liveMap = {sentinel = "live map"}
local MapMod = {
	map = liveMap,
	createRenderContext = function(def)
		return {map = {biome = def.biome, pathWorld = {{1, 2}, {3, 4}}}, mapDef = def}
	end,
}
local State = {worldMapIndex = 73}
local modules = {}
for _, name in ipairs({"trees", "cactus", "rocks", "mushrooms"}) do
	modules[name] = {list = {{name = name}}}
end
modules.trees.occupied = {unchanged = true}

local shouldFail = false
local receivedContext
local MapRender = {
	gameplayPreviewTransform = function()
		return {cameraScale = 1, destinationScale = 1, offsetX = 0, offsetY = 0,
			cameraX = 0, cameraY = 0}
	end,
	renderGameplayFramedToCanvas = function(_, context)
		receivedContext = context
		if shouldFail then error("fixture render failure") end
	end,
}
local Scatter = {generate = function(map, index)
	assert(map ~= liveMap and index == 1, "preview scatter must receive isolated map and explicit index")
	return {trees = {}, treeOccupied = {}, cacti = {}, rocks = {}, mushrooms = {}}
end}

package.loaded["core.constants"] = {TILE = 64}
package.loaded["world.map_defs"] = {{id = "fixture", biome = {}}}
package.loaded["world.map"] = MapMod
package.loaded["world.map_render"] = MapRender
package.loaded["core.state"] = State
package.loaded["world.scatter"] = Scatter
package.loaded["world.scatter_trees"] = modules.trees
package.loaded["world.scatter_cactus"] = modules.cactus
package.loaded["world.scatter_rocks"] = modules.rocks
package.loaded["world.scatter_mushrooms"] = modules.mushrooms

local Cache = dofile("world/map_preview_cache.lua")
local identities = {
	map = MapMod.map, index = State.worldMapIndex,
	trees = modules.trees.list, occupied = modules.trees.occupied,
	cactus = modules.cactus.list, rocks = modules.rocks.list, mushrooms = modules.mushrooms.list,
}
local function assertLiveStateUnchanged()
	assert(MapMod.map == identities.map and MapMod.map.sentinel == "live map")
	assert(State.worldMapIndex == identities.index)
	assert(modules.trees.list == identities.trees and modules.trees.list[1].name == "trees")
	assert(modules.trees.occupied == identities.occupied and modules.trees.occupied.unchanged)
	assert(modules.cactus.list == identities.cactus and modules.cactus.list[1].name == "cactus")
	assert(modules.rocks.list == identities.rocks and modules.rocks.list[1].name == "rocks")
	assert(modules.mushrooms.list == identities.mushrooms and modules.mushrooms.list[1].name == "mushrooms")
end

assert(Cache.get("fixture", 160, 90))
assert(receivedContext.map ~= liveMap and receivedContext.decorations,
	"renderer must consume the explicit preview context")
assertLiveStateUnchanged()

Cache.clear()
shouldFail = true
local ok, err = pcall(Cache.get, "fixture", 160, 90)
assert(not ok and tostring(err):find("fixture render failure", 1, true))
assertLiveStateUnchanged()

print("map preview context fixtures passed")
