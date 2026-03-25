local MapPreviewCache = {}

local Maps = require("world.map_defs")
local MapMod = require("world.map")
local State = require("core.state")
local Constants = require("core.constants")
local MapRender = require("world.map_render")

local lg = love.graphics

local mapW = Constants.GRID_W * Constants.TILE
local mapH = Constants.GRID_H * Constants.TILE

local cache = {}

-- Clone pathWorld so it doesn't get overwritten later
local function clonePathWorld(path)
	local out = {}

	for i = 1, #path do
		out[i] = {path[i][1], path[i][2]}
	end

	return out
end

function MapPreviewCache.buildAll(w, h)
	for i, map in ipairs(Maps) do
		State.worldMapIndex = i

		if resetGame then
			resetGame()
		end

		local canvas = lg.newCanvas(w, h, {msaa = 8})

		MapRender.renderToCanvas(canvas)

		cache[map.id] = {
			canvas = canvas,
			pathWorld = clonePathWorld(MapMod.map.pathWorld),
			mapW = mapW,
			mapH = mapH,
		}
	end
end

function MapPreviewCache.get(mapId)
	return cache[mapId]
end

return MapPreviewCache