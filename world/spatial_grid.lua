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
}

local nestedCollectContext = {
	results = nestedQueryBuffer,
	count = 0,
	dedupeById = false,
	seen = {},
	stamp = 0,
}

local forEachContext = {
	fn = nil,
	context = nil,
}

local function eachNeighborInRange(cx, cy, cellRadius, onCell, context)
	local idx = 0
	for dx = -cellRadius, cellRadius do
		local col = grid[cx + dx]
		for dy = -cellRadius, cellRadius do
			idx = idx + 1
			local cell = col and col[cy + dy] or nil
			onCell(cell, idx, context)
		end
	end
	return idx
end

local function queryCellRadius(radius)
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

	return cellRadius
end

local function queryCellRadiusLocal()
	return 2
end

local function traverseOccupancy(cx, cy, radiusCells, onCell, context)
	local radius = radiusCells or 1
	return eachNeighborInRange(cx, cy, radius, onCell, context)
end

local function traverseQueryCellsCollect(x, y, radius, collectContext, dedupeById, radiusPolicy)
	local ctx = collectContext
	ctx.count = 0
	ctx.dedupeById = dedupeById == true
	if ctx.dedupeById then
		nextStamp(ctx)
	end

	local cx = floor(x * INV_CELL)
	local cy = floor(y * INV_CELL)
	local cellRadius = (radiusPolicy or queryCellRadius)(radius)
	local results = ctx.results
	local count = 0
	local seen = ctx.seen
	local stamp = ctx.stamp
	for dx = -cellRadius, cellRadius do
		local col = grid[cx + dx]
		if col then
			for dy = -cellRadius, cellRadius do
				local cell = col[cy + dy]
				if cell then
					for i = 1, #cell do
						local enemy = cell[i]
						if ctx.dedupeById then
							local id = enemy.id
							if id and seen[id] == stamp then
								goto continue_enemy
							end
							if id then
								seen[id] = stamp
							end
						end
						count = count + 1
						results[count] = enemy
						::continue_enemy::
					end
				end
			end
		end
	end
	ctx.count = count
	return results, count
end

local function traverseQueryCellsCallback(x, y, radius, callbackContext, radiusPolicy)
	local cx = floor(x * INV_CELL)
	local cy = floor(y * INV_CELL)
	local cellRadius = (radiusPolicy or queryCellRadius)(radius)
	local fn = callbackContext.fn
	local context = callbackContext.context
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
	outerCollectContext.count = 0
	nestedCollectContext.count = 0
end

function Spatial.queryCells(x, y, radius, dedupeById)
	return traverseQueryCellsCollect(x, y, radius, outerCollectContext, dedupeById, queryCellRadius)
end

function Spatial.queryCellsLocal(x, y, radius, dedupeById)
	return traverseQueryCellsCollect(x, y, radius, nestedCollectContext, dedupeById, queryCellRadiusLocal)
end

function Spatial.pointToCell(x, y)
	return floor(x * INV_CELL), floor(y * INV_CELL)
end

local function countCellOccupancy(cell, idx, ctx)
	local count = 0
	if cell then
		count = #cell
	end
	ctx.sum = ctx.sum + count
	local onCount = ctx.onCount
	if onCount then
		onCount(idx, count)
	end
end

local occupancyState = { sum = 0, onCount = nil, counts = nil }
local function writeOccupancyCount(i, count)
	occupancyState.counts[i] = count
end

function Spatial.queryOccupancy(cx, cy, radiusCells, out)
	local counts = out or occupancyBuffer
	local state = occupancyState
	state.sum = 0
	state.counts = counts
	state.onCount = writeOccupancyCount

	local idx = traverseOccupancy(cx, cy, radiusCells, countCellOccupancy, state)
	local sum = state.sum
	state.onCount = nil
	state.counts = nil

	for i = idx + 1, #counts do
		counts[i] = nil
	end

	return counts, idx, sum
end

function Spatial.queryOccupancySum(cx, cy, radiusCells)
	local state = occupancyState
	state.sum = 0
	state.onCount = nil
	traverseOccupancy(cx, cy, radiusCells, countCellOccupancy, state)
	return state.sum
end

function Spatial.forEachInCells(x, y, radius, fn, context)
	forEachContext.fn = fn
	forEachContext.context = context
	traverseQueryCellsCallback(x, y, radius, forEachContext, queryCellRadius)
	forEachContext.fn = nil
	forEachContext.context = nil
end

return Spatial
