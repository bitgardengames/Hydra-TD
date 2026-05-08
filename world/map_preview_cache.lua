local MapPreviewCache = {}

local Maps = require("world.map_defs")
local MapMod = require("world.map")
local Constants = require("core.constants")
local MapRender = require("world.map_render")
local Camera = require("core.camera")

local lg = love.graphics

local mapW = Constants.GRID_W * Constants.TILE
local mapH = Constants.GRID_H * Constants.TILE

local cache = {}

local function clonePathWorld(path)
	local out = {}
	for i = 1, #path do
		out[i] = {path[i][1], path[i][2]}
	end
	return out
end

function MapPreviewCache.buildAll(w, h)
	local winW, winH = lg.getDimensions()

	for _, mapDef in ipairs(Maps) do
		local context = MapMod.createRenderContext(mapDef)
		local canvas = lg.newCanvas(w, h, {msaa = 8})

		MapRender.renderGameplayFramedToCanvas(canvas, context)

		cache[mapDef.id] = {
			canvas = canvas,
			pathWorld = clonePathWorld(context.map.pathWorld),
			mapW = mapW,
			mapH = mapH,
			winW = winW,
			winH = winH,
			camScale = Camera.wscale,
		}
	end
end

function MapPreviewCache.get(mapId)
	return cache[mapId]
end

return MapPreviewCache
