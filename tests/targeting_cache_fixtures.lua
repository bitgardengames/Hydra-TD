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

-- A new frame refreshes the same leaf and list in place. Moving enemies must
-- affect the result even though the coordinate/footprint index stays alive.
State.frameId = 11
candidates[1], candidates[2] = enemyB, nil
enemyB.x = 20
assert(Targeting.findTarget(towerA) == enemyB, "new frame reused stale enemy positions")
assert(queryCount == 3, "new frame reused a stale query")
assert(cache.entries == oldEntries, "new frame replaced the coordinate index")
assert(oldEntries[0][0][2] == sharedEntry, "new frame replaced a cache leaf")
assert(sharedEntry.list == sharedList, "new frame replaced a candidate list")
assert(sharedEntry.frameId == 11, "refreshed leaf did not record the new frame")
assert(sharedList[1] == enemyB and sharedList[2] == nil,
	"refreshed list retained stale candidates")

-- A sold tower is no longer queried, but its persistent cache entry remains
-- available until the map is explicitly reset.
assert(oldEntries[2][0][1] == soldTowerEntry, "sold tower entry was discarded between frames")
assert(soldTowerEntry.frameId == 10, "sold tower entry was unexpectedly refreshed")
assert(queryCount == 3, "sold tower issued an unexpected spatial query")

-- A run reset can occur without a frame-id change, so it must invalidate eagerly.
enemyB.x = 210
Targeting.clearFrameCache()
assert(next(cache.entries) == nil, "run reset retained coordinate keys")
assert(Targeting.findTarget(towerAtObsoleteCell) == enemyB,
	"run reset reused candidates from the previous map")
assert(queryCount == 4, "run reset did not force a fresh spatial query")

print("targeting cache fixtures passed")
