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

-- Advancing the frame clears candidate references and all nested coordinate maps.
State.frameId = 11
candidates[1], candidates[2] = nil, nil
Targeting.findTarget(towerA)
assert(queryCount == 3, "new frame reused a stale query")
assert(next(oldEntries) == nil, "old coordinate keys survived the frame boundary")
for i = 1, #cache.listPool do
	assert(next(cache.listPool[i]) == nil, "pooled candidate list retained an enemy reference")
end

-- A run reset can occur without a frame-id change, so it must invalidate eagerly.
candidates[1] = enemyB
Targeting.clearFrameCache()
assert(next(cache.entries) == nil, "run reset retained coordinate keys")
assert(Targeting.findTarget(towerAtObsoleteCell) == enemyB,
	"run reset reused candidates from the previous map")
assert(queryCount == 4, "run reset did not force a fresh spatial query")

print("targeting cache fixtures passed")
