-- Dependency-free spatial-query regression fixtures. Run from the repository root.
package.path = "./?.lua;./?/init.lua;" .. package.path

local Constants = require("core.constants")
local Spatial = require("world.spatial_grid")
local CELL_SIZE = Constants.TILE * 2

local nextId = 0
local inserted = {}
local queryContext = Spatial.newQueryContext(true)
local localQueryContext = Spatial.newQueryContext(true)

local function add(x, y)
	nextId = nextId + 1
	local enemy = {id = nextId, x = x, y = y, hp = 1, dist = 0}
	Spatial.updateEnemy(enemy)
	inserted[#inserted + 1] = enemy
	return enemy
end

local function clear()
	for i = 1, #inserted do
		Spatial.removeEnemy(inserted[i])
	end
	inserted = {}
end

local function contains(results, count, expected)
	for i = 1, count do
		if results[i] == expected then return true end
	end
	return false
end

local function assertBothQueriesFind(x, radius, enemy, label)
	local results, count = Spatial.queryCells(x, 0, radius, queryContext)
	assert(contains(results, count, enemy), label .. " (queryCells)")
	results, count = Spatial.queryCellsLocal(x, 0, radius, localQueryContext)
	assert(contains(results, count, enemy), label .. " (queryCellsLocal)")
	assert(Spatial.localQueryFootprintKey(radius) == math.ceil(radius / CELL_SIZE),
		label .. " (cache footprint)")
end

local function currentMaxEnemyRadius()
	for outer = 1, 20 do
		local outerName, traverse = debug.getupvalue(Spatial.visitRadius, outer)
		if not outerName then break end
		if type(traverse) == "function" then
			for inner = 1, 20 do
				local name, value = debug.getupvalue(traverse, inner)
				if name == "maxEnemyRadius" then return value end
				if not name then break end
			end
		end
	end
	error("could not inspect the tracked maximum enemy radius")
end

-- Collision-query expansion follows active radius buckets rather than retaining
-- the largest radius ever inserted.
local widestA = add(1, 1)
widestA.radius = 20
Spatial.updateEnemy(widestA)
local widestB = add(2, 2)
widestB.radius = 20
Spatial.updateEnemy(widestB)
local narrower = add(3, 3)
narrower.radius = 8
Spatial.updateEnemy(narrower)
assert(currentMaxEnemyRadius() == 20, "active maximum radius was not tracked")
Spatial.removeEnemy(widestA)
assert(currentMaxEnemyRadius() == 20, "maximum radius dropped while its bucket remained active")
Spatial.removeEnemy(widestB)
assert(currentMaxEnemyRadius() == 8, "maximum radius did not fall back to the next active bucket")
Spatial.removeEnemy(narrower)
assert(currentMaxEnemyRadius() == 0, "maximum radius did not reset after the final removal")
inserted = {}

-- Empty cells and columns are reclaimed without disturbing swap removal.
local sharedA = add(1, 1)
local sharedB = add(2, 2)
local neighboringCell = add(1, CELL_SIZE + 1)
local sharedCX, sharedCY = sharedA.cellX, sharedA.cellY
local neighboringCY = neighboringCell.cellY
local column = Spatial.grid[sharedCX]
Spatial.removeEnemy(sharedA)
assert(sharedB.cellIndex == 1 and column[sharedCY] ~= nil,
	"swap removal did not update the remaining enemy index")
Spatial.removeEnemy(sharedB)
assert(column[sharedCY] == nil, "removing the final enemy did not reclaim its cell")
assert(Spatial.grid[sharedCX] == column, "column was reclaimed while it still contained a cell")
Spatial.removeEnemy(neighboringCell)
assert(column[neighboringCY] == nil, "neighboring cell was not reclaimed")
assert(Spatial.grid[sharedCX] == nil, "empty column was not reclaimed")
inserted = {}

-- A map reset clears occupancy and reusable query state in place.
local priorGrid = Spatial.grid
local priorEnemy = add(4, 4)
local priorResults, priorCount = Spatial.queryCells(4, 4, 1, queryContext)
assert(priorCount == 1 and priorResults[1] == priorEnemy, "reset fixture did not populate query state")
Spatial.queryCellsLocal(4, 4, 1, localQueryContext)
Spatial.clear()
assert(currentMaxEnemyRadius() == 0, "Spatial.clear did not reset radius metadata")
assert(Spatial.grid == priorGrid and next(priorGrid) == nil,
	"Spatial.clear replaced or failed to empty the exposed grid")
local queryCount, candidateTotal = Spatial.getLocalQueryFrameStats()
assert(queryCount == 0 and candidateTotal == 0, "Spatial.clear did not reset query frame counters")
local resetResults, resetCount = Spatial.queryCells(4, 4, 1, queryContext)
assert(resetCount == 0 and resetResults[1] == nil, "map reset retained a stale query result")
local localResults, localCount = Spatial.queryCellsLocal(4, 4, 1, localQueryContext)
assert(localCount == 0 and localResults[1] == nil, "map reset retained a stale local query result")
inserted = {}

-- Visitor state is entirely caller-owned, so a nested query cannot overwrite
-- the outer traversal's callback or ID-deduplication stamp.
local nestedA = add(1, 1)
local nestedB = add(CELL_SIZE + 1, 1)
local outerSeen, outerCount = {}, 0
local outerContext = Spatial.newQueryContext(true)
local innerContext = Spatial.newQueryContext(true)
Spatial.visitCells(1, 1, CELL_SIZE * 2, function(enemy)
	outerCount = outerCount + 1
	outerSeen[enemy] = (outerSeen[enemy] or 0) + 1
	if enemy == nestedA then
		local innerCount = 0
		Spatial.visitCells(nestedB.x, nestedB.y, 0, function()
			innerCount = innerCount + 1
		end, nil, innerContext)
		assert(innerCount == 1, "nested visitor returned the wrong candidate count")
	end
end, nil, outerContext)
assert(outerCount == 2 and outerSeen[nestedA] == 1 and outerSeen[nestedB] == 1,
	"nested query lost or duplicated an outer visitor candidate")
clear()

-- Radius visitation filters in place and honors its retained hot-path options.
local radiusCenter = add(0, 0)
local renderedOnly = add(CELL_SIZE, 0)
renderedOnly.rx, renderedOnly.ry = 3, 4
local collisionOnly = add(13, 0)
collisionOnly.radius = 4
local dead = add(1, 0)
dead.hp = 0
local radiusVisited = {}
local radiusContext = Spatial.newQueryContext(true)
local function rememberRadiusEnemy(enemy, context, distanceSquared)
	context[enemy] = distanceSquared
end
Spatial.visitRadius(0, 0, 5, rememberRadiusEnemy, radiusVisited, radiusContext,
	Spatial.radiusOptions.livingRenderedDedupe)
assert(radiusVisited[radiusCenter] == 0 and radiusVisited[renderedOnly] == 25 and not radiusVisited[dead],
	"rendered/living radius options did not apply exact filtering")
radiusVisited = {}
Spatial.visitRadius(0, 0, 10, rememberRadiusEnemy, radiusVisited, radiusContext,
	Spatial.radiusOptions.livingCollision)
assert(radiusVisited[collisionOnly] == 169, "collision radius was not included in exact filtering")
clear()

-- A center close to either cell edge must traverse far enough in that direction.
local radius = CELL_SIZE * 2 + 1
local leftCenter = CELL_SIZE + 0.01
local leftEnemy = add(leftCenter - radius + 0.01, 0)
assertBothQueriesFind(leftCenter, radius, leftEnemy, "low-edge center omitted a distant in-radius cell")
clear()

local rightCenter = CELL_SIZE * 2 - 0.01
local rightEnemy = add(rightCenter + radius - 0.01, 0)
assertBothQueriesFind(rightCenter, radius, rightEnemy, "high-edge center omitted a distant in-radius cell")
clear()

-- Derive the largest fully-upgraded tower range directly from the checked-in definitions.
package.loaded["core.theme"] = {tower = {
	slow = {}, lancer = {}, poison = {}, cannon = {}, shock = {}, plasma = {},
}}
local TowerDefs = require("world.tower_defs")
local maxTowerRange = 0
for _, def in pairs(TowerDefs) do
	maxTowerRange = math.max(maxTowerRange, def.range + (def.upgrade.rangeAdd or 0) * 4)
end
local towerX = CELL_SIZE - 0.01
local towerEnemy = add(towerX + maxTowerRange - 0.01, 0)
assertBothQueriesFind(towerX, maxTowerRange, towerEnemy, "maximum tower range omitted a candidate")
assert(math.floor(towerEnemy.x / CELL_SIZE) - math.floor(towerX / CELL_SIZE) >= 3,
	"tower fixture must cross the former two-cell cap")

-- Tower targeting consumes the same footprint-keyed list and retains exact circle filtering.
package.loaded["core.state"] = {frameId = 1}
local Targeting = require("world.targeting")
local tower = {x = towerX, y = 0, range = maxTowerRange, range2 = maxTowerRange * maxTowerRange}
assert(Targeting.findTarget(tower) == towerEnemy, "tower targeting omitted the maximum-range candidate")
local cornerEnemy = add(towerX + maxTowerRange * 0.9, maxTowerRange * 0.9)
cornerEnemy.dist = 100
package.loaded["core.state"].frameId = 2
assert(Targeting.findTarget(tower) == towerEnemy, "tower targeting did not apply its squared-distance check")
clear()

local bossRadius = 320
local bossX = CELL_SIZE - 0.01
local bossEnemy = add(bossX + bossRadius - 0.01, 0)
assertBothQueriesFind(bossX, bossRadius, bossEnemy, "320-pixel boss-add radius omitted a candidate")
assert(math.floor(bossEnemy.x / CELL_SIZE) - math.floor(bossX / CELL_SIZE) >= 3,
	"boss-add fixture must cross the former two-cell cap")
clear()

print("spatial grid fixtures passed")
