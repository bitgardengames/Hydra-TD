local Launcher = {}

-- Tool entry points stay lazy so an export does not initialize the game or
-- load modules belonging to another tool.
local TOOL_MODES = {
	art = "tools.art_export",
	achievements = "tools.achievement_export",
	map = "tools.map_export.main",
	trailer = "tools.trailer.trailer_main",
	capsule = "tools.capsule_export",
}

local function configureWindow(settings)
	local Scale = require("core.scale")
	local width, height = 1280, 800
	local fullscreen = settings.fullscreen == true

	if fullscreen then
		width, height = love.window.getDesktopDimensions()
	end

	local msaa = Scale.suggestMSAA(width, height) or 8
	love.window.updateMode(fullscreen and 0 or width, fullscreen and 0 or height, {
		fullscreen = fullscreen,
		fullscreentype = fullscreen and "desktop" or nil,
		resizable = not fullscreen,
		vsync = 1,
		msaa = msaa,
	})
end

local function launchGame(onOverlayOpened)
	local Save = require("core.save")

	Save.load()
	require("core.hotkeys").refreshFromSave()
	configureWindow(Save.data.settings or {})
	require("core.bootstrap").initFull()
	require("core.steam").setOverlayHook(onOverlayOpened)
end

function Launcher.run(mode, onOverlayOpened)
	local toolModule = TOOL_MODES[mode]
	if toolModule then
		return require(toolModule).run()
	end

	return launchGame(onOverlayOpened)
end

return Launcher
