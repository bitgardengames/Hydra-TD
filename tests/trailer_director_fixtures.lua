-- Regression fixture for screenshot shots that use post-campaign waves.
local file = assert(io.open("tools/trailer/director.lua", "r"))
local source = file:read("*a")
file:close()

local resolveAt = assert(source:find("State.resolveMapIndex%(Director.shot.map%)"),
	"trailer shots must resolve their requested map")
local worldMapAt = assert(source:find("State.worldMapIndex = mapIndex", resolveAt, true),
	"resetGame must build the requested trailer map")
local gameplayMapAt = assert(source:find("State.mapIndex = mapIndex", worldMapAt, true),
	"wave resolution must use the requested trailer map")
local endlessAt = assert(source:find("RunModes.set(State, RunModes.ENDLESS)", gameplayMapAt, true),
	"trailer shots must permit procedural waves after the campaign")
local resetAt = assert(source:find("resetGame()", endlessAt, true),
	"trailer run state must be configured before resetGame")

assert(resolveAt < worldMapAt and worldMapAt < gameplayMapAt
	and gameplayMapAt < endlessAt and endlessAt < resetAt,
	"trailer map and run mode setup must happen before resetGame")

print("trailer director fixtures passed")
