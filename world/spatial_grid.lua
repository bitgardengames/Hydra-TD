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
local enemyCellChangedHook
local enemyRemovedHook

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

local frameStats = {
	localQueryCount = 0,
	localCandidateTotal = 0,
}

local forEachContext = {
	fn = nil,
	context = nil,
}

local function eachNeighborInRange(cx, cy, cellRadius, onCell, context)
	local idx = 0
	for dx = -cellRadius, cellRadius do
		local col = grid[cx + dx]
		if col then
			for dy = -cellRadius, cellRadius do
				idx = idx + 1
				onCell(col[cy + dy], idx, context)
			end
		else
			for _ = -cellRadius, cellRadius do
				idx = idx + 1
				onCell(nil, idx, context)
			end
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

local function queryCellRadiusLocal(radius)
	local cellRadius = 0

	if radius and radius > 0 then
		cellRadius = ceil(radius * INV_CELL)
		if cellRadius < 0 then
			cellRadius = 0
		elseif cellRadius > 2 then
			-- Preserve legacy local-query safety bound for compatibility.
			cellRadius = 2
		end
	end

	return cellRadius
end

-- Towers can share a local-query candidate list when this footprint and their
-- center cell match. Keep the key tied directly to the traversal policy so
-- cache callers cannot drift from queryCellsLocal's CELL_SIZE boundaries.
function Spatial.localQueryFootprintKey(radius)
	return queryCellRadiusLocal(radius)
end

local function traverseOccupancy(cx, cy, radiusCells, onCell, context)
	return eachNeighborInRange(cx, cy, radiusCells or 1, onCell, context)
end

local function traverseQueryCellsCollect(x, y, radius, collectContext, dedupeById, radiusPolicy)
	local ctx = collectContext
	ctx.count = 0
	ctx.dedupeById = dedupeById == true
	local useDedupe = ctx.dedupeById
	if useDedupe then
		nextStamp(ctx)
	end

	local cx = floor(x * INV_CELL)
	local cy = floor(y * INV_CELL)
	local cellRadius = (radiusPolicy or queryCellRadius)(radius)
	local results = ctx.results
	local count = 0
	if useDedupe then
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
							local id = enemy.id
							if id and seen[id] == stamp then
								goto continue_enemy
							end
							if id then
								seen[id] = stamp
							end
							count = count + 1
							results[count] = enemy
							::continue_enemy::
						end
					end
				end
			end
		end
	else
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

	local oldCX, oldCY = e.cellX, e.cellY
	removeFromCell(e)
	insertIntoCell(e, cx, cy)
	if enemyCellChangedHook then
		enemyCellChangedHook(e, oldCX, oldCY, cx, cy)
	end
end

function Spatial.removeEnemy(e)
	local oldCX, oldCY = e.cellX, e.cellY
	removeFromCell(e)
	if enemyRemovedHook and oldCX ~= nil then
		enemyRemovedHook(e, oldCX, oldCY)
	end
end

function Spatial.setEnemyLifecycleHooks(onCellChanged, onRemoved)
	enemyCellChangedHook = onCellChanged
	enemyRemovedHook = onRemoved
end

function Spatial.beginFrame()
	outerCollectContext.count = 0
	nestedCollectContext.count = 0
	frameStats.localQueryCount = 0
	frameStats.localCandidateTotal = 0
end

function Spatial.queryCells(x, y, radius, dedupeById)
	return traverseQueryCellsCollect(x, y, radius, outerCollectContext, dedupeById, queryCellRadius)
end

function Spatial.queryCellsLocal(x, y, radius, dedupeById)
	local results, count =
		traverseQueryCellsCollect(x, y, radius, nestedCollectContext, dedupeById, queryCellRadiusLocal)
	frameStats.localQueryCount = frameStats.localQueryCount + 1
	frameStats.localCandidateTotal = frameStats.localCandidateTotal + count
	return results, count
end

function Spatial.getLocalQueryFrameStats()
	return frameStats.localQueryCount, frameStats.localCandidateTotal
end

function Spatial.pointToCell(x, y)
	return floor(x * INV_CELL), floor(y * INV_CELL)
end

-- Return the exact cell footprint traversed by queryCells. Systems which keep
-- secondary spatial indexes can use this without duplicating grid policy.
function Spatial.queryCellBounds(x, y, radius)
	local cx = floor(x * INV_CELL)
	local cy = floor(y * INV_CELL)
	local cellRadius = queryCellRadius(radius)
	return cx - cellRadius, cy - cellRadius, cx + cellRadius, cy + cellRadius
end

function Spatial.queryIncludesCell(x, y, radius, cx, cy)
	local centerX = floor(x * INV_CELL)
	local centerY = floor(y * INV_CELL)
	local cellRadius = queryCellRadius(radius)
	return math.abs(centerX - cx) <= cellRadius and math.abs(centerY - cy) <= cellRadius
end

function Spatial.queryOccupancy(cx, cy, radiusCells, out)
	local counts = out or occupancyBuffer
	local sum = 0
	local idx = traverseOccupancy(cx, cy, radiusCells, function(cell, cellIdx)
		local count = cell and #cell or 0
		counts[cellIdx] = count
		sum = sum + count
	end)

	for i = idx + 1, #counts do
		counts[i] = nil
	end

	return counts, idx, sum
end

function Spatial.queryOccupancySum(cx, cy, radiusCells)
	local sum = 0
	traverseOccupancy(cx, cy, radiusCells, function(cell)
		if cell then
			sum = sum + #cell
		end
	end)

	return sum
end

function Spatial.forEachInCells(x, y, radius, fn, context)
	forEachContext.fn = fn
	forEachContext.context = context
	traverseQueryCellsCallback(x, y, radius, forEachContext, queryCellRadius)
	forEachContext.fn = nil
	forEachContext.context = nil
end

return Spatial
