package.path = "./?.lua;./?/init.lua;" .. package.path

local nearby = {}
local queryCounts = {}

package.loaded["world.spatial_grid"] = {
	queryCells = function(x)
		queryCounts[x] = (queryCounts[x] or 0) + 1
		local result = nearby[x] or {}
		return result, #result
	end,
	queryIncludesCell = function()
		return true
	end,
}

local Support = require("world.enemy_support")

local function enemy(id, x)
	return {id = id, x = x, y = 0, hp = 10, supportBoost = 1, def = {}}
end

local function source(id, x, multiplier)
	local result = enemy(id, x)
	result.def.support = {radius = 64, speedMultiplier = multiplier, pulsePeriod = 1}
	result.support = result.def.support
	Support.register(result)
	return result
end

-- Initial membership and multiple crossings of one aura are reconciled once.
local aura = source(1, 100, 1.5)
local first = enemy(2, 200)
local second = enemy(3, 300)
nearby[100] = {aura, first, second}
Support.flushDirtySources()
assert(first.supportBoost == 1.5 and second.supportBoost == 1.5,
	"initial support membership did not preserve the boost behavior")
queryCounts[100] = 0
Support.onEnemyCellChanged(first, 0, 0, 1, 0)
Support.onEnemyCellChanged(second, 0, 0, 1, 0)
assert(queryCounts[100] == 0, "a lifecycle hook refreshed an aura immediately")
Support.flushDirtySources()
assert(queryCounts[100] == 1, "same-tick crossings did not deduplicate the dirty source")

-- A moving source invalidates itself, even without another enemy crossing it.
queryCounts[100] = 0
Support.markSourceDirty(aura)
Support.flushDirtySources()
assert(queryCounts[100] == 1, "moving support source was not refreshed")

-- Overlaps retain the strongest multiplier, including after one source leaves.
local stronger = source(4, 400, 2)
nearby[400] = {stronger, first}
Support.flushDirtySources()
assert(first.supportBoost == 2, "overlapping support did not select the strongest boost")
nearby[400] = {stronger}
Support.onEnemyCellChanged(first, 1, 0, 2, 0)
Support.flushDirtySources()
assert(first.supportBoost == 1.5, "removing one overlap did not restore the remaining boost")

-- Source removal must detach its contribution immediately; the queued neighbor
-- refresh must not change the final boost.
Support.onEnemyRemoved(aura, 1, 0)
assert(first.supportBoost == 1, "source removal left its contribution attached")
Support.flushDirtySources()
assert(first.supportBoost == 1, "source-removal flush changed the final boost")

Support.clear()
print("enemy support fixtures passed")
