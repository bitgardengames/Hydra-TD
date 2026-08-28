local Constants = require("core.constants")

local Spatial = {}

local floor = math.floor
local ceil = math.ceil
local TILE = Constants.TILE

local CELL_SIZE = TILE * 2
local INV_CELL = 1 / CELL_SIZE

local grid = {}
Spatial.grid = grid
local maxEnemyRadius = 0

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

local frameStats = {
	localQueryCount = 0,
	localCandidateTotal = 0,
}

local function clearTable(t)
	for key in pairs(t) do
		t[key] = nil
	end
end

local function queryCellFootprint(radius)
	if not radius or radius <= 0 then
		return 0
	end

	return ceil(radius * INV_CELL)
end

-- Towers can share a local-query candidate list when this footprint and their
-- center cell match. Keep the key tied directly to the traversal policy so
-- cache callers cannot drift from queryCellsLocal's CELL_SIZE boundaries.
function Spatial.localQueryFootprintKey(radius)
	return queryCellFootprint(radius)
end

local function traverseQueryCellsCollect(x, y, radius, collectContext)
	local ctx = collectContext
	local previousCount = ctx.count
	ctx.count = 0
	local useDedupe = ctx.dedupeById
	if useDedupe then
		nextStamp(ctx)
	end

	local cx = floor(x * INV_CELL)
	local cy = floor(y * INV_CELL)
	local cellRadius = queryCellFootprint(radius)
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
	for i = count + 1, previousCount do
		results[i] = nil
	end
	ctx.count = count
	return results, count
end

local function traverseQueryCellsCallback(x, y, radius, fn, context, queryContext)
	local cx = floor(x * INV_CELL)
	local cy = floor(y * INV_CELL)
	local cellRadius = queryCellFootprint(radius)
	local useDedupe = queryContext.dedupeById
	local seen, stamp
	if useDedupe then
		stamp = nextStamp(queryContext)
		seen = queryContext.seen
	end
	local count = 0
	for dx = -cellRadius, cellRadius do
		local col = grid[cx + dx]
		if col then
			for dy = -cellRadius, cellRadius do
				local cell = col[cy + dy]
				if cell then
					for i = 1, #cell do
						local enemy = cell[i]
						local id = enemy.id
						if not (useDedupe and id and seen[id] == stamp) then
							if useDedupe and id then seen[id] = stamp end
							count = count + 1
							fn(enemy, context)
						end
					end
				end
			end
		end
	end
	return count
end

-- Retained option records for the common hot paths. Callers may also retain
-- their own record with the same stable boolean fields.
Spatial.radiusOptions = {
	default = {livingOnly = false, dedupeById = false, renderedPosition = false, includeCollisionRadius = false},
	living = {livingOnly = true, dedupeById = false, renderedPosition = false, includeCollisionRadius = false},
	livingDedupe = {livingOnly = true, dedupeById = true, renderedPosition = false, includeCollisionRadius = false},
	livingRendered = {livingOnly = true, dedupeById = false, renderedPosition = true, includeCollisionRadius = false},
	livingRenderedDedupe = {livingOnly = true, dedupeById = true, renderedPosition = true, includeCollisionRadius = false},
	livingCollision = {livingOnly = true, dedupeById = false, renderedPosition = false, includeCollisionRadius = true},
}

