package.path = "./?.lua;./?/init.lua;" .. package.path

local Spatial = require("world.spatial_grid")
local State = require("core.state")

local function addEnemy(id, x, y, dist)
	local enemy = {id = id, x = x, y = y, hp = 10, dist = dist}
	Spatial.updateEnemy(enemy)
	return enemy
end

local outerEnemy = addEnemy(1, 0, 0, 10)
local nestedEnemy = addEnemy(2, 336, 0, 20)
local outerContext = Spatial.createCollectContext()
local nestedContext = Spatial.createCollectContext()
local outer, outerCount = Spatial.queryCellsLocal(0, 0, 1, outerContext)
assert(outerCount == 1 and outer[1] == outerEnemy, "outer fixture query was not isolated")

for i = 1, outerCount do
	local nested, nestedCount = Spatial.queryCellsLocal(336, 0, 1, nestedContext)
	assert(nestedCount == 1 and nested[1] == nestedEnemy, "nested fixture query returned the wrong result")
	assert(outer[i] == outerEnemy and outerCount == 1, "nested query overwrote the outer result")
end
assert(nestedContext.results[1] == nestedEnemy, "outer result overwrote the nested result")

-- Tower candidate entries are snapshots for a frame. A later grid insertion
-- becomes visible only after State.frameId advances, the documented boundary.
local Targeting = require("world.targeting")
local tower = {x = 0, y = 0, range = 120, range2 = 120 * 120}
State.frameId = 100
assert(Targeting.findTarget(tower) == outerEnemy, "initial tower candidate was not selected")
local laterEnemy = addEnemy(3, 10, 0, 100)
assert(Targeting.findTarget(tower) == outerEnemy, "tower candidate cache changed inside a frame")
State.frameId = 101
assert(Targeting.findTarget(tower) == laterEnemy, "tower candidate cache was not rebuilt at the frame boundary")

print("spatial grid collect context fixtures passed")
