local Constants = require("core.constants")

local Spatial = {}

local floor = math.floor
local TILE = Constants.TILE

local CELL_SIZE = TILE * 2
local INV_CELL = 1 / CELL_SIZE

local grid = {}
Spatial.grid = grid

local queryBuffer = {}

local function removeFromCell(e)
	local cell = e.cell

	if not cell then
		return
	end

	local list = cell
	local idx = e.cellIndex

	local last = #list
	local lastEnemy = list[last]

	list[idx] = lastEnemy
	list[last] = nil

	if idx ~= last then
		lastEnemy.cellIndex = idx
	end

	e.cell = nil
	e.cellIndex = nil
end

local function getCell(cx, cy)
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

	return cell
end

local function insertIntoCell(e, cx, cy)
	local cell = getCell(cx, cy)

	local idx = #cell + 1
	cell[idx] = e

	e.cell = cell
	e.cellIndex = idx
	e.cellX = cx
	e.cellY = cy
end

function Spatial.updateEnemy(e)
	local cx = floor(e.x * INV_CELL)
	local cy = floor(e.y * INV_CELL)

	if e.cellX == cx and e.cellY == cy then
		return
	end

	removeFromCell(e)
	insertIntoCell(e, cx, cy)
end

function Spatial.removeEnemy(e)
	removeFromCell(e)
end

local tsort = table.sort

function Spatial.queryCells(x, y)
	local results = queryBuffer

	local cx = floor(x * INV_CELL)
	local cy = floor(y * INV_CELL)

	local count = 0

	for dx = -2, 2 do
		local col = grid[cx + dx]

		if col then
			for dy = -2, 2 do
				local cell = col[cy + dy]

				if cell then
					for i = 1, #cell do
						count = count + 1
						results[count] = cell[i]
					end
				end
			end
		end
	end

	-- Maintain an exact logical length without clearing the whole buffer each query.
	results[count + 1] = nil

	--[[tsort(results, function(a, b)
		return a.id < b.id
	end)]]

	return results
end

return Spatial