local function traverseRadius(x, y, radius, visitor, visitorContext, queryContext, options)
	local cx = floor(x * INV_CELL)
	local cy = floor(y * INV_CELL)
	local cellRadius = queryCellFootprint(radius + (options.includeCollisionRadius and maxEnemyRadius or 0))
	local dedupe = options.dedupeById
	local seen, stamp
	if dedupe then
		stamp = nextStamp(queryContext)
		seen = queryContext.seen
	end
	local radiusSquared = radius * radius
	local count = 0
	for dx = -cellRadius, cellRadius do
		local col = grid[cx + dx]
		if col then
			for dy = -cellRadius, cellRadius do
				local cell = col[cy + dy]
				if cell then
					for i = 1, #cell do
						local enemy = cell[i]
						local id = enemy.id
						if not (dedupe and id and seen[id] == stamp) then
							if dedupe and id then seen[id] = stamp end
							if not options.livingOnly or enemy.hp > 0 then
								local ex = options.renderedPosition and (enemy.rx or enemy.x) or enemy.x
								local ey = options.renderedPosition and (enemy.ry or enemy.y) or enemy.y
								local ddx, ddy = ex - x, ey - y
								local distanceSquared = ddx * ddx + ddy * ddy
								local exactRadius = radius
								if options.includeCollisionRadius then exactRadius = exactRadius + (enemy.radius or 0) end
								if distanceSquared <= (options.includeCollisionRadius and exactRadius * exactRadius or radiusSquared) then
									count = count + 1
									if visitor(enemy, visitorContext, distanceSquared) == false then return count end
								end
							end
						end
					end
				end
			end
		end
	end
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

	if last == 1 then
		local cx, cy = e.cellX, e.cellY
		local col = grid[cx]
		if col and col[cy] == cell then
			col[cy] = nil
			if next(col) == nil then
				grid[cx] = nil
			end
		end
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
	maxEnemyRadius = math.max(maxEnemyRadius, e.radius or 0)
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

function Spatial.clear()
	clearTable(grid)
	maxEnemyRadius = 0
	frameStats.localQueryCount = 0
	frameStats.localCandidateTotal = 0
end

function Spatial.beginFrame()
	frameStats.localQueryCount = 0
	frameStats.localCandidateTotal = 0
end

function Spatial.newQueryContext(dedupeById, results)
	return {results = results or {}, count = 0, dedupeById = dedupeById == true, seen = {}, stamp = 0}
end

-- Collection and visitation both require caller-owned state. A caller that can
-- nest queries must use a distinct context for every simultaneously active
-- traversal; contexts may otherwise be retained and reused without allocation.
function Spatial.queryCells(x, y, radius, queryContext)
	assert(queryContext and queryContext.results, "queryCells requires a caller-owned query context")
	return traverseQueryCellsCollect(x, y, radius, queryContext)
end

function Spatial.queryCellsLocal(x, y, radius, queryContext)
	local results, count = Spatial.queryCells(x, y, radius, queryContext)
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

function Spatial.queryIncludesCell(x, y, radius, cx, cy)
	local centerX = floor(x * INV_CELL)
	local centerY = floor(y * INV_CELL)
	local cellRadius = queryCellFootprint(radius)
	return math.abs(centerX - cx) <= cellRadius and math.abs(centerY - cy) <= cellRadius
end

-- Visit the exact square cell footprint used by queryCells. Systems which
-- maintain secondary spatial indexes can therefore share this module's cell
-- sizing and radius-rounding policy without duplicating coordinate math.
function Spatial.forEachQueryCell(x, y, radius, fn, context)
	local centerX = floor(x * INV_CELL)
	local centerY = floor(y * INV_CELL)
	local cellRadius = queryCellFootprint(radius)
	for dx = -cellRadius, cellRadius do
		for dy = -cellRadius, cellRadius do
			fn(centerX + dx, centerY + dy, context)
		end
	end
end

function Spatial.visitCells(x, y, radius, fn, context, queryContext)
	assert(queryContext, "visitCells requires a caller-owned query context")
	return traverseQueryCellsCallback(x, y, radius, fn, context, queryContext)
end

-- Visits exact-radius matches directly from grid cells, without materializing
-- a candidate array. A query context cannot be active in a nested traversal;
-- retain a distinct context at every nesting level.
function Spatial.visitRadius(x, y, radius, visitor, visitorContext, queryContext, options)
	assert(queryContext and queryContext.seen, "visitRadius requires a caller-owned query context")
	assert(options, "visitRadius requires retained options")
	return traverseRadius(x, y, radius, visitor, visitorContext, queryContext, options)
end

return Spatial
