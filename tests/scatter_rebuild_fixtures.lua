local calls = {}

local function decoration(name, tracksOccupied)
	local module = {list = {}}
	if tracksOccupied then module.occupied = {} end

	function module.generate(config)
		calls[#calls + 1] = name .. ":generate"
		module.list = {{config = config}}
		if tracksOccupied then module.occupied = {populated = true} end
	end

	function module.clear()
		calls[#calls + 1] = name .. ":clear"
		module.list = {}
		if tracksOccupied then module.occupied = {} end
	end

	return module
end

local Rocks = decoration("rocks")
local Trees = decoration("trees", true)
local Cacti = decoration("cactus")
local Mushrooms = decoration("mushrooms")

package.loaded["world.scatter_rocks"] = Rocks
package.loaded["world.scatter_trees"] = Trees
package.loaded["world.scatter_cactus"] = Cacti
package.loaded["world.scatter_mushrooms"] = Mushrooms

local Scatter = dofile("world/scatter.lua")
local enabled = {enabled = true}
Scatter.generateForBiome({scatter = {
	rocks = enabled,
	trees = enabled,
	cactus = enabled,
	mushrooms = enabled,
}})

assert(#Rocks.list == 1 and #Trees.list == 1 and #Cacti.list == 1 and #Mushrooms.list == 1,
	"an enabled rebuild must generate every decoration type")
assert(Trees.occupied.populated, "tree generation must populate its occupancy state")

Scatter.generateForBiome({})

assert(#Rocks.list == 0, "rocks must clear when scatter configuration is missing")
assert(#Trees.list == 0, "trees must clear when scatter configuration is missing")
assert(#Cacti.list == 0, "cactus must clear when scatter configuration is missing")
assert(#Mushrooms.list == 0, "mushrooms must clear when scatter configuration is missing")
assert(next(Trees.occupied) == nil, "clearing trees must reset occupied cells")

assert(table.concat(calls, ",") == table.concat({
	"rocks:generate", "trees:generate", "cactus:generate", "mushrooms:generate",
	"rocks:clear", "trees:clear", "cactus:clear", "mushrooms:clear",
}, ","), "scatter rebuilds must preserve generation order and always process every type")

print("scatter rebuild fixtures passed")
