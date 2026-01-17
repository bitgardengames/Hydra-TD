local Constants = require("core.constants")
local Camera = require("core.camera")
local Theme = require("core.theme")
local Sound = require("systems.sound")
local Fonts = require("core.fonts")
local State = require("core.state")
local Save = require("core.save")
local MapMod = require("world.map")
local Maps = require("world.maps")
local Enemies = require("world.enemies")
local Towers = require("world.towers")
local Projectiles = require("world.projectiles")
local Floaters = require("ui.floaters")
local Waves = require("systems.waves")
local Draw = require("ui.draw")
local Input = require("ui.input")
local Menu = require("ui.menu")
local Hotkeys = require("core.hotkeys")

local lg = love.graphics
local lk = love.keyboard
local lm = love.mouse

local max = math.max
local min = math.min

local colorGood = Theme.ui.good
local colorBad = Theme.ui.bad
local colorText = Theme.ui.text
local colorBg = Theme.terrain.bg

-- Artwork export, always make sure it's disabled
DEV_EXPORT = 0

function resetGame()
    -- Clear world state
    Enemies.clear()
    Towers.clear()
    Projectiles.clear()
    Floaters.clear()

    -- Map state
    MapMod.clearBlocked()
    MapMod.buildPath(Maps[State.mapIndex])

    -- Core game state
    State.money = 120
    State.moneyLerp = State.money
    State.lives = 20
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
	Save.load()

	love.window.setFullscreen(Save.data.settings.fullscreen)
	love.window.setTitle("Hydra TD")

	lg.setDefaultFilter("nearest", "nearest")

	Fonts.load()

	Camera.load()

	Sound.load()
	Sound.playMusic("bg")

	lg.setBackgroundColor(colorBg)
	love.math.setRandomSeed(os.time())

	Menu.load()

	if DEV_EXPORT == 1 then
		require("tools.art_export").run()
	end
end

function love.update(dt)
	local target = (State.mode == "pause") and 1 or 0
	State.pauseT = State.pauseT + (target - State.pauseT) * min(1, dt * 14)

	if State.mode == "campaign" then
		State.carouselT = math.min(1, State.carouselT + dt * 7)

		if State.carouselT >= 1 then
			State.carouselDir = 0
		end
	end

	if State.mode ~= "game" then
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

	dt = min(dt, 1 / 30) -- never simulate more than ~33ms
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
	Projectiles.updateProjectiles(dt)
	Floaters.updateFloaters(dt)

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
			--Floaters.addFloater(Constants.SCREEN_W / 2 - 40, Constants.SCREEN_H / 2 - 40, "VICTORY!", colorGood[1], colorGood[2], colorGood[3])

			return
		end

		-- Otherwise continue as normal
		State.inPrep = true
		State.prepTimer = 6.0
		-- Note, move these floaters or signal the message elsewhere. Floaters are for game messaging, not UI messaging
		--Floaters.addFloater(20, 20, "Wave cleared!", colorGood[1], colorGood[2], colorGood[3])
	end
end

function love.draw()
	local sw, sh = lg.getDimensions()

	if State.mode == "game" or State.mode == "pause" then
		Camera.begin()
		Draw.drawWorld()
		Draw.drawUI()
		Camera.finish()

		Camera.present()

		-- Pause overlay on top
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
			lg.setColor(colorText[1], colorText[2], colorText[3], ease)
			lg.printf("PAUSED\n\n[P] Resume\n[R] Restart\n[M] Menu", 0, sh * 0.5 - 70 + drop, sw, "center")
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
	else
		Menu.draw()
	end
end

function love.mousepressed(x, y, button)
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

function love.resize(w, h)
	Camera.resize(w, h)
end