local Constants = require("core.constants")

local Spatial = {}

local floor = math.floor
local TILE = Constants.TILE

local CELL_SIZE = TILE * 2
local INV_CELL = 1 / CELL_SIZE

-- grid[cx][cy] = {enemies}
Spatial.grid = {}

-- Reusable query buffer
local queryBuffer = {}

function Spatial.clear()
	local grid = Spatial.grid

	for cx in pairs(grid) do
		grid[cx] = nil
	end
end

function Spatial.insert(e)
	local cx = floor(e.x * INV_CELL)
	local cy = floor(e.y * INV_CELL)

	local grid = Spatial.grid
	local col = grid[cx]

	if not col then
		col = {}
		grid[cx] = col
	end

	local cell = col[cy]

	if not cell then
		cell = {}
		col[cy] = cell
	end

	cell[#cell + 1] = e
end

function Spatial.rebuild(enemies)
	Spatial.clear()

	for i = 1, #enemies do
		Spatial.insert(enemies[i])
	end
end

function Spatial.queryCells(x, y)
	local results = queryBuffer

	-- Clear buffer
	for i = 1, #results do
		results[i] = nil
	end

	local cx = floor(x * INV_CELL)
	local cy = floor(y * INV_CELL)

	local grid = Spatial.grid

	for dx = -1, 1 do
		local col = grid[cx + dx]

		if col then
			for dy = -1, 1 do
				local cell = col[cy + dy]

				if cell then
					local n = #cell

					for i = 1, n do
						results[#results + 1] = cell[i]
					end
				end
			end
		end
	end

	return results
end

return Spatial