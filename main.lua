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
local MapWorldCache = require("world.map_world_cache")
local Enemies = require("world.enemies")
local Towers = require("world.towers")
local Effects = require("world.effects")
local Projectiles = require("world.projectiles")
local Floaters = require("ui.floaters")
local Waves = require("systems.waves")
local Sim = require("core.sim")
local Tooltip = require("ui.tooltip")
local Messages = require("ui.messages")
local Draw = require("render.draw")
local Glyphs = require("ui.glyphs")
local DrawWorld = require("render.draw_world")
local Trees = require("world.scatter_trees")
local Cacti = require("world.scatter_cactus")
local Rocks = require("world.scatter_rocks")
local Mushrooms = require("world.scatter_mushrooms")
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
local L = require("core.localization")
local Modules = require("systems.modules")
local ModulePicker = require("ui.module_picker")

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

	local seed = 123456 + State.worldMapIndex * 1009
	love.math.setRandomSeed(seed)

	local biome = MapMod.map.biome
	local scatter = biome and biome.scatter

	if scatter then
		if scatter.rocks and scatter.rocks.enabled then
			Rocks.generate(scatter.rocks)
		end

		if scatter.trees and scatter.trees.enabled then
			Trees.generate(scatter.trees)
		end

		if scatter.cactus and scatter.cactus.enabled then
			Cacti.generate(scatter.cactus)
		end

		if biome.scatter.mushrooms and biome.scatter.mushrooms.enabled then
			Mushrooms.generate()
		end
	end

	MapWorldCache.invalidate()

	local diff = Difficulty.get()

    -- Core game state
    State.money = diff.startMoney
    State.moneyLerp = State.money
    State.lives = diff.startLives
    State.score = 0
    State.wave = 1
	State.waveLeaks = 0
	State.totalLeaks = 0

	State.modules = {}

    State.inPrep = true
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

	-- Modules
	Modules.clear()

	State.modulePicker.active = false
	State.modulePicker.choices = nil
	State.modulePicker.waveOffered = 0
	State.modulePicker.mode = "wave_reward"
	State.modulePicker.title = nil
	State.modulePicker.subtitle = nil
	State.modulePicker.hint = nil
	State.modulePicker.tower = nil

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

	-- Just make a loader already, if there's this many modes now
	if mode == "art" then
		return require("tools.art_export").run()
	elseif mode == "achievements" then
		require("tools.achievement_export").run()
	elseif mode == "map" then
		return require("tools.map_export.main").run()
	elseif mode == "trailer" then
		require("tools.trailer.trailer_main").run()
	elseif mode == "capsule" then
		require("tools.capsule_export").run()
	else
		Save.load()

		local settings = Save.data.settings or {}

		-- Decide window mode
		if settings.fullscreen then
			local dmW, dmH = love.window.getDesktopDimensions()
			local msaa = Scale.suggestMSAA(dmW, dmH) or 8

			love.window.updateMode(0, 0, {fullscreen = true, fullscreentype = "desktop", vsync = 1, msaa = msaa})
		else
			local msaa = Scale.suggestMSAA(1280, 800) or 8

			love.window.updateMode(1280, 800, {fullscreen = false, resizable = true, vsync = 1, msaa = msaa})
		end

		require("core.bootstrap").initFull()

		Steam.setOverlayHook(pauseGame)
	end

	collectgarbage("collect")
end

local clamp = 1 / 30

-- What is this name? lol "maybeDoSomething"
function love.update(dt)
	dt = min(dt, clamp)

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

	if State.paused then
		return
	end

	local gameplayFrozen = ModulePicker.isActive()

	if gameplayFrozen then
		-- Don't accumulate simulation time while the module picker is open.
		-- Otherwise, choosing late will process a large backlog in one frame.
		ACCUM = 0
	else
		ACCUM = ACCUM + dt

		while ACCUM >= FIXED_DT do
			Sim.update(FIXED_DT * State.speed)

			ACCUM = ACCUM - FIXED_DT
		end
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
	Messages.update(dt)

	if gameplayFrozen then
		return
	end

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
		--if State.wave == 1 and not State.endless then
		if State.wave == 20 and not State.endless then
			-- Save
			local nextMapIndex = min(State.worldMapIndex + 1, #Maps)
			Save.data.furthestIndex = max(Save.data.furthestIndex, nextMapIndex)

			Achievements.onGameOver()

			State.speed = 0.35
			State.gameOver = true
			State.victory = true

			finalizeCurrentRun(true)

			-- No Leak Achievement
			if State.totalLeaks == 0 then
				local diff = Difficulty.key()

				if diff == "hard" then
					Achievements.unlock("NO_LEAKS_NORMAL")
					Achievements.unlock("NO_LEAKS_HARD")
				elseif diff == "normal" then
					Achievements.unlock("NO_LEAKS_NORMAL")
				end
			end

			ACCUM = 0 -- Reset frame accumulator
			Menu.set("victory") -- All of this logic should be migrated to Victory.enter() now
			Sound.play("victory")

			Save.flush()

			return
		end

		if State.waveLeaks == 0 then
			local bonus = 2 * State.wave
			State.money = State.money + bonus

			Messages.add(L("messages.bonus", bonus), 0.6, 1.0, 0.6)
		end

		-- Otherwise continue as normal
		State.wave = State.wave + 1
		State.waveAnim = State.waveAnim + (1 - State.waveAnim) * 0.6
		State.inPrep = true
	end
end

function love.draw()
	local sw, sh = lg.getDimensions()

	lg.setColor(1, 1, 1)

	if State.mode == "game" or State.mode == "pause" or State.mode == "game_over" or State.mode == "victory" then
		-- World
		Camera.begin()
		Draw.drawWorld()

		Camera.finish()
		Camera.present()

		-- UI
		Draw.drawUI()
		ModulePicker.draw() -- This should all be part of drawUI, not in main.lua

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

	if ModulePicker.isActive() then
		if ModulePicker.mousepressed(x, y, button) then
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

	if ModulePicker.isActive() then
		if ModulePicker.keypressed(key) then
			return
		end
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
	--Scale.update()
	--Camera.resize()
	MapWorldCache.invalidate()
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
