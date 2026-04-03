local Constants = require("core.constants")
local Camera = require("core.camera")
local MapRender = require("world.map_render")

local lg = love.graphics

local MapWorldCache = {}

local canvas = nil
local cachedScale = nil

local function getMapSize()
	return Constants.GRID_W * Constants.TILE,
	       Constants.GRID_H * Constants.TILE
end

function MapWorldCache.build()
	local scale = Camera.wscale

	if canvas and cachedScale == scale then
		return
	end

	local mapW, mapH = getMapSize()

	canvas = lg.newCanvas(
		mapW * scale,
		mapH * scale,
		{ msaa = 8 }
	)

	cachedScale = scale

	MapRender.renderWorldToCanvas(canvas, scale)
end

function MapWorldCache.draw()
	if not canvas then
		return
	end

	local inv = 1 / Camera.wscale
	lg.draw(canvas, 0, 0, 0, inv, inv)
end

function MapWorldCache.invalidate()
	canvas = nil
	cachedScale = nil
end

return MapWorldCache