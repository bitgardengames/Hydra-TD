package.path = "./?.lua;./?/init.lua;" .. package.path

local nearby = {}
local queryCounts = {}
local floor, ceil = math.floor, math.ceil

package.loaded["world.spatial_grid"] = {
	newQueryContext = function() return {} end,
	radiusOptions = {living = {}},
	visitRadius = function(x, y, radius, visitor, context)
		queryCounts[x] = (queryCounts[x] or 0) + 1
		local result = nearby[x] or {}
		local radius2 = radius * radius
		for i = 1, #result do
			local target = result[i]
			local dx, dy = target.x - x, target.y - y
			if target.hp > 0 and dx * dx + dy * dy <= radius2 then
				visitor(target, context, dx * dx + dy * dy)
			end
		end
	end,
	visitCells = function(x, y, radius, visitor, context)
		queryCounts[x] = (queryCounts[x] or 0) + 1
		local result = nearby[x] or {}
		for i = 1, #result do
			visitor(result[i], context)
		end
	end,
	forEachQueryCell = function(x, y, radius, fn, context)
		local cx, cy = floor(x / 100), floor(y / 100)
		local footprint = radius > 0 and ceil(radius / 100) or 0
		for dx = -footprint, footprint do
			for dy = -footprint, footprint do
				fn(cx + dx, cy + dy, context)
			end
		end
	end,
}

local Support = require("world.enemy_support")

local function enemy(id, x)
	return {id = id, x = x, y = 0, hp = 10, supportBoost = 1, def = {}}
end

local function source(id, x, multiplier, radius)
	local result = enemy(id, x)
	result.def.support = {radius = radius or 64, speedMultiplier = multiplier, pulsePeriod = 1}
	result.support = result.def.support
	Support.register(result)
	return result
end

-- Overlapping auras retain the strongest boost and dirty work is deduplicated.
local firstAura = source(1, 100, 1.5)
local strongerAura = source(2, 200, 2)
local target = enemy(3, 150)
nearby[100] = {firstAura, strongerAura, target}
nearby[200] = {firstAura, strongerAura, target}
Support.flushDirtySources()
assert(target.supportBoost == 2, "overlapping support did not select the strongest boost")
assert(firstAura._supportRefreshX == 100 and firstAura._supportRefreshY == 0,
	"support refresh position was not retained")
queryCounts[100] = 0

-- Source movement stays cached until it can reach a nearby membership
-- boundary. An unchanged position should never enqueue redundant work.
Support.onSourceMoved(firstAura, firstAura.x, firstAura.y)
Support.flushDirtySources()
assert(queryCounts[100] == 0, "unchanged support source was refreshed")
firstAura.x = 110
nearby[110] = nearby[100]
Support.onSourceMoved(firstAura, 100, 0)
Support.flushDirtySources()
assert(queryCounts[110] == nil, "safe support movement crossed its refresh threshold")
firstAura.x = 100

Support.onEnemyCellChanged(target, 1, 0, 2, 0)
Support.onEnemyCellChanged(target, 2, 0, 1, 0)
Support.flushDirtySources()
assert(queryCounts[100] == 1, "cell crossings did not deduplicate dirty sources")

-- A source movement immediately reindexes its covered cells, while refresh is
-- still deferred to the authoritative flush pipeline.
firstAura.x = 500
nearby[500] = {firstAura}
Support.onEnemyCellChanged(firstAura, 1, 0, 5, 0)
assert(queryCounts[500] == nil, "source movement refreshed membership immediately")
Support.flushDirtySources()
assert(queryCounts[500] == 1, "moving support source was not refreshed")
assert(target.supportBoost == 2, "moving one overlap removed the remaining boost")

-- Removing/dying sources cleans contributions immediately.
strongerAura.hp = 0
Support.onEnemyRemoved(strongerAura, 2, 0)
assert(target.supportBoost == 1, "dead source left its contribution attached")

-- A runtime radius change updates covered-cell indexing as well as membership.
local resizingAura = source(4, 1000, 1.25, 20)
local crossingTarget = enemy(5, 1250)
nearby[1000] = {resizingAura, crossingTarget}
Support.flushDirtySources()
resizingAura.def.support.radius = 220
Support.update(0)
Support.flushDirtySources()
queryCounts[1000] = 0
Support.onEnemyCellChanged(crossingTarget, 12, 0, 13, 0)
Support.flushDirtySources()
assert(queryCounts[1000] == 1, "runtime aura-radius change did not reindex covered cells")

-- Instrumentation proves an ordinary enemy crossing examines only sources in
-- its old/new covered-cell buckets, not every registered source.
for i = 1, 30 do
	local distant = source(100 + i, 10000 + i * 1000, 1.1)
	nearby[distant.x] = {distant}
end
Support.flushDirtySources()
Support.resetLifecycleStats()
Support.onEnemyCellChanged(crossingTarget, 13, 0, 14, 0)
local examined = Support.getLifecycleStats()
assert(examined == 1, "nearby lookup examined " .. examined .. " sources instead of one")

Support.clear()
print("enemy support fixtures passed")
