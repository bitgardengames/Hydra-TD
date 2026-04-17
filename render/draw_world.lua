local Constants = require("core.constants")
local Theme = require("core.theme")
local MapMod = require("world.map")
local State = require("core.state")
local Trees = require("world.scatter_trees")
local Cacti = require("world.scatter_cactus")
local Rocks = require("world.scatter_rocks")
local Mushrooms = require("world.scatter_mushrooms")

local lg = love.graphics
local min = math.min
local sin = math.sin
local abs = math.abs
local sqrt = math.sqrt
local floor = math.floor

local tile = Constants.TILE
local gridW = Constants.GRID_W
local gridH = Constants.GRID_H

local colorGrid = Theme.grid
local outlineW = Theme.outline.width

local gridToCenter = MapMod.gridToCenter

local worldCanvas = nil
local worldCanvasZoom = nil

local function rebuildWorldCanvas()
	local w = lg.getWidth()
	local h = lg.getHeight()

	local zoom = Camera.zoom

	worldCanvas = lg.newCanvas(w, h, {msaa = 8})

	worldCanvasZoom = zoom

	lg.setCanvas(worldCanvas)
	lg.clear()

	lg.push()

	-- Apply zoom, not translation
	lg.scale(zoom, zoom)

	-- Draw world at origin-relative coordinates
	drawWorldStatic()

	lg.pop()

	lg.setCanvas()
end

local function getTerrain()
	local biome = MapMod.map and MapMod.map.biome

	if biome and biome.terrain then
		return biome.terrain
	end

	return Theme.terrain
end

local function hashNoise(x, y, seed)
	local n = sin(x * 127.1 + y * 311.7 + seed * 74.7) * 43758.5453

	return n - floor(n)
end

local function drawGrass()
	local terrain = getTerrain()

	local grass = terrain.grass

	lg.setColor(grass)
	lg.rectangle("fill", 0, 0, gridW * tile, gridH * tile)

	local colorScatterDark = {grass[1] * 0.94, grass[2] * 0.94, grass[3] * 0.94, 1}
	local colorScatterLight = {grass[1] * 1.06, grass[2] * 1.06, grass[3] * 1.06, 1}

	for y = 1, gridH do
		for x = 1, gridW do
			local col = MapMod.map.isPath[x]

			if not (col and col[y]) then
				local seed = (x * 127 + y * 331) % 997
				local r = seed % 4

				if r == 0 then
					local useLight = (seed % 7) < 3

					lg.setColor(useLight and colorScatterLight or colorScatterDark)

					for i = 1, 2 do
						local ox = (seed * (13 + i * 17)) % (tile - 8) + 4
						local oy = (seed * (29 + i * 23)) % (tile - 8) + 4

						lg.rectangle("fill", (x - 1) * tile + ox, (y - 1) * tile + oy, 6, 6, 2)
					end
				end
			end
		end
	end
end

local function isWater(gx, gy)
	local water = MapMod.map.water

	if not water then
		return false
	end

	for i = 1, #water do
		local blob = water[i]
		local bx, by, r = blob[1], blob[2], blob[3]

		local dx = gx - bx
		local dy = gy - by
		local d = sqrt(dx * dx + dy * dy)

		local n = hashNoise(gx, gy, i)

		local edge = r * (1 + (n - 0.5) * 0.36)

		if d <= edge then
			return true
		end
	end

	return false
end

local function drawWater()
	local radius = 8
	local water = MapMod.map.water

	if not water then
		return
	end

	local terrain = getTerrain()

	lg.setColor(terrain.water)

	for i = 1, #water do
		local blob = water[i]
		local bx, by, r = blob[1], blob[2], blob[3]

		for y = -r - 1, r + 1 do
			for x = -r - 1, r + 1 do

				local gx = bx + x
				local gy = by + y

				if gx >= 1 and gx <= gridW and gy >= 1 and gy <= gridH then
					if isWater(gx, gy) then

						local wx = (gx - 1) * tile
						local wy = (gy - 1) * tile

						-- Base rounded tile
						lg.rectangle("fill", wx, wy, tile, tile, radius, radius)

						-- Fill horizontal seam
						if isWater(gx + 1, gy) then
							lg.rectangle("fill", wx + tile - radius, wy, radius * 2, tile)
						end

						-- Fill vertical seam
						if isWater(gx, gy + 1) then
							lg.rectangle("fill", wx, wy + tile - radius, tile, radius * 2)
						end
					end
				end
			end
		end
	end
end

local function updatePathColor(color)
	colorPath = color
end

local function updateGrassColor(color)
	colorGrass = color

	colorScatterDark = {color[1] * 0.94, color[2] * 0.94, color[3] * 0.94, 1}
	colorScatterLight = {color[1] * 1.06, color[2] * 1.06, color[3] * 1.06, 1}
end

local function updateWaterColor(color)
	colorWater = color
end

-- This system is already getting ready for a rework
local function drawScatter()
	local biome = MapMod.map and MapMod.map.biome
	local scatter = biome and biome.scatter

	if not scatter then
		return
	end

	if scatter.rocks and scatter.rocks.enabled then
		Rocks.draw()
	end

	if scatter.trees and scatter.trees.enabled then
		Trees.draw()
	end

	if scatter.cactus and scatter.cactus.enabled then
		Cacti.draw()
	end

	if scatter.mushrooms and scatter.mushrooms.enabled then
		Mushrooms.draw()
	end
