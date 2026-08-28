-- Dependency-free spatial-query regression fixtures. Run from the repository root.
package.path = "./?.lua;./?/init.lua;" .. package.path

local Constants = require("core.constants")
local Spatial = require("world.spatial_grid")
local CELL_SIZE = Constants.TILE * 2

local nextId = 0
local inserted = {}

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
	local results, count = Spatial.queryCells(x, 0, radius, true)
	assert(contains(results, count, enemy), label .. " (queryCells)")
	results, count = Spatial.queryCellsLocal(x, 0, radius, true)
	assert(contains(results, count, enemy), label .. " (queryCellsLocal)")
	assert(Spatial.localQueryFootprintKey(radius) == math.ceil(radius / CELL_SIZE),
		label .. " (cache footprint)")
end

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
