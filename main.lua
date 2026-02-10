-- Hydra TD: Dec 19 2025, 2:22 AM

local Constants = require("core.constants")
local Scale = require("core.scale")
local Camera = require("core.camera")
local Cursor = require("core.cursor")
local Theme = require("core.theme")
local Sound = require("systems.sound")
local Fonts = require("core.fonts")
local State = require("core.state")
local Save = require("core.save")
local MapMod = require("world.map")
local Maps = require("world.map_defs")
local Enemies = require("world.enemies")
local Towers = require("world.towers")
local Effects = require("world.effects")
local Projectiles = require("world.projectiles")
local Floaters = require("ui.floaters")
local Waves = require("systems.waves")
local Tooltip = require("ui.tooltip")
local Draw = require("ui.draw")
local Glyphs = require("ui.glyphs")
local DrawWorld = require("ui.draw_world")
local Input = require("ui.input")
local Difficulty = require("systems.difficulty")
local Menu = require("ui.menu.menu")
local Hotkeys = require("core.hotkeys")
local Rumble = require("systems.rumble")
local Localization = require("core.localization")
local Victory = require("ui.menu.screens.victory")
local GameOver = require("ui.menu.screens.game_over")

local lg = love.graphics
local lk = love.keyboard
local lm = love.mouse

local max = math.max
local min = math.min
local abs = math.abs

local colorGood = Theme.ui.good
local colorBad = Theme.ui.bad
local colorText = Theme.ui.text
local colorBg = Theme.terrain.bg

local MAX_DT = 1 / 60

-- Artwork export, always make sure it's disabled
local ART_EXPORT = 0
local TRAILER_EXPORT = 0

function resetGame()
	-- Remove! Just testing. Brute force.
	--State.mapIndex = 2

    -- Clear world state
    Enemies.clear()
    Towers.clear()
    Projectiles.clear()
    Effects.clear()
    Floaters.clear()

    -- Map state
    MapMod.clearBlocked()
    MapMod.buildPath(Maps[State.mapIndex])

	local diff = Difficulty.get()

    -- Core game state
    State.money = diff.startMoney
    State.moneyLerp = State.money
    State.lives = diff.startLives
    State.score = 0
    State.wave = 0

    State.inPrep = true
    State.prepTimer = 6.0
    State.paused = false
    State.speed = 1

    -- Placement / selection
    State.placing = nil
    State.selectedTower = nil
    State.hoverGX = nil
    State.hoverGY = nil

    State.gameOver = false
    State.victory = false
    State.endless = false
    State.activeBoss = nil

    -- Reset damage stats
    State.stats.damageByTower = {}
    State.stats.bossDamageByTower = {}
    State.stats.totalDamage = 0
    State.stats.bossTotalDamage = 0
    State.stats.damageView = 0

    -- Waves
    Waves.resetSpawner()
end

function love.load()
	print(Constants.VERSION_STRING)

	love.math.setRandomSeed(123456) -- Lock determinism

	if ART_EXPORT == 1 then
		require("tools.art_export").run()

		return
	end

	love.mouse.setVisible(false)

	-- If a joystick exists at boot, assume controller-first until mouse movement is received
	if #love.joystick.getJoysticks() > 0 then
		Cursor.enableVirtual()
	end

	Save.load()

	love.window.setTitle("Hydra TD")
	--love.window.setMode(0, 0, {fullscreen = true, fullscreentype = "desktop", vsync = 1})

	-- Testing resolution scaling
	--love.window.setMode(2560, 1440, {fullscreen = false, resizable = false}) -- 1440p
	--love.window.setMode(1920, 1080, {fullscreen = false, resizable = false}) -- 1080
	--love.window.setMode(1280, 720, {fullscreen = false, resizable = false}) -- 720p testing
	--love.window.setMode(1366, 768, {fullscreen = false, resizable = false}) -- laptops
	--love.window.setMode(1280, 800, {fullscreen = false, resizable = false}) -- steam deck
	--love.window.setMode(1024, 768, {fullscreen = false, resizable = false}) -- torture test

	lg.setDefaultFilter("nearest", "nearest")

	Difficulty.set(Save.data.settings.difficulty)

	Localization.load(Save.data.settings.language or "enUS")

	Fonts.load()

	Scale.update()
	Camera.load()

	Sound.load()

	Sound.playMusic("bg")

	if TRAILER_EXPORT == 1 then
		require("tools.trailer.main").run()

		return
	end

	lg.setBackgroundColor(colorBg)

	Menu.load()

	require("ui.glyph_defs")

	--require("ui.glyphs").exportSheet("glyphs.png", {cols = 6})
end

