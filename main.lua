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
local Sim = require("core.sim")
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

local FIXED_DT = 1 / 120 -- Fixed step
local ACCUM = 0 -- Frame accumulator

function resetGame()
	-- Remove! Just testing. Brute force.
	--State.worldMapIndex = 2

    -- Clear world state
    Enemies.clear()
    Towers.clear()
    Projectiles.clear()
    Effects.clear()
    Floaters.clear()

    -- Map state
    MapMod.clearBlocked()
    MapMod.buildPath(Maps[State.worldMapIndex])

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

	Camera.load()
end

function love.load(arg)
	print(Constants.VERSION_STRING)

	love.math.setRandomSeed(123456)

	local mode = arg and arg[1]

	require("core.environment").load()

	if mode == "art" then
		return require("tools.art_export").run()
	elseif mode == "map" then
		return require("tools.map_export.main").run()
	elseif mode == "trailer" then
		require("tools.trailer.main").run()
	else
	    require("core.bootstrap").initFull()
		require("ui.menu.menu").load()
	end
end


	local lastMem = 0

	function debugGC()
		local mem = collectgarbage("count")
		if math.abs(mem - lastMem) > 20 then
			print("GC spike:", mem - lastMem)
		end
		lastMem = mem
	end

function love.update(dt)
	dt = min(dt, 0.1)

	local mode = State.mode
	local target = (mode == "pause") and 1 or 0

	State.pauseT = State.pauseT + (target - State.pauseT) * min(1, dt * 14)

	Cursor.update(dt)
	Rumble.update(dt)

	if mode == "pause" then
		Menu.updatePause(dt)

		return
	end

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

	ACCUM = ACCUM + dt

	while ACCUM >= FIXED_DT do
		Sim.update(FIXED_DT * State.speed)
		ACCUM = ACCUM - FIXED_DT
	end

	State.renderAlpha = ACCUM / FIXED_DT

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

	--Sim.update(dt)

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

	debugGC()
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

	print("Controller name:", name)

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