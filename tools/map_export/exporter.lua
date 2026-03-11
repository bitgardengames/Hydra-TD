local Config = require("tools.map_export.config")
local Maps = require("world.map_defs")
local State = require("core.state")
local Constants = require("core.constants")
local Camera = require("core.camera")
local DrawWorld = require("render.draw_world")
local Theme = require("core.theme")

local lg = love.graphics
local floor = math.floor
local min = math.min

local Exporter = {
	active = false,
	queue = {},
	i = 1,

	canvas = nil,
	w = 0,
	h = 0,

	rendered = {},
}

local function ensureDir(path)
	love.filesystem.createDirectory(path)
end

local function mapWorldSize()
	local mw = Constants.GRID_W * Constants.TILE
	local mh = Constants.GRID_H * Constants.TILE

	return mw, mh
end

local function resetWorldToMap(mapIndex)
	State.mode = "game"
	State.worldMapIndex = mapIndex

	if resetGame then
		resetGame()
	end
end

local function renderMapToCanvas(canvasW, canvasH)
	local winW, winH = lg.getDimensions()

	-- Scale logical window coords → canvas coords
	local sx = canvasW / winW
	local sy = canvasH / winH

	local z = Camera.wscale

	local mapW, mapH = mapWorldSize()
	local cx = mapW * 0.5
	local cy = mapH * 0.5

	lg.push()

	-- Reset any inherited transforms
	lg.origin()

	-- Fill the canvas
	lg.scale(sx, sy)

	-- === Gameplay camera transform (unchanged) ===
	lg.scale(z, z)

	local wx = cx - (winW / (2 * z))
	local wy = cy - (winH / (2 * z))

	lg.translate(-wx, -wy)

	if Config.drawGrass then
		DrawWorld.drawGrass()
	end

	if Config.drawWater then
		DrawWorld.drawWater()
	end

	if Config.forcePathColor then
		DrawWorld.updatePathColor(Config.forcedPathColor)
	end

	DrawWorld.drawPath()

	DrawWorld.updatePathColor(Theme.terrain.path)

	lg.pop()
end

local function exportPNG(canvas, pathNoExt)
	local img = canvas:newImageData()
	img:encode("png", pathNoExt .. ".png")
end

local function exportStitchedHorizontal()
	if not (Config.stitch and Config.stitch.enabled) then
		return
	end

	local padding = Config.stitch.padding or 0

	-- Determine base size from first rendered map
	local first

	for _, canvas in pairs(Exporter.rendered) do
		first = canvas

		break
	end

	if not first then
		return
	end

	local w = first:getWidth()
	local h = first:getHeight()

	local count = 0
	for _ in pairs(Exporter.rendered) do
		count = count + 1
	end

	local totalW = count * w + (count - 1) * padding
	local canvas = lg.newCanvas(totalW, h, {msaa = 8})

	lg.setCanvas(canvas)
	lg.clear(0, 0, 0, 0)

	local xOffset = 0

	for _, def in ipairs(Maps) do
		if Exporter.rendered[def.id] then
			lg.draw(Exporter.rendered[def.id], xOffset, 0)
			xOffset = xOffset + w + padding
		end
	end

	lg.setCanvas()

	local out = string.format("%s/%s", Config.outDir, Config.stitch.filename)
	exportPNG(canvas, out)

	print(string.format("[MapExport] stitched -> %s", out))
end

function Exporter.initSize(w, h)
	Exporter.w = w
	Exporter.h = h
	Exporter.canvas = lg.newCanvas(w, h, {msaa = 8})
end

function Exporter.start()
	Exporter.active = true
	Exporter.i = 1
	Exporter.queue = {}

	for idx, def in ipairs(Maps) do
		if not (Config.skip and Config.skip[def.id]) then
			table.insert(Exporter.queue, { index = idx, id = def.id })
		end
	end

	ensureDir(Config.outDir)
end

function Exporter.update(dt)
	if not Exporter.active then
		return
	end

	local item = Exporter.queue[Exporter.i]

	if not item then
		exportStitchedHorizontal()

		Exporter.active = false
		love.event.quit()

		return
	end

	-- Load/reset cleanly
	resetWorldToMap(item.index)

	-- Render + save for each requested size
	for _, sz in ipairs(Config.sizes or {}) do
		Exporter.initSize(sz.w, sz.h)

		lg.setCanvas(Exporter.canvas)
		lg.clear(0, 0, 0, 0)

		renderMapToCanvas(sz.w, sz.h)

		lg.setCanvas()

		-- clone canvas into a new one (so it doesn't get overwritten)
		local clone = lg.newCanvas(sz.w, sz.h, {msaa = 8})

		lg.setCanvas(clone)
		lg.clear(0, 0, 0, 0)
		lg.setColor(1, 1, 1, 1)
		lg.draw(Exporter.canvas)
		lg.setCanvas()

		-- store by map id
		Exporter.rendered[item.id] = clone

		-- still export individual file
		local order = string.format("%02d", item.index)
		local out = string.format("%s/%s_%s_%dx%d", Config.outDir, order, item.id, sz.w, sz.h)

		exportPNG(clone, out)
		print(string.format("[MapExport] %s", out))
	end

	Exporter.i = Exporter.i + 1
end

function Exporter.draw()
	-- Optional: show a simple progress screen, or nothing.
	lg.clear(0, 0, 0, 1)
	lg.print("Exporting maps... " .. tostring(Exporter.i) .. "/" .. tostring(#Exporter.queue), 20, 20)
end

return Exporter