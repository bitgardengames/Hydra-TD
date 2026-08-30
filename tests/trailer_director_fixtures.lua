-- Regression fixture for exports that must show real campaign formations.
local file = assert(io.open("tools/trailer/director.lua", "r"))
local source = file:read("*a")
file:close()

local resolveAt = assert(source:find("State.resolveMapIndex%(Director.shot.map%)"),
	"trailer shots must resolve their requested map")
local worldMapAt = assert(source:find("State.worldMapIndex = mapIndex", resolveAt, true),
	"resetGame must build the requested trailer map")
local gameplayMapAt = assert(source:find("State.mapIndex = State.resolveMapIndex", worldMapAt, true),
	"wave resolution must select an authored campaign map")
local campaignAt = assert(source:find("RunModes.set(State, RunModes.CAMPAIGN)", gameplayMapAt, true),
	"trailer shots must resolve authored campaign waves")
local resetAt = assert(source:find("resetGame()", campaignAt, true),
	"trailer run state must be configured before resetGame")
assert(source:find("CampaignWaveDefs.get(Maps[State.mapIndex], State.wave)", 1, true),
	"trailer shots must reject unauthored wave requests")

assert(resolveAt < worldMapAt and worldMapAt < gameplayMapAt
	and gameplayMapAt < campaignAt and campaignAt < resetAt,
	"trailer map and run mode setup must happen before resetGame")

for _, shot in ipairs({"steam_screenshot_1", "steam_screenshot_3", "steam_screenshot_4"}) do
	local shotFile = assert(io.open("tools/trailer/shots/" .. shot .. ".lua", "r"))
	local shotSource = shotFile:read("*a")
	shotFile:close()
	local wave = tonumber(assert(shotSource:match("index%s*=%s*(%d+)"), shot .. " must select a wave"))
	assert(wave <= 20, shot .. " must not select a procedural post-campaign wave")
end

print("trailer director fixtures passed")
