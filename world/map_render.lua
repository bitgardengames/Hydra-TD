local DrawWorld = require("render.draw_world")
local Constants = require("core.constants")
local Camera = require("core.camera")

local MapRender = {}

local lg = love.graphics

local MAP_W = Constants.GRID_W * Constants.TILE
local MAP_H = Constants.GRID_H * Constants.TILE

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

function MapRender.renderGameplayFramedToCanvas(canvas)
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

	-- Match gameplay camera framing, then scale that framed view into the preview box.
	lg.scale(sx, sy)
	lg.scale(z, z)
	lg.translate(-camWX, -camWY)

	DrawWorld.drawGrass()
	DrawWorld.drawPath()
	DrawWorld.drawScatter()

	lg.pop()
	lg.setCanvas()
end

return MapRender