-- Hydra TD: Dec 19 2025, 2:22 AM

local Constants = require("core.constants")
local Camera = require("core.camera")
local Scale = require("core.scale")
local Theme = require("core.theme")
local Sound = require("systems.sound")
local State = require("core.state")
local Save = require("core.save")
local MapMod = require("world.map")
local Maps = require("world.map_defs")
local MapWorldCache = require("world.map_world_cache")
local Enemies = require("world.enemies")
local Spatial = require("world.spatial_grid")
local Towers = require("world.towers")
local Effects = require("world.effects")
local Projectiles = require("world.projectiles")
local Floaters = require("ui.floaters")
local Waves = require("systems.waves")
local Sim = require("core.sim")
local Tooltip = require("ui.tooltip")
local Messages = require("ui.messages")
local Draw = require("render.draw")
local Trees = require("world.scatter_trees")
local Cacti = require("world.scatter_cactus")
local Rocks = require("world.scatter_rocks")
local Mushrooms = require("world.scatter_mushrooms")
local DamageMeter = require("ui.damage_meter")
local BossHealthBar = require("ui.boss_hp")
local BottomBar = require("ui.bottom_bar")
local Input = require("ui.input")
local Difficulty = require("systems.difficulty")
local Achievements = require("systems.achievements")
local Menu = require("ui.menu.menu")
local Overlay = require("ui.overlay")
local Victory = require("ui.menu.screens.victory")
local Steam = require("core.steam")
local L = require("core.localization")
local Modules = require("systems.modules")
local ModulePicker = require("ui.module_picker")
local RunStats = require("systems.run_stats")
local CampaignUnlocks = require("systems.campaign_unlocks")
local CampaignWaveDefs = require("systems.campaign_wave_defs")
local GameSpeed = require("core.game_speed")
local SimulationClock = require("core.simulation_clock")
local DevelopmentCounters = require("core.development_counters")
local GameplayOutcome = require("systems.gameplay_outcome")
local RunModes = require("systems.run_modes")

local lg = love.graphics

local max = math.max
local min = math.min

local colorDim = Theme.ui.screenDim

local cd1, cd2, cd3, cd4 = colorDim[1], colorDim[2], colorDim[3], colorDim[4]

local SCREENSHOT_DIR = "screenshots"
local simulationAccumulator = 0

function resetGame()
	if RunStats.data and not RunStats.final and State.mode == "game" then GameplayOutcome.cancel("restart") end
	simulationAccumulator = 0
	--State.worldMapIndex = 1 -- Map override

    -- Clear world state
    Enemies.clear()
	Spatial.clear()
    Towers.clear()
    Projectiles.clear()
    Effects.clear()
    Floaters.clear()

    -- Map state
    MapMod.clearBlocked()
    MapMod.buildPath(Maps[State.worldMapIndex])

	love.math.setRandomSeed(123456 + State.worldMapIndex * 1009)

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
	RunStats.reset()
	State.runResult = nil
	State.newRecords = {}

    -- Core game state
	State.money = math.floor(diff.startMoney + 0.5)
    State.moneyLerp = State.money
	State.lives = diff.startLives
	State.livesAnim = 0
	State.score = 0
	State.totalKills = 0
	State.spawnedKills = 0
	if RunModes.isEndless(State) and State.buildSeed == nil then
		State.buildSeed = os.time()
	elseif RunModes.isCampaign(State) then
		State.buildSeed = nil
	end
    State.wave = 1
	State.waveLeaks = 0
	State.totalLeaks = 0

	State.modules = {}

    State.inPrep = true
    State.paused = false
	GameSpeed.reset()

    -- Placement / selection
    State.placing = nil
	State.selectedTower = nil
	State.selectedEnemy = nil
	State.equippedAbilities = CampaignUnlocks.getEquippedAbilities()
	State.abilityCharges = {}
	State.abilityTargeting = nil
	require("systems.abilities").reset()
    State.hoverGX = nil
    State.hoverGY = nil

	State.gameOver = false
    State.victory = false
	State.endT = 0
	State.endReady = false
	State.endTitle = nil
	State.endReason = nil
	State.victoryDanceClock = 0
	State.previousCompletionDifficulty = nil
	State.wasFirstClear = false
	State.unlockedTowersThisVictory = {}
	State.unlockedRewardsThisVictory = {}
	State.unlockedAbilitiesThisVictory = {}
    State.activeBoss = nil
	State.activeBossKind = nil

    -- Reset damage stats and cached values
	State.resetDamage()
	DamageMeter.reset()

    -- Waves
    Waves.resetSpawner()

	-- Modules
	Modules.clear()
	State.moduleInventory = {}

	ModulePicker.reset()
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

	-- Ensure OS cursor is always visible during gameplay/UI interactions
	love.mouse.setVisible(true)

	math.randomseed(os.time())
	math.random()

	require("core.environment").load()
	require("core.launcher").run(arg and arg[1], pauseGame)

	collectgarbage("collect")
