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

local worldCanvas = nil

-- Precomputed scatter colors
local colorScatterDark  = {colorGrass[1] * 0.78, colorGrass[2] * 0.78, colorGrass[3] * 0.78, 0.2}
local colorScatterLight = {colorGrass[1] * 1.12, colorGrass[2] * 1.12, colorGrass[3] * 1.12, 0.2}

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

local function drawPath()
	-- Path visual thickness
	local thickness = tile
	local radius = thickness * 0.5

	local path = MapMod.map.path
	local count = #path

	lg.setColor(colorPath)

	for i = 1, count - 1 do
		local a = path[i]
		local b = path[i + 1]

		-- World-space centers
		local ax, ay = gridToCenter(a[1], a[2])
		local bx, by = gridToCenter(b[1], b[2])

		-- Snap once for clean rasterization
		ax = math.floor(ax + 0.5)
		ay = math.floor(ay + 0.5)
		bx = math.floor(bx + 0.5)
		by = math.floor(by + 0.5)

		if ax ~= bx then
			-- Horizontal segment
			local x = math.min(ax, bx) - radius
			local y = ay - radius
			local w = math.abs(bx - ax) + thickness
			local h = thickness

			lg.rectangle("fill", x, y, w, h, radius, radius)
		else
			-- Vertical segment
			local x = ax - radius
			local y = math.min(ay, by) - radius
			local w = thickness
			local h = math.abs(by - ay) + thickness

			lg.rectangle("fill", x, y, w, h, radius, radius)
		end
	end
end

local function rebuildWorld()
	local w = gridW * tile
	local h = gridH * tile

	if worldCanvas then
		worldCanvas:release()
	end

	worldCanvas = lg.newCanvas(w, h, {msaa = 8})

	lg.push()
	lg.setCanvas(worldCanvas)
	lg.clear(0, 0, 0, 0)

	drawGrass()
	drawPath()

	lg.setCanvas()
	lg.pop()
end

local function drawWorld()
	if not worldCanvas then
		rebuildWorld()
	end

	lg.setColor(1, 1, 1, 1)
	lg.draw(worldCanvas, 0, 0)
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
	drawWorld = drawWorld,
	drawGrid = drawGrid,
	rebuild = rebuildWorld,
}