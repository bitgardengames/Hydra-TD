package.path = "./?.lua;./?/init.lua;" .. package.path

local occupants = {}
local queryCount = 0
package.loaded["world.spatial_grid"] = {
	queryCells = function()
		queryCount = queryCount + 1
		return occupants, #occupants
	end,
	queryCellBounds = function(x, y, radius)
		local size = 128
		local cx, cy = math.floor(x / size), math.floor(y / size)
		local cells = math.max(1, math.min(2, math.ceil(radius / size)))
		return cx - cells, cy - cells, cx + cells, cy + cells
	end,
}

local Support = require("world.enemy_support")

local function enemy(id, x, y)
	return {id = id, x = x, y = y or 0, hp = 10, supportBoost = 1,
		def = {}, cellX = math.floor(x / 128), cellY = math.floor((y or 0) / 128)}
end

local function source(id, x, radius, multiplier)
	local result = enemy(id, x)
	result.def.support = {radius = radius, speedMultiplier = multiplier, pulsePeriod = 1}
	result.support = result.def.support
	Support.register(result)
	return result
end

-- A target entering and leaving the circular boundary without changing cells
-- is updated exactly and does not cause a full source membership refresh.
local aura = source(1, 64, 40, 1.5)
local target = enemy(2, 110)
occupants = {aura, target}
Support.flushDirtySources()
assert(target.supportBoost == 1, "outside target unexpectedly received support")
local baselineQueries = queryCount
target.x = 100
Support.onEnemyMoved(target, 110, 0)
assert(target.supportBoost == 1.5, "same-cell aura entry was not detected")
target.x = 110
Support.onEnemyMoved(target, 100, 0)
assert(target.supportBoost == 1, "same-cell aura exit was not detected")
assert(queryCount == baselineQueries, "target movement rebuilt source membership")

-- Simultaneous movement is reconciled at the final positions before combat.
target.x = 102
Support.onEnemyMoved(target, 110, 0)
aura.x = 60
Support.onEnemyMoved(aura, 64, 0)
Support.flushDirtySources()
assert(target.supportBoost == 1, "simultaneous final positions used stale membership")

-- Runtime definition mutation forces a full refresh even with stable bounds.
aura.def.support.radius = 50
aura.def.support.speedMultiplier = 2
Support.update(0)
Support.flushDirtySources()
assert(target.supportBoost == 2, "runtime aura definition change was not applied")

-- Source death/removal immediately clears contributions and its reverse index.
aura.hp = 0
Support.detachDead(aura)
assert(target.supportBoost == 1, "source death left a contribution attached")
Support.onEnemyCellChanged(target, 0, 0, 1, 0)
assert(target.supportBoost == 1, "removed source remained in the cell reverse index")

Support.clear()
print("enemy support fixtures passed")
