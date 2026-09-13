-- Dependency-free graphics/layout fixtures. Run from the repository root.
package.path = "./?.lua;" .. package.path

love = {
	graphics = {getDimensions = function() return 1280, 720 end},
	window = {
		getDisplayCount = function() return 2 end,
		getDesktopDimensions = function(display)
			if display == 2 then return 2560, 1440 end
			return 1920, 1080
		end,
		getFullscreenModes = function(display)
			if display == 2 then
				return {{width = 2560, height = 1440}, {width = 1280, height = 720},
					{width = 1280, height = 720}, {width = 3840, height = 2160}}
			end
			return {{width = 1280, height = 800}, {width = 1920, height = 1080}}
		end,
	},
}
local Scale = require("core.scale")
local Window = require("core.window")

local cases = {
	{name = "smallest", w = 1280, h = 720},
	{name = "windowed_16_10", w = 1280, h = 800},
	{name = "full_hd", w = 1920, h = 1080},
	{name = "ultrawide", w = 3440, h = 1440},
}

for _, fixture in ipairs(cases) do
	assert(Scale.suggestMSAA(fixture.w, fixture.h) == 8, fixture.name .. " uses 8x MSAA")
	local usableH = fixture.h - 48
	local menuLineH = 48
	assert(usableH >= menuLineH * 6, fixture.name .. " cannot show six settings rows")
	local tooltipW = math.min(260, fixture.w - 12)
	assert(tooltipW > 0 and tooltipW <= fixture.w - 12, fixture.name .. " tooltip constraint")
end

local resolutions = Window.getResolutions(2)
assert(#resolutions == 2, "duplicate and larger-than-desktop modes are filtered")

local normalized = Window.normalizeSettings({
	displayMode = "invalid", displayIndex = 99,
	windowWidth = -1, windowHeight = "wide",
	fullscreenWidth = 1111, fullscreenHeight = 777,
})
assert(normalized.displayMode == "borderless", "invalid display mode falls back safely")
assert(normalized.displayIndex == 1, "unavailable monitor falls back to the primary display")
assert(normalized.windowWidth == 1280 and normalized.windowHeight == 800, "invalid window size is normalized")
assert(normalized.fullscreenWidth == 1920 and normalized.fullscreenHeight == 1080,
	"unavailable fullscreen resolution falls back to desktop")

local width, height, flags = Window.buildMode({
	displayMode = "fullscreen", displayIndex = 2,
	windowWidth = 1280, windowHeight = 720,
	fullscreenWidth = 1280, fullscreenHeight = 720,
})
assert(width == 1280 and height == 720, "exclusive mode uses the selected resolution")
assert(flags.fullscreen and flags.fullscreentype == "exclusive" and flags.display == 2,
	"exclusive mode flags target the selected monitor")

width, height, flags = Window.buildMode({displayMode = "borderless", displayIndex = 2})
assert(width == 0 and height == 0 and flags.fullscreentype == "desktop",
	"borderless mode uses desktop dimensions")

print("graphics settings fixtures passed")
