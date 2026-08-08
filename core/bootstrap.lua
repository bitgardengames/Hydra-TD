local Bootstrap = {}

local Save = require("core.save")
local Difficulty = require("systems.difficulty")
local L = require("core.localization")
local Fonts = require("core.fonts")
local Scale = require("core.scale")
local Camera = require("core.camera")
local Steam = require("core.steam")
local Sound = require("systems.sound")
local Hotkeys = require("core.hotkeys")
local MapPreviewCache = require("world.map_preview_cache")
local Menu = require("ui.menu.menu")
local Effects = require("world.effects")
local Projectiles = require("world.projectiles")

local function configureGameWindow(settings)
	if settings.fullscreen then
		local width, height = love.window.getDesktopDimensions()
		local msaa = Scale.suggestMSAA(width, height) or 8
		love.window.updateMode(0, 0, {fullscreen = true, fullscreentype = "desktop", vsync = 1, msaa = msaa})
	else
		local msaa = Scale.suggestMSAA(1280, 800) or 8
		love.window.updateMode(1280, 800, {fullscreen = false, resizable = true, vsync = 1, msaa = msaa})
	end
end

function Bootstrap.initFull()
	Save.load()
	Hotkeys.refreshFromSave()
	configureGameWindow(Save.data.settings or {})

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

	Save.load()
	L.load("enUS")
	Sound.load()
	Fonts.load()
	Scale.update()
	Camera.load()
end

return Bootstrap
