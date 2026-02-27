local Bootstrap = {}

function Bootstrap.initFull()
	local Save = require("core.save")
	local Difficulty = require("systems.difficulty")
	local L = require("core.localization")
	local Fonts = require("core.fonts")
	local Scale = require("core.scale")
	local Camera = require("core.camera")
	local Steam = require("core.steam")
	local Sound = require("systems.sound")

	Save.load()
	Difficulty.set(Save.data.settings.difficulty)
	L.load(Save.data.settings.language or "enUS")
	Fonts.load()
	Scale.update()
	Camera.load()
	Steam.load()
	Sound.load()
	Sound.playMusic("menu")

	Steam.setRichPresence(L("presence.menu"))

	require("ui.glyph_defs")
end

function Bootstrap.initMinimal()
	local Save = require("core.save").load()
	local Localization = require("core.localization")
	local Sound = require("systems.sound").load()

	require("core.fonts").load()
	require("core.scale").update()
	require("core.camera").load()

	Localization.load("enUS")
end

return Bootstrap