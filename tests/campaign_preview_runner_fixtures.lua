-- Dependency-free source checks for the selected-map path animation.
local file = assert(io.open("ui/menu/screens/campaign.lua", "r"))
local source = file:read("*a")
file:close()

assert(source:find("local function pointAlongPreviewPath(path, distance)", 1, true),
	"campaign preview runner must interpolate along the cached map path")
assert(source:find("local PREVIEW_RUNNER_SPEED = 64", 1, true),
	"campaign preview runner must use the faster map-selection pace")
assert(source:find("local cycleDuration = travelDuration + PREVIEW_RUNNER_FADE_DURATION", 1, true)
	and source:find("local cycleTime = previewRunnerTime % cycleDuration", 1, true),
	"campaign preview runner must restart after each travel-and-fade cycle")
assert(source:find("local fadeOutStart = max(0, travelDuration - PREVIEW_RUNNER_FADE_DURATION)", 1, true)
	and source:find("(travelDuration - cycleTime) / PREVIEW_RUNNER_FADE_DURATION", 1, true),
	"campaign preview runner must fade before reaching its trimmed endpoint")
assert(source:find("local PREVIEW_RUNNER_ENTRY_TRIM_TILES = 2", 1, true)
	and source:find("local PREVIEW_RUNNER_EXIT_TRIM_TILES = 2", 1, true)
	and source:find("local endDistance = path.totalLength - PREVIEW_RUNNER_EXIT_TRIM_TILES * path.tileLength", 1, true)
	and source:find("local distance = startDistance +", 1, true),
	"campaign preview runner must skip two tiles at both ends of the path")
assert(source:find("cycleTime / PREVIEW_RUNNER_FADE_DURATION", 1, true),
	"campaign preview runner must fade in at its trimmed starting point")
assert(source:find("drawPreviewRunner(entry, previewX, previewY, isMapLocked(mapIndex))", 1, true),
	"campaign screen must draw the runner over the large selected-map preview")
assert(source:find("previewRunnerTime = previewRunnerTime + dt", 1, true),
	"campaign screen must advance the preview runner during updates")

print("campaign preview runner fixtures passed")
