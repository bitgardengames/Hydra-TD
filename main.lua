local Constants = require("core.constants")
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
local Draw = require("ui.draw")
local Input = require("ui.input")
local Difficulty = require("systems.difficulty")
local Menu = require("ui.menu")
local Hotkeys = require("core.hotkeys")
local Rumble = require("systems.rumble")
local Localization = require("core.localization")

local lg = love.graphics
local lk = love.keyboard
local lm = love.mouse
local getTime = love.timer.getTime

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
    State.stats.damageByTower = {
		lancer = 0,
		slow = 0,
		cannon = 0,
        shock = 0,
        poison = 0,
    }

    State.stats.bossDamageByTower = {}
    State.stats.totalDamage = 0
    State.stats.bossTotalDamage = 0
    State.stats.damageView = 0

    -- Waves
    Waves.resetSpawner()
end

function love.load()
	-- Remove for public release
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

	lg.setDefaultFilter("nearest", "nearest")

	Localization.load(Save.data.settings.language or "enUS")

	Fonts.load()

	Camera.load()

	Sound.load()

	if TRAILER_EXPORT == 1 then
		require("tools.trailer.main").run()

		return
	end

	Sound.playMusic("bg")

	lg.setBackgroundColor(colorBg)
	--love.math.setRandomSeed(123456) -- Lock determinism

	Menu.load()
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

	if mode == "menu" or mode == "campaign" or mode == "settings" then
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

	-- Game over: simple restart on click
	if State.gameOver then
		State.endT = min(1, State.endT + dt * 2.8)

		if State.endT > 0.85 then
			State.endReady = true
		end

		-- Restart only after settle, and only on defeat
		if State.endReady and not State.victory and lm.isDown(1) then
			resetGame()
		end

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

	-- If wave is finished, go to prep
	if not State.inPrep and Waves.allEnemiesCleared() then
		-- Win condition: wave 20 cleared
		if State.wave == 20 and not State.endless then
			-- Save
			Save.data.furthestIndex = math.max(Save.data.furthestIndex, State.mapIndex + 1)
			Save.flush()

			State.gameOver = true
			State.victory = true

			State.endT = 0
			State.endReady = false
			State.endTitle  = "VICTORY"
			State.endReason = "Wave 20 cleared"

			Sound.play("victory")
			--Floaters.add(Constants.SCREEN_W / 2 - 40, Constants.SCREEN_H / 2 - 40, "VICTORY!", colorGood[1], colorGood[2], colorGood[3])

			return
		end

		-- Otherwise continue as normal
		State.inPrep = true
		State.prepTimer = 6.0
		-- Note, move these floaters or signal the message elsewhere. Floaters are for game messaging, not UI messaging
		--Floaters.add(20, 20, "Wave cleared!", colorGood[1], colorGood[2], colorGood[3])
	end
end

function love.draw()
	local sw, sh = lg.getDimensions()

	if State.mode == "game" or State.mode == "pause" then
		Camera.begin()
		Draw.drawWorld()

		--[[ Debug draw map center
		local mapCX = Constants.GRID_W * Constants.TILE * 0.5
		local mapCY = Constants.GRID_H * Constants.TILE * 0.5

		lg.setColor(1, 0, 0)
		lg.circle("fill", mapCX, mapCY, 6)

		-- draw screen center in world space
		local sw, sh = lg.getDimensions()
		local wx, wy = Camera.screenToWorld(sw/2, sh/2)

		lg.setColor(0, 1, 0)
		lg.circle("fill", wx, wy, 4)]]

		Camera.finish()
		Camera.present()

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
		elseif State.gameOver then
			local t = State.endT
			local ease = t * t * (3 - 2 * t)

			-- Overlay
			local overlayA = 0.78 * ease
			lg.setColor(0, 0, 0, overlayA)
			lg.rectangle("fill", 0, 0, sw, sh)

			-- Text motion
			local drop = (1 - ease) * 8
			local textY = sh / 2 - 36 + drop
			local titleY  = textY
			local reasonY = titleY + 32
			local actionY = reasonY + 52

			-- Color
			local color = State.victory and colorGood or colorBad
			lg.setColor(color[1], color[2], color[3], ease)

			-- Title
			lg.setColor(color[1], color[2], color[3], ease)
			lg.printf(State.endTitle, 0, titleY, sw, "center")

			-- Reason
			if State.endReason and State.endT > 0.25 then
				lg.setColor(1, 1, 1, 0.55 * ease)
				lg.printf(State.endReason, 0, reasonY, sw, "center")
			end

			-- Actions
			lg.setColor(1, 1, 1, 0.65 * ease)

			if State.endReady then
				if State.victory then
					lg.printf("[N] Next Map    [E] Endless", 0, actionY, sw, "center")
				else
					lg.printf("Click to Restart", 0, actionY, sw, "center")
				end
			end
		end

		Cursor.draw()
	else
		Menu.draw()

		Cursor.draw()
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

function love.keypressed(key)
	if key == Hotkeys.actions.screenshot then
		local time = os.date("%Y-%m-%d_%H-%M-%S")
		lg.captureScreenshot("screenshot_" .. time .. ".png")
	end

	if State.mode == "game" and key == "p" then
		State.mode = "pause"

		return
	elseif State.mode == "pause" and key == "p" then
		State.mode = "game"

		return
	end

	if State.mode == "pause" then
		if key == "r" then
			State.mode = "game"
			resetGame()
		elseif key == "m" then
			State.mode = "menu"
		end

		return
	end

	if State.mode ~= "game" then
		Menu.keypressed(key)

		return
	end

	Input.keypressed(key)
end

local lastPadClick = 0

function love.gamepadpressed(_, button)
	Cursor.enableVirtual()

	local now = getTime()

	if button == "a" then
		if now - lastPadClick > 0.12 then
			love.mousepressed(Cursor.x, Cursor.y, 1)
			lastPadClick = now
		end
	elseif button == "b" then
		love.mousepressed(Cursor.x, Cursor.y, 2)
	end
end

function love.mousemoved(x, y, dx, dy)
	if abs(dx) + abs(dy) > 2 then
		Cursor.disableVirtual()
	end

	Cursor.mousemoved(x, y)
end

function love.resize(w, h)
	Camera.resize(w, h)
end