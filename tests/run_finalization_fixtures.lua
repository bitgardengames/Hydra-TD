-- Static and dependency-free fixtures for completed-run tower history ownership.
-- Run from the repository root with Lua/LuaJIT.

local function read(path)
	local file = assert(io.open(path, "r"))
	local contents = file:read("*a")
	file:close()
	return contents
end

local pauseSource = read("ui/menu/pause.lua")
local mainSource = read("main.lua")
assert(not pauseSource:find("Achievements.onGameOver", 1, true),
	"pause navigation must not finalize achievements or tower history")
assert(not mainSource:find("Achievements.onGameOver", 1, true),
	"victory and application shutdown must not use the old mixed finalizer")
assert(mainSource:find('GameplayOutcome.cancel("quit")', 1, true),
	"application quit should explicitly classify an active run as quit")

local recorded = {}
local flushes = 0
package.loaded["core.save"] = {
	recordTowerRun = function(kind, damage, kills)
		recorded[#recorded + 1] = {kind = kind, damage = damage, kills = kills}
	end,
	flush = function() flushes = flushes + 1 end,
}
package.loaded["systems.run_stats"] = nil
local RunStats = require("systems.run_stats")

local function populateRun()
	local tower = {kind = "cannon"}
	RunStats.recordPurchase(tower)
	RunStats.recordDamage(tower, 125)
	RunStats.recordKill(tower)
	RunStats.recordKill(tower)
end

-- A played-out run is committed by canonical outcome finalization. Later menu
-- navigation and love.quit may encounter it again, but can never add it twice.
populateRun()
RunStats.finish("completed", {score = 10})
assert(RunStats.commitTowerHistory(), "a completed run should commit tower history")
assert(not RunStats.commitTowerHistory(), "navigation after completion should be a no-op")
assert(not RunStats.commitTowerHistory(), "quitting after completion should be a no-op")
assert(#recorded == 1 and recorded[1].kind == "cannon"
	and recorded[1].damage == 125 and recorded[1].kills == 2,
	"completed tower damage and kills should be added exactly once")
assert(flushes == 1, "only the successful history commit should flush")

local function assertIneligible(outcome)
	RunStats.reset()
	populateRun()
	RunStats.finish(outcome, {})
	assert(not RunStats.commitTowerHistory(), outcome .. " runs must not commit tower history")
	assert(#recorded == 1, outcome .. " runs must not change cumulative tower history")
end

assertIneligible("restarted")
assertIneligible("abandoned")
assertIneligible("quit")

print("run finalization fixtures passed")
