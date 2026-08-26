-- Shared aspect fitting and dependency-free victory call-site checks.
love = {graphics = {}}
for _, name in ipairs({
	"world.map_defs", "world.map", "world.map_render", "core.state",
	"world.scatter_trees", "world.scatter_cactus", "world.scatter_rocks",
	"world.scatter_mushrooms",
}) do
	package.loaded[name] = {}
end

local MapPreviewCache = dofile("world/map_preview_cache.lua")
local w, h = MapPreviewCache.fitDimensions(118, 68)
assert(w == 118 and h == 66,
	"aspect fitting must produce integer 1:1 dimensions approximating 16:9")
w, h = MapPreviewCache.fitDimensions(100, 40)
assert(w == 71 and h == 40, "aspect fitting must respect height-limited bounds")
w, h = MapPreviewCache.fitDimensions(7, 20)
assert(w == 7 and h == 4, "aspect fitting must respect width-limited bounds")

local file = assert(io.open("ui/menu/screens/victory.lua", "r"))
local source = file:read("*a")
file:close()
assert(source:find("MapPreviewCache.getFitted(map.id, previewBoundsW, previewBoundsH)", 1, true),
	"victory must use the shared fitted-preview API")
assert(source:find("(previewBoundsW - (previewW or 0)) * 0.5", 1, true)
	and source:find("(previewBoundsH - (previewH or 0)) * 0.5", 1, true),
	"victory must center the fitted preview in both available dimensions")
assert(source:find("local previewBottom = previewY + (previewH or 0)", 1, true)
	and source:find("previewBottom + 18", 1, true)
	and source:find("previewBottom + 52", 1, true),
	"victory stat rows must follow the fitted image's actual bottom edge")

print("victory map preview fixtures passed")
