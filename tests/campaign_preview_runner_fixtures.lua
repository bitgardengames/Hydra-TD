-- Dependency-free source checks for the selected-map path animation.
local file = assert(io.open("ui/menu/screens/campaign.lua", "r"))
local source = file:read("*a")
file:close()

assert(source:find("local function pointAlongPreviewPath(path, distance)", 1, true),
	"campaign preview runner must interpolate along the cached map path")
assert(source:find("local PREVIEW_RUNNER_SPEED = 120", 1, true),
	"campaign preview runner must use the near-double map-selection pace")
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

-- Load the screen with narrow stubs so this fixture exercises the real layout
-- accessor without needing a LÖVE runtime or constructing the rest of the UI.
local oldLove = love
local viewportW, viewportH = 1280, 800
love = {
	graphics = {getDimensions = function() return viewportW, viewportH end},
}

local dependencyNames = {
	"systems.sound", "systems.difficulty", "core.fonts", "core.theme", "core.state",
	"core.save", "world.map_defs", "world.map_preview_cache", "ui.text", "ui.button",
	"ui.medals", "ui.tooltip", "scenes.backdrop", "core.steam", "core.localization",
	"systems.campaign_unlocks", "systems.run_modes", "render.tower_renderer",
	"ui.ability_icons", "systems.ability_defs", "core.hotkeys",
	"ui.campaign_unlock_presentation",
}
local oldLoaded, oldPreload = {}, {}
local function stubDependency(name)
	if name == "world.map_defs" then return {{id = "one"}, {id = "two"}, {id = "three"}} end
	if name == "ui.campaign_unlock_presentation" then return {new = function() return {} end} end
	if name == "core.localization" then return function(key) return key end end
	if name == "core.state" then return {mapIndex = 1} end
	if name == "core.theme" then
		return {ui = {good = {}, warn = {}, bad = {}}}
	end
	return setmetatable({}, {__index = function() return function() end end})
end
for _, name in ipairs(dependencyNames) do
	oldLoaded[name] = package.loaded[name]
	oldPreload[name] = package.preload[name]
	package.loaded[name] = nil
	local dependencyName = name
	package.preload[name] = function() return stubDependency(dependencyName) end
end
package.loaded["ui.menu.screens.campaign"] = nil
local Campaign = require("ui.menu.screens.campaign")

local function upvalue(fn, wanted)
	for index = 1, 30 do
		local name, value = debug.getupvalue(fn, index)
		if not name then break end
		if name == wanted then return value end
	end
end
local getLayout = assert(upvalue(Campaign.update, "layout"), "update must use the shared layout accessor")
Campaign.load()
local first = getLayout()
local firstLeft, firstCenter = first.left, first.center
assert(getLayout() == first and getLayout().left == firstLeft and getLayout().center == firstCenter,
	"layout and column table identities must be stable at unchanged dimensions")
assert(first.sw == 1280 and first.sh == 800 and first.contentH == 656,
	"initial layout dimensions must retain the existing campaign geometry")
assert(first.left.x == 56 and first.left.y == 96 and first.left.w == 405 and first.left.h == 656,
	"initial list placement and height must remain unchanged")
assert(first.center.x == 461 and first.center.y == 96 and first.center.w == 763 and first.center.h == 656,
	"initial preview geometry must remain unchanged")

viewportW, viewportH = 1600, 1000
Campaign.resize()
local resized = getLayout()
assert(resized == first and resized.left == firstLeft and resized.center == firstCenter,
	"resize must update the retained layout and column records in place")
assert(resized.sw == 1600 and resized.sh == 1000 and resized.contentH == 734,
	"resize must recompute and cap the campaign content height")
assert(resized.left.x == 216 and resized.left.y == 115 and resized.left.w == 405 and resized.left.h == 734,
	"resized list and scrolling geometry must be recomputed")
assert(resized.center.x == 621 and resized.center.y == 115 and resized.center.w == 763 and resized.center.h == 734,
	"resized preview geometry must be recomputed")

assert(source:find("keepSelectedVisible(layout())", 1, true),
	"selection visibility must continue using the shared layout accessor")
assert(source:find("local l = layout()", 1, true)
	and source:find("local playX, _cardY, playW, _labelW, playY = difficultyGeometry(l)", 1, true),
	"scrolling, preview, pointer handling, and button placement must continue sharing layout geometry")

package.loaded["ui.menu.screens.campaign"] = nil
for _, name in ipairs(dependencyNames) do
	package.loaded[name] = oldLoaded[name]
	package.preload[name] = oldPreload[name]
end
love = oldLove

print("campaign preview runner fixtures passed")
