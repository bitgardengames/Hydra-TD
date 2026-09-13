-- Dependency-free targeting-cache regression fixtures. Run from the repository root.
package.path = "./?.lua;./?/init.lua;" .. package.path

local queryCount = 0
local candidates = {}
package.loaded["core.state"] = {frameId = 10}
package.loaded["world.spatial_grid"] = {
	pointToCell = function(x, y) return math.floor(x / 100), math.floor(y / 100) end,
	localQueryFootprintKey = function(range) return math.ceil(range / 100) end,
	newQueryContext = function() return {} end,
	visitCellsLocal = function(_, _, _, visitor, context)
		queryCount = queryCount + 1
		for i = 1, #candidates do visitor(candidates[i], context) end
		return #candidates
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
local enemyA = {id = 2, x = 10, y = 10, hp = 1, dist = 5}
local enemyB = {id = 1, x = 20, y = 10, hp = 1, dist = 5}
candidates[1], candidates[2] = enemyA, enemyB

local towerA = {x = 5, y = 5, range = 150, range2 = 150 * 150}
local towerInSameCell = {x = 95, y = 95, range = 199, range2 = 199 * 199}
assert(Targeting.findTarget(towerA) == enemyB, "equal scores were not resolved by deterministic ID")
assert(Targeting.findTarget(towerInSameCell) == enemyB, "shared cache entry changed selection")
assert(queryCount == 1, "matching same-frame keys should issue one spatial traversal")

local entry = cache.entries[0][0][2]
local retainedList = entry.list
assert(entry.frameId == 10 and entry.count == 2, "cache entry did not record its generation/count")

-- A generation refresh retains the entry and buffer, and clears its stale tail.
State.frameId = 11
enemyA.hp = 0
enemyB.x, enemyB.dist = 10, 7
candidates[1], candidates[2] = enemyB, nil
assert(Targeting.findTarget(towerA) == enemyB, "death/movement refresh returned stale state")
assert(queryCount == 2, "new generation did not perform exactly one traversal")
assert(cache.entries[0][0][2] == entry and entry.list == retainedList,
	"warmed cache entry or candidate buffer was reallocated")
assert(entry.count == 1 and retainedList[1] == enemyB and retainedList[2] == nil,
	"refresh did not clear the stale candidate tail")

-- Phase changes are applied while filling the retained buffer.
State.frameId = 12
enemyA.hp, enemyA.phaseActive = 1, false
enemyB.phaseActive = true
candidates[1], candidates[2] = enemyA, enemyB
assert(Targeting.findTarget(towerA) == enemyA, "phase filtering was not refreshed")
assert(Targeting.findTarget(towerInSameCell) == enemyA and queryCount == 3,
	"shared key traversed more than once after phase refresh")

-- Distinct numeric tuples remain collision-free and persist without allocation.
local negativeTower = {x = -105, y = 195, range = 50, range2 = 50 * 50}
local otherTower = {x = -15, y = 95, range = 50, range2 = 50 * 50}
Targeting.findTarget(negativeTower)
Targeting.findTarget(otherTower)
local negativeEntry = cache.entries[-2][1][1]
local otherEntry = cache.entries[-1][0][1]
assert(negativeEntry and otherEntry, "negative coordinate tuples collided")
State.frameId = 13
Targeting.findTarget(negativeTower)
Targeting.findTarget(otherTower)
assert(cache.entries[-2][1][1] == negativeEntry and cache.entries[-1][0][1] == otherEntry,
	"warmed tuple keys allocated replacement entries")

-- A run reset eagerly releases every retained enemy reference and coordinate map.
local warmedEntries = {entry, negativeEntry, otherEntry}
Targeting.clearFrameCache()
assert(next(cache.entries) == nil and cache.frameId == nil, "run reset retained cache keys")
for i = 1, #warmedEntries do
	assert(warmedEntries[i].count == 0 and next(warmedEntries[i].list) == nil,
		"run reset retained an enemy reference")
end
Targeting.findTarget(towerA)
assert(queryCount == 8, "run reset did not force a fresh traversal")

print("targeting cache fixtures passed")
