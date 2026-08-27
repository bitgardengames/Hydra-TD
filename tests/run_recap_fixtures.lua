-- Dependency-light recap fixtures. Run from the repository root with Lua/LuaJIT.
package.path = "./?.lua;./?/init.lua;" .. package.path

love = {graphics = {}}
package.loaded["core.theme"] = {ui = {good = {1, 1, 1}, text = {1, 1, 1}, screenDim = {0, 0, 0}}}
package.loaded["core.fonts"] = {set = function() end}
local printed = {}
package.loaded["ui.text"] = {printfShadow = function(text, x, _, width, alignment)
	table.insert(printed, {text = text, x = x, width = width, alignment = alignment})
end}

local AnimatedRunStats = require("ui.animated_run_stats")
local stats = AnimatedRunStats.new()
stats:setRows({
	{label = "Kills", value = 75, denominator = 100},
	{label = "Score", value = 12345},
})
assert(not stats:isComplete(), "a newly reset sequence must animate")
assert(stats.rows[1].barOpacity == 0 and stats.rows[2].barOpacity == 0,
	"progress bars must start fully transparent")
stats:update(0.275)
assert(stats.rows[1].displayedValue > 0 and stats.rows[1].displayedValue < 75,
	"elapsed-time interpolation must produce an intermediate value")
assert(stats.rows[1].fill > 0 and stats.rows[1].fill < 0.75,
	"bar fill must ease toward the honest denominator ratio")
assert(stats.rows[1].barOpacity == 1 and stats.rows[2].barOpacity == 0,
	"each progress bar must appear only when its fill begins")
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

stats:setRows({{label = "Perfect", value = 100, denominator = 100}})
stats:update(stats.rowDuration)
assert(stats.rows[1].flashElapsed == 0, "a full bar must begin flashing after reaching its fill")
stats:update(0.1)
assert(stats.rows[1].flashElapsed > 0, "the full-bar flash must continue after stat completion")

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
assert(rectangles[1].x == 90 and rectangles[1].width == 340,
	"wide recap progress bars should be capped and centered")
assert(rectangles[2].x == rectangles[1].x and rectangles[2].width == 255,
	"progress fills should use the same compact track geometry")
assert(printed[1].x == rectangles[1].x and printed[1].alignment == "left",
	"stat labels should begin at the progress bar's left endpoint")
assert(printed[2].x == rectangles[1].x and printed[2].width == rectangles[1].width
		and printed[2].alignment == "right",
	"stat values should end at the progress bar's right endpoint")

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
local gameOverSource = source("ui/menu/screens/game_over.lua")
assert(stateSource:find("totalKills = 0", 1, true), "state must declare the run kill counter")
assert(stateSource:find("spawnedKills = 0", 1, true), "state must declare the recap kill counter")
assert(mainSource:find("State.totalKills = 0", 1, true), "resetGame must reset run kills")
assert(mainSource:find("State.spawnedKills = 0", 1, true), "resetGame must reset recap kills")
assert(enemySource:find("State.totalKills = (State.totalKills or 0) + 1", 1, true),
	"enemy death must increment run kills")
assert(enemySource:find("if e.scheduledWaveEnemy then", 1, true),
	"only scheduled wave enemies may increment recap kills")
assert(enemySource:find("State.spawnedKills = (State.spawnedKills or 0) + 1", 1, true),
	"scheduled enemy death must increment recap kills")
assert(victorySource:find('{label = L("runRecap.score"), value = State.score or 0}', 1, true),
	"victory recap must display the final score")
assert(not gameOverSource:find('L("runRecap.score")', 1, true),
	"defeat recap must not display the final score")
assert(gameOverSource:find("local panelW = 420", 1, true)
		and gameOverSource:find("panelW = math.min(420, sw - 64)", 1, true),
	"defeat panel must use its narrow layout")
for name, screenSource in pairs({victory = victorySource, defeat = gameOverSource}) do
	assert(not screenSource:find('L("runRecap.enemiesDefeated")', 1, true),
		name .. " recap must not display kill stats")
	assert(not screenSource:find("RecordRows.build", 1, true),
		name .. " recap must not display run records")
end
assert(victorySource:find("if runStats:isComplete() then Medals.update(dt) end", 1, true),
	"medals must wait for stat completion")
assert(victorySource:find("local medalR = 32", 1, true),
	"victory medals must use the larger presentation size")
assert(victorySource:find("medalsY + (medalsH - clusterH) * 0.5", 1, true),
	"victory medals must be vertically centered in their card")
assert(victorySource:find("local rowY, barW, barH = y + 48, w - 190, 9", 1, true),
	"victory damage bars must use the shortened width")
assert(victorySource:find("runStats:update(dt)", 1, true),
	"victory stats must begin without waiting for a reward popup")
assert(not victorySource:find("rewardCards", 1, true),
	"victory stats must not be gated by reward popup state")

print("run recap fixtures passed")
