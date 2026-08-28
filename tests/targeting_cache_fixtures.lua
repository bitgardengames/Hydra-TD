-- Dependency-free targeting-cache regression fixtures. Run from the repository root.
package.path = "./?.lua;./?/init.lua;" .. package.path

local queryCount = 0
local candidates = {}
package.loaded["core.state"] = {frameId = 10}
package.loaded["world.spatial_grid"] = {
	pointToCell = function(x, y) return math.floor(x / 100), math.floor(y / 100) end,
	localQueryFootprintKey = function(range) return math.ceil(range / 100) end,
	queryCellsLocal = function()
		queryCount = queryCount + 1
		return candidates, #candidates
	end,
}

local Targeting = require("world.targeting")
local State = package.loaded["core.state"]

local function upvalue(fn, wanted)
	for i = 1, 20 do
		local name, value = debug.getupvalue(fn, i)
		if not name then break end
		if name == wanted then return value end
	end
	error("missing upvalue " .. wanted)
end

local getCandidatesForTower = upvalue(Targeting.findTarget, "getCandidatesForTower")
local cache = upvalue(getCandidatesForTower, "frameCache")
local enemyA = {id = 1, x = 10, y = 10, hp = 1, dist = 1}
local enemyB = {id = 2, x = 210, y = 10, hp = 1, dist = 2}
candidates[1] = enemyA
candidates[2] = enemyB

local towerA = {x = 5, y = 5, range = 150, range2 = 150 * 150}
local towerInSameCell = {x = 95, y = 95, range = 199, range2 = 199 * 199}
assert(Targeting.findTarget(towerA) == enemyA, "initial tower did not query candidates")
assert(Targeting.findTarget(towerInSameCell) == enemyA,
	"tower sharing a cell footprint did not reuse the candidate query")
assert(queryCount == 1, "matching same-frame footprints should issue one spatial query")

local towerAtObsoleteCell = {x = 205, y = 5, range = 50, range2 = 50 * 50}
Targeting.findTarget(towerAtObsoleteCell)
assert(queryCount == 2, "second cache key was not populated")
local oldEntries = cache.entries
assert(oldEntries[0] and oldEntries[2], "fixture did not populate distinct coordinate keys")
local sharedEntry = oldEntries[0][0][2]
local sharedList = sharedEntry.list
local soldTowerEntry = oldEntries[2][0][1]

-- A new frame retires every old key, but reuses the bounded entry/list pool.
-- Moving enemies must affect the result and stale references must be released.
State.frameId = 11
candidates[1], candidates[2] = enemyB, nil
enemyB.x = 20
assert(Targeting.findTarget(towerA) == enemyB, "new frame reused stale enemy positions")
assert(queryCount == 3, "new frame reused a stale query")
assert(cache.entries == oldEntries, "new frame replaced the coordinate index")
assert(oldEntries[2] == nil, "new frame retained an obsolete coordinate key")
local recycledEntry = oldEntries[0][0][2]
assert(recycledEntry == sharedEntry or recycledEntry == soldTowerEntry,
	"new frame did not reuse a pooled cache leaf")
assert(recycledEntry.list[1] == enemyB and recycledEntry.list[2] == nil,
	"recycled list retained stale candidates")
local unusedList = recycledEntry == sharedEntry and soldTowerEntry.list or sharedList
assert(unusedList[1] == nil and unusedList[2] == nil,
	"unused pooled list retained stale enemy references")

-- A sold tower is no longer queried and its historical key is not retained.
assert(oldEntries[2] == nil, "sold tower coordinate survived the frame boundary")
assert(queryCount == 3, "sold tower issued an unexpected spatial query")

-- A run reset can occur without a frame-id change, so it must invalidate eagerly.
enemyB.x = 210
Targeting.clearFrameCache()
assert(next(cache.entries) == nil, "run reset retained coordinate keys")
assert(cache.poolCount == 0 and next(cache.pool) == nil, "run reset retained pooled entries")
assert(Targeting.findTarget(towerAtObsoleteCell) == enemyB,
	"run reset reused candidates from the previous map")
assert(queryCount == 4, "run reset did not force a fresh spatial query")

print("targeting cache fixtures passed")
