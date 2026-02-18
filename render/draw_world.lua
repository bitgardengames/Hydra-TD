local Constants = require("core.constants")
local Theme = require("core.theme")
local MapMod = require("world.map")
local State = require("core.state")

local lg = love.graphics
local min = math.min
local abs = math.abs

local tile = Constants.TILE
local gridW = Constants.GRID_W
local gridH = Constants.GRID_H

local colorGrass = Theme.terrain.grass
local colorPath = Theme.terrain.path
local colorGrid = Theme.grid

local gridToCenter = MapMod.gridToCenter

-- Precomputed scatter colors
local colorScatterDark  = {colorGrass[1] * 0.94, colorGrass[2] * 0.94, colorGrass[3] * 0.94, 1}
local colorScatterLight = {colorGrass[1] * 1.06, colorGrass[2] * 1.06, colorGrass[3] * 1.06, 1}

-- Static world drawing
local function drawGrass()
	lg.setColor(colorGrass)
	lg.rectangle("fill", 0, 0, gridW * tile, gridH * tile)

	for y = 1, gridH do
		for x = 1, gridW do
			local k = MapMod.makeKey(x, y)

			if not MapMod.map.isPath[k] then
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

local function updatePathColor(color)
	colorPath = color
end

local function drawPath()
	local pathThickness = tile
	local half = pathThickness * 0.5

	lg.setColor(colorPath)

	for i = 1, #MapMod.map.path - 1 do
		local a = MapMod.map.path[i]
		local b = MapMod.map.path[i + 1]

		local ax, ay = MapMod.gridToCenter(a[1], a[2])
		local bx, by = MapMod.gridToCenter(b[1], b[2])

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
			local w  = abs(bx - ax)

			if trimA then
				x1 = x1 + half
				w = w - half
			end

			if trimB then
				w  = w - half
			end

			lg.rectangle("fill", x1, ay - half, w, pathThickness)
		else
			local y1 = min(ay, by)
			local h  = abs(by - ay)

			if trimA then
				y1 = y1 + half
				h = h - half
			end

			if trimB then
				h  = h - half
			end

			lg.rectangle("fill", ax - half, y1, pathThickness, h)
		end
	end

	-- Rounded corners
	for i = 2, #MapMod.map.path - 1 do
		local prev = MapMod.map.path[i - 1]
		local cur = MapMod.map.path[i]
		local next = MapMod.map.path[i + 1]

		local dx1 = cur[1] - prev[1]
		local dy1 = cur[2] - prev[2]
		local dx2 = next[1] - cur[1]
		local dy2 = next[2] - cur[2]

		if dx1 ~= dx2 or dy1 ~= dy2 then
			local cx, cy = MapMod.gridToCenter(cur[1], cur[2])

			lg.circle("fill", cx, cy, half)
		end
	end
end

local function drawWorld()
	drawGrass()
	drawPath()
end

-- Grid
local function drawGrid()
	local fade = State.placingFade or 0

	if fade == 0 then
		return
	end

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
	drawPath = drawPath,
	drawGrid = drawGrid,
	drawWorld = drawWorld,
	updatePathColor = updatePathColor,
}