function love.update(dt)
	local mode = State.mode
	local target = (mode == "pause") and 1 or 0

	State.pauseT = State.pauseT + (target - State.pauseT) * min(1, dt * 14)

	Cursor.update(dt)
	Rumble.update(dt)

	if mode == "pause" then
		Menu.updatePause(dt)

		return
	end

	--if mode == "menu" or mode == "campaign" or mode == "settings" or mode == "game_over" or mode == "victory" then
	if mode ~= "game" then -- Pause already bailed right there ^
		Menu.update(dt)
	end

	if mode == "campaign" then
		State.carouselT = math.min(1, State.carouselT + dt * 7)

		if State.carouselT >= 1 then
			State.carouselDir = 0
		end
	end

	if mode ~= "game" then
		return
	end

	Input.updateHover()

	if State.paused then
		return
	end

	dt = min(dt, MAX_DT)
	--dt = min(dt * State.speed, MAX_DT)
	dt = dt * State.speed

	State.livesAnim = max(0, State.livesAnim - dt * 4.5)
	State.waveAnim = max(0, State.waveAnim - dt * 4.5)

	-- Placement ghost fade
	if State.placing then
		State.placingFadeT = min(1, State.placingFadeT + dt * 12)
	else
		State.placingFadeT = 0
	end

	local p = State.placingFadeT
	State.placingFade = p * p * (3 - 2 * p)

	Waves.updatePrep(dt)
	Waves.updateSpawner(dt)
	Enemies.updateEnemies(dt)
	Towers.updateTowers(dt)
	Projectiles.update(dt)
	Effects.update(dt)
	Floaters.update(dt)
	Tooltip.update(dt)

	-- Loss condition
	if State.lives <= 0 and not State.gameOver then
		State.gameOver = true
		State.victory = false

		State.mode = "game_over"

		Sound.play("gameOver")

		return
	end

	-- If wave is finished, go to prep
	if not State.inPrep and Waves.allEnemiesCleared() then
		-- Win condition: wave 20 cleared
		if State.wave == 20 and not State.endless then
			-- Save
			Save.data.furthestIndex = math.max(Save.data.furthestIndex, State.mapIndex + 1)
			Save.flush()

			State.gameOver = true
			State.victory = true

			State.mode = "victory"

			Sound.play("victory")

			return
		end

		-- Otherwise continue as normal
		State.inPrep = true
		State.prepTimer = 6.0
	end
end

function love.draw()
	local sw, sh = lg.getDimensions()

	if State.mode == "game" or State.mode == "pause" or State.mode == "game_over" or State.mode == "victory" then
		-- World
		Camera.begin()
		Draw.drawWorld()

		Camera.finish()
		Camera.present()

		-- UI
		Draw.drawUI()

		if State.mode == "pause" then
			local t = State.pauseT
			local ease = t * t * (3 - 2 * t)

			-- Dim overlay
			lg.setColor(0, 0, 0, 0.55 * ease)
			lg.rectangle("fill", 0, 0, sw, sh)

			-- Text motion
			local drop = (1 - ease) * 10
			local alpha = ease

			-- Text
			Fonts.set("menu")

			lg.setColor(colorText[1], colorText[2], colorText[3], ease)
			lg.printf("PAUSED", 0, sh * 0.5 - 70 + drop, sw, "center")

			Menu.drawPause()
		end

		if State.mode == "game_over" or State.mode == "victory" then
			Menu.draw()
		end

		Cursor.draw()
		Tooltip.draw()
	else
		Menu.draw()

		Cursor.draw()
		Tooltip.draw()
	end
end

function love.mousepressed(x, y, button)
	if State.mode == "pause" then
		if Menu.mousepressedPause(x, y, button) then
			return
		end
	end

	Input.mousepressed(x, y, button)
end

function love.mousereleased(x, y, button)
	Input.mousereleased(x, y, button)
end

function love.mousemoved(x, y, dx, dy)
	if abs(dx) + abs(dy) > 2 then
		Cursor.disableVirtual()
		State.inputSource = "mouse"
	end

	Cursor.mousemoved(x, y)
end

function love.keypressed(key)
	--State.inputSource = "keyboard"

	if key == Hotkeys.kb.actions.screenshot then
		local time = os.date("%Y-%m-%d_%H-%M-%S")
		lg.captureScreenshot("screenshot_" .. time .. ".png")
	end

	if State.mode ~= "game" then
		Menu.keypressed(key)

		return
	end

	Input.keypressed(key)
end

local function detectControllerType(joystick)
	local name = joystick:getName():lower()

	-- Steam Deck
	if name:find("steam") then
		return "steamdeck"
	end

	-- PlayStation
	if name:find("dualshock") or name:find("dualsense") or name:find("playstation") or name:find("ps4") or name:find("ps5") then
		return "playstation"
	end

	-- Xbox (default)
	if name:find("xbox") or name:find("xinput") then
		return "xbox"
	end

	-- Fallback: treat unknown gamepads as Xbox
	return "xbox"
end

function love.gamepadpressed(joystick, button)
	State.inputSource = "controller"

	local platform = detectControllerType(joystick)

	if platform and platform ~= State.lastInputPlatform then
		State.lastInputPlatform = platform
		Glyphs.setPlatform(platform)
	end

	Input.gamepadpressed(joystick, button)
end

function love.gamepadreleased(joystick, button)
	local platform = detectControllerType(joystick)

	if platform and platform ~= State.lastInputPlatform then
		State.lastInputPlatform = platform
		Glyphs.setPlatform(platform)
	end

	Input.gamepadreleased(joystick, button)
end

function love.gamepadaxis(joystick, axis, value)
	if abs(value) > 0.3 then
		State.inputSource = "controller"

		local platform = detectControllerType(joystick)

		if platform and platform ~= State.lastInputPlatform then
			State.lastInputPlatform = platform
			Glyphs.setPlatform(platform)
		end
	end
end

function love.joystickremoved(joystick)
	if State.mode == "game" then
		State.mode = "pause"
	end
end

function love.joystickadded(joystick)
	local platform = detectControllerType(joystick)

	if platform and platform ~= State.lastInputPlatform then
		State.lastInputPlatform = platform
		Glyphs.setPlatform(platform)
	end
end

function love.resize(w, h)
	Scale.update()
	Camera.resize()
	require("ui.title").invalidateCache()
	require("ui.menu.screens.campaign").resize(w, h)
end

function love.focus(focused)
	if not focused then
		-- Steam Overlay / alt-tab
		if State.mode == "game" then
			State.mode = "pause"
		end
	end
end
