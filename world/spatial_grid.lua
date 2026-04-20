local Constants = require("core.constants")

local Spatial = {}

local floor = math.floor
local ceil = math.ceil
local TILE = Constants.TILE

local CELL_SIZE = TILE * 2
local INV_CELL = 1 / CELL_SIZE

local grid = {}
Spatial.grid = grid

local queryBuffer = {}
local queryCount = 0

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

function Spatial.queryCells(x, y, radius)
	local results = queryBuffer

	local cx = floor(x * INV_CELL)
	local cy = floor(y * INV_CELL)
	local cellRadius = 2

	if radius and radius > 0 then
		-- Keep legacy upper bound for compatibility; shrink neighborhood for small-radius queries.
		cellRadius = ceil(radius * INV_CELL)
		if cellRadius < 1 then
			cellRadius = 1
		elseif cellRadius > 2 then
			cellRadius = 2
		end
	end

	local count = 0

	for dx = -cellRadius, cellRadius do
		local col = grid[cx + dx]

		if col then
			for dy = -cellRadius, cellRadius do
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

	queryCount = count

	--[[tsort(results, function(a, b)
		return a.id < b.id
	end)]]

	return results
end

function Spatial.queryCellsCount()
	return queryCount
end

return Spatial
