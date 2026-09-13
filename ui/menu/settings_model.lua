local Sound = require("systems.sound")
local Theme = require("core.theme")
local Save = require("core.save")
local Util = require("core.util")
local L = require("core.localization")

local Model = {}

local keyboardControlsLayout = {
	{kind = "action", id = "escape", label = "settings.controlPause"},
	{kind = "action", id = "returnToMenu", label = "settings.controlReturnToMenu"},
	{kind = "action", id = "fastForward", label = "settings.controlSpeed"},
	{kind = "action", id = "skipPrep", label = "settings.controlStartWave"},
	{kind = "action", id = "upgrade", label = "settings.controlUpgrade"},
	{kind = "action", id = "sell", label = "settings.controlSell"},
	{kind = "shop", id = "slow", label = "settings.controlPlaceSlow"},
	{kind = "shop", id = "lancer", label = "settings.controlPlaceLancer"},
	{kind = "shop", id = "poison", label = "settings.controlPlacePoison"},
	{kind = "shop", id = "cannon", label = "settings.controlPlaceCannon"},
	{kind = "shop", id = "shock", label = "settings.controlPlaceShock"},
	{kind = "shop", id = "plasma", label = "settings.controlPlacePlasma"},
	{kind = "action", id = "toggleMeter", label = "settings.controlDamageMeter"},
}

local function formatPercent(value)
	return L("settings.percentValue", math.floor(Util.clamp(value, 0, 1) * 100 + 0.5))
end

local function slider(id, label, description, color, get, set)
	return {id = id, label = label, description = description, type = "slider", color = color, get = get, set = set,
		valueFormatter = formatPercent}
end

local function toggle(id, label, setting, description, set)
	return {id = id, label = label, description = description, type = "toggle",
		get = function() return Save.data.settings[setting] end,
		set = set or function(value) Save.data.settings[setting] = value end}
end

local function choice(id, label, description, choices, get, set)
	return {id = id, label = label, description = description, type = "choice",
		choices = choices, get = get, set = set}
end

local function keybindRows(capture, options)
	local rows = {}
	for _, def in ipairs(keyboardControlsLayout) do
		rows[#rows + 1] = {
			id = string.format("bind_%s_%s", def.kind, def.id), label = L(def.label), type = "keybind",
			bindingKind = def.kind, bindingId = def.id,
			valueFormatter = function(row) return capture:text(row) end,
		}
	end
	rows[#rows + 1] = {id = "restore_defaults_controls", label = L("settings.controlsRestoreDefaults"),
		type = "action", onClick = options.onRestoreKeybindDefaults}
	return rows
end

function Model.build(capture, options)
	options = options or {}
	local onRestoreKeybindDefaults = options.onRestoreKeybindDefaults
		or function() capture:restoreDefaults() end
	local keybindOptions = {onRestoreKeybindDefaults = onRestoreKeybindDefaults}
	local Window = require("core.window")
	local function applyWindow() Window.apply(Save.data.settings) end
	local function displays() return Window.getDisplays() end
	local function monitorChoices()
		local result = {}
		for _, display in ipairs(displays()) do
			result[#result + 1] = {value = display.index,
				label = L("settings.monitorValue", display.index, display.width, display.height)}
		end
		return result
	end
	local function resolutionChoices()
		local all = displays()
		local display = all[Save.data.settings.displayIndex] or all[1]
		local result = {}
		for _, mode in ipairs(display.resolutions) do
			result[#result + 1] = {value = mode.width .. "x" .. mode.height,
				width = mode.width, height = mode.height, label = L("settings.resolutionValue", mode.width, mode.height)}
		end
		return result
	end
	local function resolutionValue()
		local settings = Save.data.settings
		if settings.displayMode == "borderless" then
			local display = displays()[settings.displayIndex]
			return display.width .. "x" .. display.height
		end
		local prefix = settings.displayMode == "fullscreen" and "fullscreen" or "window"
		return settings[prefix .. "Width"] .. "x" .. settings[prefix .. "Height"]
	end
	return {
		{id = "audio", label = L("settings.tabAudio"), rows = {
			slider("music", L("settings.music"), nil, Theme.tower.shock,
				function() return Save.data.settings.musicVolume end,
				function(v) Save.data.settings.musicVolume = v; Sound.setMusicVolume(v) end),
			slider("gameplay_sfx", L("settings.gameplaySounds"), L("settings.gameplaySoundsDesc"), Theme.tower.cannon,
				function() return Save.data.settings.gameplaySfxVolume end,
				function(v) Save.data.settings.gameplaySfxVolume = v; Sound.setSFXVolume() end),
			slider("ui_sfx", L("settings.interfaceSounds"), L("settings.interfaceSoundsDesc"), Theme.tower.lancer,
				function() return Save.data.settings.uiVolume end,
				function(v) Save.data.settings.uiVolume = v; Sound.setSFXVolume() end),
			toggle("mute_unfocused", L("settings.muteWhenUnfocused"), "muteWhenUnfocused",
				L("settings.muteWhenUnfocusedDesc"), function(v) Sound.setMuteWhenUnfocused(v) end),
		}},
		{id = "video", label = L("settings.tabVideo"), rows = {
			toggle("camera_motion", L("settings.cameraMotion"), "cameraMotion", L("settings.cameraMotionDesc")),
			toggle("damage_numbers", L("settings.damageNumbers"), "showDamageNumbers", L("settings.damageNumbersDesc")),
			choice("display_mode", L("settings.displayMode"), L("settings.displayModeDesc"), {
				{value = "windowed", label = L("settings.displayModeWindowed")},
				{value = "borderless", label = L("settings.displayModeBorderless")},
				{value = "fullscreen", label = L("settings.displayModeFullscreen")},
			}, function() return Save.data.settings.displayMode end,
			function(value) Save.data.settings.displayMode = value; applyWindow() end),
			choice("monitor", L("settings.monitor"), L("settings.monitorDesc"), monitorChoices,
				function() return Save.data.settings.displayIndex end,
				function(value)
					Save.data.settings.displayIndex = value
					Window.normalizeSettings(Save.data.settings)
					applyWindow()
				end),
			choice("resolution", L("settings.resolution"), L("settings.resolutionDesc"), resolutionChoices,
				resolutionValue, function(_, selected)
					local settings = Save.data.settings
					if settings.displayMode == "fullscreen" then
						settings.fullscreenWidth, settings.fullscreenHeight = selected.width, selected.height
					elseif settings.displayMode == "windowed" then
						settings.windowWidth, settings.windowHeight = selected.width, selected.height
					end
					applyWindow()
				end),
		}},
		{id = "controls_keyboard", label = L("settings.tabControlsKeybinds"), rows = keybindRows(capture, keybindOptions)},
	}
end

return Model
