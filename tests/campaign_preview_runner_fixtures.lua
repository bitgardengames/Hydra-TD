-- Dependency-free source checks for the selected-map path animation.
local file = assert(io.open("ui/menu/screens/campaign.lua", "r"))
local source = file:read("*a")
file:close()

assert(source:find("local function pointAlongPreviewPath(path, distance)", 1, true),
	"campaign preview runner must interpolate along the cached map path")
assert(source:find("local cycleDuration = travelDuration + PREVIEW_RUNNER_FADE_DURATION", 1, true)
	and source:find("local cycleTime = previewRunnerTime % cycleDuration", 1, true),
	"campaign preview runner must restart after each travel-and-fade cycle")
assert(source:find("1 - (cycleTime - travelDuration) / PREVIEW_RUNNER_FADE_DURATION", 1, true),
	"campaign preview runner must fade after reaching the path end")
assert(source:find("local PREVIEW_RUNNER_TRIM_TILES = 2", 1, true)
	and source:find("path.totalLength - trimDistance * 2", 1, true)
	and source:find("local distance = trimDistance +", 1, true),
	"campaign preview runner must skip two tiles at both ends of the path")
assert(source:find("cycleTime / PREVIEW_RUNNER_FADE_DURATION", 1, true),
	"campaign preview runner must fade in at its trimmed starting point")
assert(source:find("drawPreviewRunner(entry, previewX, previewY, isMapLocked(mapIndex))", 1, true),
	"campaign screen must draw the runner over the large selected-map preview")
assert(source:find("previewRunnerTime = previewRunnerTime + dt", 1, true),
	"campaign screen must advance the preview runner during updates")

print("campaign preview runner fixtures passed")
