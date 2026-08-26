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
	-- Warm the campaign's native list thumbnails. Larger previews are generated
	-- lazily once their final layout size is known.
	MapPreviewCache.buildAll(118, 66)
	Menu.load()
	Effects.load()
	Projectiles.load()

	Steam.setRichPresence(L("presence.menu"))
end

function Bootstrap.initMinimal()
	-- Not sure if you live here permanently
	local Save = require("core.save")
	Save.load()
	require("core.window").apply(Save.data.settings)
	require("core.localization").load("enUS")
	require("systems.sound").load()
	require("core.fonts").load()
	require("core.scale").update()
	require("core.camera").load()
end

return Bootstrap
