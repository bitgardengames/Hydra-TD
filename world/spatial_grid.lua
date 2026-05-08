local Constants = require("core.constants")

local Spatial = {}

local floor = math.floor
local ceil = math.ceil
local TILE = Constants.TILE

local CELL_SIZE = TILE * 2
local INV_CELL = 1 / CELL_SIZE

local grid = {}
Spatial.grid = grid

local outerQueryBuffer = {}
local nestedQueryBuffer = {}
local occupancyBuffer = {}

local function nextStamp(ctx)
	local stamp = ctx.stamp + 1
	if stamp == math.maxinteger then
		for id in pairs(ctx.seen) do
			ctx.seen[id] = nil
		end
		stamp = 1
	end
	ctx.stamp = stamp
	return stamp
end

local outerCollectContext = {
	results = outerQueryBuffer,
	count = 0,
	dedupeById = false,
	seen = {},
	stamp = 0,
	activeLength = 0,
}

local nestedCollectContext = {
	results = nestedQueryBuffer,
	count = 0,
	dedupeById = false,
	seen = {},
	stamp = 0,
	activeLength = 0,
}

local function eachNeighborInRange(x, y, radius, fn, context)
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

	for dx = -cellRadius, cellRadius do
		local col = grid[cx + dx]

		if col then
			for dy = -cellRadius, cellRadius do
				local cell = col[cy + dy]

				if cell then
					for i = 1, #cell do
						fn(cell[i], context)
					end
				end
			end
		end
	end
end

local function collectContext(enemy, ctx)
	if ctx.dedupeById then
		local id = enemy.id
		if id then
			local stamp = ctx.stamp
			if ctx.seen[id] == stamp then
				return
			end
			ctx.seen[id] = stamp
		end
	end

	local nextCount = ctx.count + 1
	ctx.results[nextCount] = enemy
	ctx.count = nextCount
end

local function collectCellsInto(ctx, x, y, radius, dedupeById)
	ctx.count = 0
	ctx.dedupeById = dedupeById == true
	if ctx.dedupeById then
		nextStamp(ctx)
	end

	eachNeighborInRange(x, y, radius, collectContext, ctx)

	local count = ctx.count
	for i = count + 1, ctx.activeLength do
		ctx.results[i] = nil
	end
	ctx.activeLength = count

	return count
end

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

function Spatial.beginFrame()
	-- Query buffers are shared scratch arrays: callers may read them immediately
	-- after queryCells/queryCellsLocal returns, but should not hold long-lived references
	-- across frames because later queries overwrite entries in-place.
	outerCollectContext.count = 0
	nestedCollectContext.count = 0
end

function Spatial.queryCells(x, y, radius, dedupeById)
	local count = collectCellsInto(outerCollectContext, x, y, radius, dedupeById)
	return outerQueryBuffer, count
end

function Spatial.queryCellsLocal(x, y, radius, dedupeById)
	local count = collectCellsInto(nestedCollectContext, x, y, radius, dedupeById)
	return nestedQueryBuffer, count
end

function Spatial.pointToCell(x, y)
	return floor(x * INV_CELL), floor(y * INV_CELL)
end

local function traverseOccupancy(cx, cy, radiusCells, onCount)
	local radius = radiusCells or 1
	local idx = 0
	local sum = 0

	for dx = -radius, radius do
		local col = grid[cx + dx]

		for dy = -radius, radius do
			idx = idx + 1
			local count = 0

			if col then
				local cell = col[cy + dy]
				if cell then
					count = #cell
				end
			end

			sum = sum + count
			if onCount then
				onCount(idx, count)
			end
		end
	end

	return idx, sum
end

function Spatial.queryOccupancy(cx, cy, radiusCells, out)
	local counts = out or occupancyBuffer
	local idx, sum = traverseOccupancy(cx, cy, radiusCells, function(i, count)
		counts[i] = count
	end)

	for i = idx + 1, #counts do
		counts[i] = nil
	end

	return counts, idx, sum
end

function Spatial.queryOccupancySum(cx, cy, radiusCells)
	local _, sum = traverseOccupancy(cx, cy, radiusCells)
	return sum
end

function Spatial.forEachInCells(x, y, radius, fn, context)
	eachNeighborInRange(x, y, radius, fn, context)
end

return Spatial
