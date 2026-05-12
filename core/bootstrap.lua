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
	local MapPreviewCache = require("world.map_preview_cache")
	local Menu = require("ui.menu.menu")
	local Effects = require("world.effects")
	local Projectiles = require("world.projectiles")

	Difficulty.set(Save.data.settings.difficulty)
	L.load(Save.data.settings.language or "enUS")
	Fonts.load()
	Scale.update()
	Camera.load()
	Steam.load()
	Sound.load()
	Sound.playMusic("menu")
	MapPreviewCache.buildAll(520, 312)
	Menu.load()
	Effects.load()
	Projectiles.load()

	Steam.setRichPresence(L("presence.menu"))

end

function Bootstrap.initMinimal()
	-- Not sure if you live here permanently
	love.window.updateMode(0, 0, {
		fullscreen = true,
		fullscreentype = "desktop",
		vsync = 1,
		msaa = 8
	})

	--[[love.window.setMode(1080, 1920, {
		--fullscreen = true,
		--fullscreentype = "desktop",
		vsync = 1,
		msaa = 8
	})]]

	local Save = require("core.save").load()
	local Localization = require("core.localization")
	local Sound = require("systems.sound").load()

	require("core.fonts").load()
	require("core.scale").update()
	require("core.camera").load()

	Localization.load("enUS")
end

return Bootstrap