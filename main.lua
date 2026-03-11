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
local Draw = require("render.draw")
local Glyphs = require("ui.glyphs")
local DrawWorld = require("render.draw_world")
local DamageMeter = require("ui.damage_meter")
local Input = require("ui.input")
local Difficulty = require("systems.difficulty")
local Achievements = require("systems.achievements")
local Menu = require("ui.menu.menu")
local Overlay = require("ui.overlay")
local Hotkeys = require("core.hotkeys")
local Rumble = require("systems.rumble")
local Victory = require("ui.menu.screens.victory")
local GameOver = require("ui.menu.screens.game_over")
local Steam = require("core.steam")

local lg = love.graphics
local lk = love.keyboard
local lm = love.mouse

local max = math.max
local min = math.min
local abs = math.abs

local colorGood = Theme.ui.good
local colorBad = Theme.ui.bad
local colorText = Theme.ui.text
local colorDim = Theme.ui.screenDim

local cd1, cd2, cd3, cd4 = colorDim[1], colorDim[2], colorDim[3], colorDim[4]

local FIXED_DT = 1 / 120 -- Fixed step
local ACCUM = 0 -- Frame accumulator

local SCREENSHOT_DIR = "screenshots"

-- Revisit this being a global
function finalizeCurrentRun(completed)
	--if State.mode ~= "game" and State.mode ~= "pause" then
	--	return
	--end

	if State.ignoreStats then
		return
	end

	local map = Maps[State.worldMapIndex]
	local mapId = map.id
	local stats = Save.data.mapStats[mapId]

	State.previousCompletionDifficulty = stats and stats.completedDifficulty or nil

	if not map then
		return
	end

	Save.recordMapResult(mapId, State.wave or 0, Difficulty.key(), completed == true)
end

function resetGame()
	--State.worldMapIndex = 1 -- Map override

    -- Clear world state
    Enemies.clear()
    Towers.clear()
    Projectiles.clear()
    Effects.clear()
    Floaters.clear()

    -- Map state
    MapMod.clearBlocked()
    MapMod.buildPath(Maps[State.worldMapIndex])

	-- Map palettes
	--[[local palette = MapMod.getPalette()

	if palette then
		DrawWorld.updateGrassColor(palette.grass)
		DrawWorld.updatePathColor(palette.path)

		if palette.water then
			DrawWorld.updateWaterColor(palette.water)
		end
	end]]

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

    -- Reset damage stats and cached values
	State.resetDamage()
	DamageMeter.reset()

    -- Waves
    Waves.resetSpawner()

	Camera.load()
end

local pauseGame = function()
	if State.mode == "game" then
		State.mode = "pause"
		Sound.enterPause()
	end
end

function love.load(arg)
	print(Constants.VERSION_STRING)

	love.math.setRandomSeed(123456)

	math.randomseed(os.time())
	math.random()

	local mode = arg and arg[1]

	require("core.environment").load()

	if mode == "art" then
		return require("tools.art_export").run()
	elseif mode == "achievements" then
		require("tools.achievement_export").run()
	elseif mode == "map" then
		return require("tools.map_export.main").run()
	elseif mode == "trailer" then
		require("tools.trailer.main").run()
	else
	    require("core.bootstrap").initFull()
		require("ui.menu.menu").load()

		Steam.setOverlayHook(pauseGame)
	end
end

function love.update(dt)
	dt = min(dt, 0.1)

	local mode = State.mode
	local target = (mode == "pause") and 1 or 0

	State.pauseT = State.pauseT + (target - State.pauseT) * min(1, dt * 14)

	Cursor.update(dt)
	Rumble.update(dt)
	Steam.update()
	Sound.update(dt)

	if mode == "pause" then
		Menu.updatePause(dt)

		return
	end

	if mode ~= "game" then
		Menu.update(dt)
		Overlay.update(dt)

		if mode == "campaign" then
			State.carouselT = min(1, State.carouselT + dt * 7)

			if State.carouselT >= 1 then
				State.carouselDir = 0
			end
		end

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

	if mode == "victory" then
		Menu.update(dt)
		Overlay.update(dt)
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

	Tooltip.update(dt)

	-- Loss condition
	if State.lives <= 0 and not State.gameOver then
		State.gameOver = true
		State.victory = false

		Achievements.onGameOver()

		finalizeCurrentRun(false)

		--Menu.set("game_over") -- All of this logic should be migrated to GameOver.enter() now
		State.mode = "game_over"

		Sound.play("gameOver")

		return
	end

	-- If wave is finished, go to prep
	if not State.inPrep and Waves.allEnemiesCleared() then
		-- Win condition: wave 20 cleared
		if State.wave == 20 and not State.endless then
			-- Save
			local nextMapIndex = min(State.worldMapIndex + 1, #Maps)
			Save.data.furthestIndex = max(Save.data.furthestIndex, nextMapIndex)

			Achievements.onGameOver()

			State.speed = 0.35
			State.gameOver = true
			State.victory = true

			finalizeCurrentRun(true)

			ACCUM = 0 -- Reset frame accumulator
			Menu.set("victory") -- All of this logic should be migrated to Victory.enter() now
			Sound.play("victory")

			Save.flush()

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
			lg.setColor(cd1, cd2, cd3, cd4 * ease)
			lg.rectangle("fill", 0, 0, sw, sh)

			Menu.drawPause()
		end

		if State.mode == "game_over" or State.mode == "victory" then
			Menu.draw()
			Overlay.draw()
		end

		Cursor.draw()
		Tooltip.draw()
	else
		Menu.draw()
		Overlay.draw()

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

	if Overlay.isActive() then
		if Overlay.mousepressed(x, y, button) then
			return
		end
	end

	Input.mousepressed(x, y, button)
end

function love.mousereleased(x, y, button)
	if Overlay.isActive() then
		if Overlay.mousereleased(x, y, button) then
			return
		end
	end

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

		if not love.filesystem.getInfo(SCREENSHOT_DIR) then
			love.filesystem.createDirectory(SCREENSHOT_DIR)
		end

		lg.captureScreenshot(SCREENSHOT_DIR .. "/screenshot_" .. time .. ".png")
	end

	if Overlay.isActive() then
		if Overlay.keypressed(key) then
			return
		end
	end

	if State.mode ~= "game" then
		Menu.keypressed(key)

		return
	end

	Input.keypressed(key)
end

local function detectControllerType(joystick)
	local name = joystick:getName():lower()

	--print("Controller name:", name)

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
	pauseGame()
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
	if not focused then -- Alt-tab or focus loss
		pauseGame()
		love.mouse.setVisible(true)
	else
		love.mouse.setVisible(false)
	end
end

function love.visible(visible)
	if not visible then
		pauseGame()
		love.mouse.setVisible(true)
	else
		love.mouse.setVisible(false)
	end
end

function love.quit()
	Steam.shutdown()
	Achievements.onGameOver()
end