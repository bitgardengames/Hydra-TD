local Constants = require("core.constants")
local State = require("core.state")
local Camera = require("core.camera")
local DrawWorld = require("render.draw_world")
local Theme = require("core.theme")

local MapRender = {}

local lg = love.graphics

local function mapWorldSize()
	return Constants.GRID_W * Constants.TILE, Constants.GRID_H * Constants.TILE
end

-- Core render function (extracted from your exporter)
function MapRender.renderToCanvas(canvas, opts)
	opts = opts or {}

	local canvasW = canvas:getWidth()
	local canvasH = canvas:getHeight()

	local winW, winH = lg.getDimensions()

	local sx = canvasW / winW
	local sy = canvasH / winH

	local z = 1.60 or Camera.wscale

	local mapW, mapH = mapWorldSize()
	local cx = mapW * 0.5
	local cy = mapH * 0.5

	lg.setCanvas(canvas)
	lg.clear(0, 0, 0, 0)

	lg.push()
	lg.origin()

	lg.scale(sx, sy)
	lg.scale(z, z)

	local wx = cx - (winW / (2 * z))
	local wy = cy - (winH / (2 * z))

	lg.translate(-wx, -wy)

	-- Render layers
	if opts.drawGrass ~= false then
		DrawWorld.drawGrass()
	end

	if opts.drawWater ~= false then
		--DrawWorld.drawWater()
	end

	if opts.drawScatter ~= false then
		DrawWorld.drawScatter()
	end

	if opts.forcePathColor then
		DrawWorld.updatePathColor(opts.forcePathColor)
	end

	DrawWorld.drawPath()

	-- restore
	DrawWorld.updatePathColor(Theme.terrain.path)

	lg.pop()
	lg.setCanvas()
end

return MapRender