end

local function isWorldMode(mode)
	return mode == "game" or mode == "pause" or mode == "settings_gameplay" or mode == "game_over" or mode == "victory"
end

local function updateMetaScreens(dt, mode)
	Menu.update(dt)
	Overlay.update(dt)

	if mode == "campaign" then
		State.carouselT = min(1, State.carouselT + dt * 7)

		if State.carouselT >= 1 then
			State.carouselDir = 0
		end
	end
end

local function updateGamePresentation(dt)
	State.renderStep = dt

	State.livesAnim = max(0, State.livesAnim - dt * 2)
	State.waveAnim = max(0, State.waveAnim - dt * 4.5)

	if State.placing then
		State.placingFadeT = min(1, State.placingFadeT + dt * 12)
	else
		State.placingFadeT = 0
	end

	local p = State.placingFadeT
	State.placingFade = p * p * (3 - 2 * p)
end

local function updateGameplayOutcome()
	if State.mode ~= "game" then
		return
	end

	-- These transitions are gameplay, not presentation: resolve them after each
	-- simulation tick so their timing cannot depend on rendered FPS.
	-- Loss condition
	if RunModes.lossCondition(State) and not State.gameOver then
		GameplayOutcome.defeat(L("game.outOfLives"))
		return
	end

	-- If wave is finished, go to prep
	if not State.inPrep and Waves.allEnemiesCleared() then
		local campaignFinalWave = RunModes.hasCampaignVictory(State)
			and CampaignWaveDefs.getFinalWave(Maps[State.mapIndex]) or nil
		local perfectWaveBonus
		if State.waveLeaks == 0 and not (campaignFinalWave and State.wave == campaignFinalWave) then
			perfectWaveBonus = Waves.getWaveCompletionBonus(State.wave, State.waveLeaks)
			State.money = State.money + perfectWaveBonus
		end
		Waves.presentWaveCleared(perfectWaveBonus)
		if campaignFinalWave and State.wave == campaignFinalWave then
			local previousFurthestIndex = Save.data.furthestIndex or 1
			local nextMapIndex = State.worldMapIndex + 1
			Save.data.furthestIndex = max(previousFurthestIndex, nextMapIndex)
			State.unlockedTowersThisVictory = CampaignUnlocks.getNewlyUnlockedTowers(previousFurthestIndex, Save.data.furthestIndex)
			State.unlockedRewardsThisVictory = CampaignUnlocks.getNewRewards(previousFurthestIndex, Save.data.furthestIndex)
			State.unlockedAbilitiesThisVictory = {}
			for _, reward in ipairs(State.unlockedRewardsThisVictory) do
				if reward.type == "ability" then
					State.unlockedAbilitiesThisVictory[#State.unlockedAbilitiesThisVictory + 1] = reward.id
				end
			end

			State.speed = 0.35
			State.gameOver = true
			State.victory = true
			GameplayOutcome.recordCurrentRun(true)

			if State.totalLeaks == 0 then
				local diff = Difficulty.key()
				if diff == "hard" then
					Achievements.unlock("NO_LEAKS_NORMAL")
					Achievements.unlock("NO_LEAKS_HARD")
				elseif diff == "normal" then
					Achievements.unlock("NO_LEAKS_NORMAL")
				end
			end

			Menu.set("victory")
			Sound.play("victory")
			Save.flush()
			return
		end

		State.activeBoss = nil
		State.activeBossKind = nil
		State.wave = State.wave + 1
		State.waveAnim = State.waveAnim + (1 - State.waveAnim) * 0.6
		State.inPrep = true
	end
end

local function drawWorldAndUI()
	Camera.begin()
	Draw.drawWorld()
	Camera.finish()
	Camera.present()

	Draw.drawUI()
	ModulePicker.draw()
	Tooltip.draw()
end

-- What is this name? lol "maybeDoSomething"
function love.update(dt)
	Save.update(dt)
	Camera.update(dt)

	local mode = State.mode
	if mode == "game" and not State.paused then RunStats.update(dt) end
	local target = (mode == "pause" or mode == "settings_gameplay") and 1 or 0

	State.pauseT = State.pauseT + (target - State.pauseT) * min(1, dt * 14)

	Steam.update()
	Sound.update(dt)

	if isWorldMode(mode) then
		BottomBar.update(dt)
		DamageMeter.update(dt)
		BossHealthBar.update(dt)
	end
	ModulePicker.update(dt)

	if mode == "pause" then
		simulationAccumulator = 0
		Menu.updatePause(dt)

		return
	end

	if mode == "settings_gameplay" then
		simulationAccumulator = 0
		Menu.update(dt)

		return
	end

	local gameplayFrozen = ModulePicker.isActive()

	if State.paused or gameplayFrozen then
		simulationAccumulator = 0
		return
	end

	local step = SimulationClock.step
	local catchUpBudget = step * SimulationClock.maxCatchUpSteps
	-- Clamp before stepping: time beyond the catch-up budget is discarded. This
	-- prevents a long OS stall from forcing an effectively unbounded update loop.
	local requestedSimulationTime = simulationAccumulator + dt * State.speed
	if requestedSimulationTime > catchUpBudget then
		DevelopmentCounters.add("discardedSimulationTime", requestedSimulationTime - catchUpBudget)
	end
	simulationAccumulator = min(requestedSimulationTime, catchUpBudget)
	local steps = 0
	while simulationAccumulator + 1e-12 >= step and steps < SimulationClock.maxCatchUpSteps do
		Sim.update(step)
		updateGameplayOutcome()
		simulationAccumulator = simulationAccumulator - step
		steps = steps + 1
	end
	DevelopmentCounters.add("catchUpSteps", steps)
	DevelopmentCounters.add("fixedStepFrames")
	DevelopmentCounters.maximum("maxCatchUpStepsInFrame", steps)
	if steps == SimulationClock.maxCatchUpSteps then
		DevelopmentCounters.add("framesAtCatchUpLimit")
	end
	State.renderAlpha = max(0, min(1, simulationAccumulator / step))

	if mode ~= "game" then
		if mode == "victory" then
			State.victoryDanceClock = (State.victoryDanceClock or 0) + dt
		end
		updateMetaScreens(dt, mode)

		return
	end

	Input.updateHover()

	updateGamePresentation(dt)

	Tooltip.update(dt)
	Messages.update(dt)
	if gameplayFrozen then
		return
	end

end

function love.draw()
	local sw, sh = lg.getDimensions()

	lg.setColor(1, 1, 1)

	if isWorldMode(State.mode) then
		drawWorldAndUI()

		if State.mode == "pause" then
			local t = State.pauseT
			local ease = t * t * (3 - 2 * t)

			-- Dim overlay
			lg.setColor(cd1, cd2, cd3, cd4 * ease)
			lg.rectangle("fill", 0, 0, sw, sh)

			Menu.drawPause()
		end

		if State.mode == "settings_gameplay" then
			Menu.draw()
			Tooltip.draw()
		end

		if State.mode == "game_over" or State.mode == "victory" then
			Menu.draw()
			Overlay.draw()
		end
	else
		Menu.draw()
		Overlay.draw()

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
		ModulePicker.mousepressed(x, y, button)
		return
	end

	if Overlay.isActive() then
		Overlay.mousepressed(x, y, button)
		return
	end

	if State.mode ~= "game" then
		Menu.mousepressed(x, y, button)
		return
	end


	if Messages.mousepressed(x, y, button) then
		return
	end

	Input.mousepressed(x, y, button)
end

function love.wheelmoved(x, y)
	if State.mode ~= "game" and State.mode ~= "pause" then
		Menu.wheelmoved(x, y)
	end
end

function love.mousereleased(x, y, button)
	if ModulePicker.isActive() then return end
	if Overlay.isActive() then
		Overlay.mousereleased(x, y, button)
		return
	end

	if State.mode ~= "game" then
		Menu.mousereleased(x, y, button)
		return
	end

	if Messages.mousereleased(x, y, button) then
		return
	end

	Input.mousereleased(x, y, button)
end

function love.keypressed(key)
	if key == "printscreen" then
		local time = os.date("%Y-%m-%d_%H-%M-%S")

		if not love.filesystem.getInfo(SCREENSHOT_DIR) then
			love.filesystem.createDirectory(SCREENSHOT_DIR)
		end

		lg.captureScreenshot(SCREENSHOT_DIR .. "/screenshot_" .. time .. ".png")
	end

	if ModulePicker.isActive() then
		ModulePicker.keypressed(key)
		return
	end

	if Overlay.isActive() then
		Overlay.keypressed(key)
		return
	end

	if State.mode ~= "game" then
		Menu.keypressed(key)

		return
	end

	Input.keypressed(key)
end

function love.gamepadpressed(joystick, button)
	if State.mode ~= "game" then
		Menu.gamepadpressed(joystick, button)
	end
end

function love.resize(w, h)
	Scale.update()
	Camera.resize()
	MapWorldCache.invalidate()
	require("ui.title").invalidateCache()
	Tooltip.resize(w, h)
	require("ui.bottom_bar").resize(w, h)
	Overlay.resize(w, h)
	Menu.resize(w, h)
end

function love.focus(focused)
	if not focused then -- Alt-tab or focus loss
		pauseGame()
	end
end

function love.visible(visible)
	if not visible then
		pauseGame()
	end
end

function love.quit()
	-- Quitting an active run abandons it; it is not eligible for completed-run
	-- tower history. Already-finalized runs remain untouched.
	if RunStats.data and not RunStats.final and (State.mode == "game" or State.mode == "pause") then
		GameplayOutcome.cancel("quit")
	end
	Save.flush()
	Steam.shutdown()
end
