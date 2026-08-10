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
	return require("core.window").apply(settings)
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
