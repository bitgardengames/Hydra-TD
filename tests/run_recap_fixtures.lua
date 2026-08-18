-- Dependency-light recap fixtures. Run from the repository root with Lua/LuaJIT.
package.path = "./?.lua;./?/init.lua;" .. package.path

love = {graphics = {}}
package.loaded["core.theme"] = {ui = {good = {1, 1, 1}, text = {1, 1, 1}, screenDim = {0, 0, 0}}}
package.loaded["core.fonts"] = {set = function() end}
package.loaded["ui.text"] = {printfShadow = function() end}

local AnimatedRunStats = require("ui.animated_run_stats")
local stats = AnimatedRunStats.new()
stats:setRows({
	{label = "Kills", value = 75, denominator = 100},
	{label = "Score", value = 12345},
})
assert(not stats:isComplete(), "a newly reset sequence must animate")
stats:update(0.275)
assert(stats.rows[1].displayedValue > 0 and stats.rows[1].displayedValue < 75,
	"elapsed-time interpolation must produce an intermediate value")
assert(stats.rows[1].fill > 0 and stats.rows[1].fill < 0.75,
	"bar fill must ease toward the honest denominator ratio")
assert(stats.rows[2].displayedValue == 0,
	"the next result must wait for the current row animation to finish")
assert(stats.rows[2].fill == nil, "a stat without a target must omit its bar")
stats:update(stats.rowDuration - 0.275)
assert(stats.rows[1].displayedValue == 75 and stats.rows[2].displayedValue == 0,
	"result animations must play in sequence without overlap")
stats:update(0.1)
assert(stats.rows[2].displayedValue > 0 and stats.rows[2].displayedValue < 12345,
	"the next result must begin after the previous row finishes")
stats:update(10)
assert(stats:isComplete() and stats.rows[1].displayedValue == 75,
	"elapsed animation must complete at the final value")

stats:reset()
stats:finish()
assert(stats:isComplete() and stats.rows[1].fill == 0.75,
	"skip must immediately finish values and fills")

stats:setRows({{label = "Zero", value = 4, denominator = 0}})
stats:finish()
assert(stats.rows[1].fill == nil, "zero denominators must be safe and omit the bar")
assert(AnimatedRunStats.formatNumber(1234567) == "1,234,567", "large values need separators")

local rectangles = {}
love.graphics.setColor = function() end
love.graphics.rectangle = function(_, x, _, width)
	table.insert(rectangles, {x = x, width = width})
end
stats:setRows({{label = "Kills", value = 75, denominator = 100}})
stats:finish()
stats:draw(10, 20, 500)
assert(rectangles[1].x == 50 and rectangles[1].width == 420,
	"wide recap progress bars should be capped and centered")
assert(rectangles[2].x == rectangles[1].x and rectangles[2].width == 315,
	"progress fills should use the same compact track geometry")

local function source(path)
	local file = assert(io.open(path, "r"))
	local value = file:read("*a")
	file:close()
	return value
end

local stateSource = source("core/state.lua")
local mainSource = source("main.lua")
local enemySource = source("world/enemies.lua")
local victorySource = source("ui/menu/screens/victory.lua")
assert(stateSource:find("totalKills = 0", 1, true), "state must declare the run kill counter")
assert(mainSource:find("State.totalKills = 0", 1, true), "resetGame must reset run kills")
assert(enemySource:find("State.totalKills = (State.totalKills or 0) + 1", 1, true),
	"enemy death must increment run kills")
assert(victorySource:find("if runStats:isComplete() then Medals.update(dt) end", 1, true),
	"medals must wait for stat completion")
assert(victorySource:find("if #rewardCards == 0 then", 1, true),
	"stats must wait for unlock cards")

print("run recap fixtures passed")