end

local function drawPath()
	local pathThickness = tile

	local outlineThickness = pathThickness
	local halfOutline = outlineThickness * 0.5

	local fillThickness = pathThickness - outlineW * 2
	local halfFill = fillThickness * 0.5

	local terrain = getTerrain()

	-- Outline
	lg.setColor(terrain.pathOutline)

	for i = 1, #MapMod.map.path - 1 do
		local a = MapMod.map.path[i]
		local b = MapMod.map.path[i + 1]

		local ax, ay = gridToCenter(a[1], a[2])
		local bx, by = gridToCenter(b[1], b[2])

		local dx = b[1] - a[1]
		local dy = b[2] - a[2]

		local trimA, trimB = false, false

		if i > 1 then
			local p = MapMod.map.path[i - 1]
			trimA = (p[1] ~= b[1] and p[2] ~= b[2])
		end

		if i < #MapMod.map.path - 1 then
			local n = MapMod.map.path[i + 2]
			trimB = (n[1] ~= a[1] and n[2] ~= a[2])
		end

		if dx ~= 0 then
			local x1 = min(ax, bx)
			local w = abs(bx - ax)

			if trimA then
				x1 = x1 + halfOutline
				w = w - halfOutline
			end

			if trimB then
				w = w - halfOutline
			end

			lg.rectangle("fill", x1, ay - halfOutline, w, outlineThickness)
		else
			local y1 = min(ay, by)
			local h = abs(by - ay)

			if trimA then
				y1 = y1 + halfOutline
				h = h - halfOutline
			end

			if trimB then
				h = h - halfOutline
			end

			lg.rectangle("fill", ax - halfOutline, y1, outlineThickness, h)
		end
	end

	for i = 2, #MapMod.map.path - 1 do
		local prev = MapMod.map.path[i - 1]
		local cur = MapMod.map.path[i]
		local next = MapMod.map.path[i + 1]

		local dx1 = cur[1] - prev[1]
		local dy1 = cur[2] - prev[2]
		local dx2 = next[1] - cur[1]
		local dy2 = next[2] - cur[2]

		if dx1 ~= dx2 or dy1 ~= dy2 then
			local cx, cy = gridToCenter(cur[1], cur[2])
			lg.circle("fill", cx, cy, halfOutline)
		end
	end

	-- Fill
	lg.setColor(terrain.path)

	for i = 1, #MapMod.map.path - 1 do
		local a = MapMod.map.path[i]
		local b = MapMod.map.path[i + 1]

		local ax, ay = gridToCenter(a[1], a[2])
		local bx, by = gridToCenter(b[1], b[2])

		local dx = b[1] - a[1]
		local dy = b[2] - a[2]

		local trimA, trimB = false, false

		if i > 1 then
			local p = MapMod.map.path[i - 1]
			trimA = (p[1] ~= b[1] and p[2] ~= b[2])
		end

		if i < #MapMod.map.path - 1 then
			local n = MapMod.map.path[i + 2]
			trimB = (n[1] ~= a[1] and n[2] ~= a[2])
		end

		if dx ~= 0 then
			local x1 = min(ax, bx)
			local w = abs(bx - ax)

			if trimA then
				x1 = x1 + half
				w = w - half
			end

			if trimB then
				w = w - half
			end

			lg.rectangle("fill", x1, ay - halfFill, w, fillThickness)
		else
			local y1 = min(ay, by)
			local h = abs(by - ay)

			if trimA then
				y1 = y1 + half
				h = h - half
			end

			if trimB then
				h = h - half
			end

			lg.rectangle("fill", ax - halfFill, y1, fillThickness, h)
		end
	end

	for i = 2, #MapMod.map.path - 1 do
		local prev = MapMod.map.path[i - 1]
		local cur = MapMod.map.path[i]
		local next = MapMod.map.path[i + 1]

		local dx1 = cur[1] - prev[1]
		local dy1 = cur[2] - prev[2]
		local dx2 = next[1] - cur[1]
		local dy2 = next[2] - cur[2]

		if dx1 ~= dx2 or dy1 ~= dy2 then
			local cx, cy = gridToCenter(cur[1], cur[2])
			lg.circle("fill", cx, cy, halfFill)
		end
	end
end

local function drawWorld()
	drawGrass()
	--drawWater()
	drawPath()
	drawScatter()
end

local function drawGrid()
	local fade = State.placingFade or 0
	if fade == 0 then return end

	lg.setColor(colorGrid[1], colorGrid[2], colorGrid[3], colorGrid[4] * fade)

	for x = 0, gridW do
		lg.line(x * tile, 0, x * tile, gridH * tile)
	end

	for y = 0, gridH do
		lg.line(0, y * tile, gridW * tile, y * tile)
	end
end

return {
	drawGrass = drawGrass,
	drawWater = drawWater,
	drawPath = drawPath,
	drawScatter = drawScatter,
	drawGrid = drawGrid,
	drawWorld = drawWorld,
	updatePathColor = updatePathColor,
	updateGrassColor = updateGrassColor,
	updateWaterColor = updateWaterColor,
}