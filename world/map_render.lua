local DrawWorld = require("render.draw_world")
local Constants = require("core.constants")
local Camera = require("core.camera")
local MapMod = require("world.map")

local MapRender = {}

local lg = love.graphics

local MAP_W = Constants.GRID_W * Constants.TILE
local MAP_H = Constants.GRID_H * Constants.TILE

local function withRenderContext(context, fn)
	if not context or not context.map then
		return fn()
	end

	local previousMap = MapMod.map
	MapMod.map = context.map
	local ok, err = pcall(fn)
	MapMod.map = previousMap

	if not ok then
		error(err)
	end
end

function MapRender.renderWorldToCanvas(canvas, scale)
	lg.setCanvas(canvas)
	lg.clear(0, 0, 0, 0)

	lg.push()
	lg.origin()
	lg.scale(scale, scale)

	DrawWorld.drawGrass()
	DrawWorld.drawPath()
	DrawWorld.drawScatter()

	lg.pop()
	lg.setCanvas()
end

function MapRender.renderGameplayFramedToCanvas(canvas, context)
	local canvasW, canvasH = canvas:getDimensions()
	local winW, winH = love.graphics.getDimensions()

	local z = Camera.wscale

	local mapCX = MAP_W * 0.5
	local mapCY = MAP_H * 0.5

	local camWX = mapCX - (winW / (2 * z))
	local camWY = mapCY - (winH / (2 * z))

	local sx = canvasW / winW
	local sy = canvasH / winH

	lg.setCanvas(canvas)
	lg.clear(0, 0, 0, 0)

	lg.push()
	lg.origin()

	lg.scale(sx, sy)
	lg.scale(z, z)
	lg.translate(-camWX, -camWY)

	withRenderContext(context, function()
		DrawWorld.drawGrass()
		DrawWorld.drawPath()
		DrawWorld.drawScatter()
	end)

	lg.pop()
	lg.setCanvas()
end

return MapRender
