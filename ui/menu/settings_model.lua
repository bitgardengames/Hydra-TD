local Sound = require("systems.sound")
local Theme = require("core.theme")
local Save = require("core.save")
local Util = require("core.util")
local L = require("core.localization")

local Model = {}

local keyboardControlsLayout = {
	{kind = "action", id = "escape", label = "settings.controlPause"},
	{kind = "action", id = "restartRun", label = "settings.controlRestartRun"},
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

local function slider(id, label, color, get, set)
	return {id = id, label = label, type = "slider", color = color, get = get, set = set,
		valueFormatter = formatPercent}
end

local function toggle(id, label, setting, description, set)
	return {id = id, label = label, description = description, type = "toggle",
		get = function() return Save.data.settings[setting] end,
		set = set or function(value) Save.data.settings[setting] = value end}
end

local function keybindRows(capture)
	local rows = {}
	for _, def in ipairs(keyboardControlsLayout) do
		rows[#rows + 1] = {
			id = string.format("bind_%s_%s", def.kind, def.id), label = L(def.label), type = "keybind",
			bindingKind = def.kind, bindingId = def.id,
			valueFormatter = function(row) return capture:text(row) end,
		}
	end
	rows[#rows + 1] = {id = "restore_defaults_controls", label = L("settings.controlsRestoreDefaults"),
		type = "action", onClick = function() capture:restoreDefaults() end}
	return rows
end

function Model.build(capture)
	return {
		{id = "audio", label = L("settings.tabAudio"), rows = {
			slider("music", L("settings.music"), Theme.tower.shock,
				function() return Save.data.settings.musicVolume end,
				function(v) Save.data.settings.musicVolume = v; Sound.setMusicVolume(v) end),
			slider("sfx", L("settings.sfx"), Theme.tower.cannon,
				function() return Save.data.settings.sfxVolume end,
				function(v) Save.data.settings.sfxVolume = v; Sound.setSFXVolume(v) end),
		}},
		{id = "video", label = L("settings.tabVideo"), rows = {
			toggle("camera_motion", L("settings.cameraMotion"), "cameraMotion", L("settings.cameraMotionDesc")),
			toggle("damage_numbers", L("settings.damageNumbers"), "showDamageNumbers", L("settings.damageNumbersDesc")),
			toggle("dense_particles", L("settings.highDensityParticles"), "highDensityParticles", L("settings.highDensityParticlesDesc")),
			toggle("fullscreen", L("settings.fullscreen"), "fullscreen", nil, function(v)
				Save.data.settings.fullscreen = v
				require("core.window").apply(Save.data.settings, v)
			end),
		}},
		{id = "controls_keyboard", label = L("settings.tabControlsKeybinds"), rows = keybindRows(capture)},
	}
end

return Model
