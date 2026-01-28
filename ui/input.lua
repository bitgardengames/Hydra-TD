local Constants = require("core.constants")
local Hotkeys = require("core.hotkeys")
local Camera = require("core.camera")
local Theme = require("core.theme")
local State = require("core.state")
local Towers = require("world.towers")
local Enemies = require("world.enemies")
local Floaters = require("ui.floaters")
local Waves = require("systems.waves")
local Maps = require("world.map_defs")
local Menu = require("ui.menu.menu")
local Settings = require("ui.menu.screens.settings")
local BottomBar = require("ui.bottom_bar")
local Cursor = require("core.cursor")
local L = require("core.localization")

local lm = love.mouse
local floor = math.floor
local min = math.min

local findEnemyAt = Enemies.findEnemyAt

local colorBad = Theme.ui.bad

local TILE = Constants.TILE

local function worldToGrid(wx, wy)
	if wx < 0 or wy < 0 then
		return nil, nil
	end

	return floor(wx / TILE) + 1, floor(wy / TILE) + 1
end

local function screenToGrid(sx, sy)
	local wx, wy = Camera.screenToWorld(sx, sy)

	return worldToGrid(wx, wy)
end

local function deselect()
	State.selectedTower = nil
	State.selectedEnemy = nil
end

local function cancelPlacement()
	State.placing = nil
end

local function updateHover()
	State.hoverGX, State.hoverGY = screenToGrid(Cursor.x, Cursor.y)
end

local function mousepressed(x, y, button)
	-- Menu screens
	if State.mode == "menu" or State.mode == "campaign" or State.mode == "settings" then
		Menu.mousepressed(x, y, button)

		return
	end

	-- Pause overlay
	if State.paused then
		if Menu.mousepressedPause(x, y, button) then
			return
		end
	end

	if State.lives <= 0 then
		return
	end

	local wx, wy = Camera.screenToWorld(x, y)

	-- Shop UI
	if button == 1 and State.mode == "game" then
		-- Tower shop
		local buttons = BottomBar.getShopButtons()

		if buttons then
			for _, b in ipairs(buttons) do
				if x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h then
					if b.canAfford then
						State.placing = b.kind
						State.selectedTower = nil
						--Sound.play("ui_click")
					else
						--Sound.play("ui_deny")
					end

					return
				end
			end
		end

		-- Inspect panel (upgrade / sell)
		local btns = BottomBar.getBottomBarButtons()

		if btns then
			-- Upgrade
			if btns.upgrade then
				local b = btns.upgrade
				if x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h then
					if State.selectedTower then
						Towers.upgradeTower(State.selectedTower)
						--Sound.play("ui_click")
					end

					return
				end
			end

			-- Sell
			if btns.sell then
				local b = btns.sell
				if x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h then
					if State.selectedTower then
						Towers.sellTower(State.selectedTower)
						--Sound.play("ui_sell")
					end

					return
				end
			end
		end
	end

	-- WORLD INTERACTION
	if button == 1 then
		-- Enemy selection
		local enemy = findEnemyAt(wx, wy)

		if enemy then
			State.selectedEnemy = enemy
			State.selectedTower = nil

			return
		end

		local gx, gy = worldToGrid(wx, wy)

		-- Placement mode
		if State.placing then
			if gx then
				local ok, why = Towers.addTower(State.placing, gx, gy)

				if ok then
					cancelPlacement()
					deselect()
				else
					if why == "path" or why == "occupied" then
						Floaters.add(wx, wy, L("floater.cannotPlace"), colorBad[1], colorBad[2], colorBad[3])
					elseif why == "money" then
						Floaters.add(wx, wy, L("floater.needMoney"), colorBad[1], colorBad[2], colorBad[3])
					end
				end
			end

			return
		end

		-- Tower selection
		if gx then
			local t = Towers.findTowerAt(gx, gy)

			if t then
				State.selectedTower = t
				State.selectedEnemy = nil

				return
			end
		end

		-- Clicked empty ground
		deselect()
	elseif button == 2 then
		-- Right click: cancel placement + deselect
		cancelPlacement()
		deselect()
	end
end

local function mousereleased(x, y, button)
	if Menu.mousereleased then
		Menu.mousereleased(x, y, button)
	end
end

local function keypressed(key)
	-- Menu screens
	if State.mode == "menu" or State.mode == "campaign" or State.mode == "settings" then
		Menu.keypressed(key)
		
		return
	end

	-- Victory / game over
	if State.gameOver and State.victory then
		if key == Hotkeys.actions.endless then
			State.gameOver = false
			State.victory = false
			State.endless = true
			State.inPrep = true
			State.prepTimer = 6.0
			return
		elseif key == Hotkeys.actions.nextMap then
			State.mapIndex = min(State.mapIndex + 1, #Maps)

			State.endless = false
			State.gameOver = false
			State.victory = false
			State.mode = "campaign"
			return
		end
	end

	-- Pause toggle
	if key == Hotkeys.actions.pause then
		State.paused = not State.paused
		
		return
	end

	-- Pause overlay
	if State.paused then
		Menu.keypressed(key)
		
		return
	end

	-- Gameplay hotkeys
	if key == Hotkeys.actions.deselect then
		cancelPlacement()
		deselect()
	elseif key == Hotkeys.shop.lancer then
		State.placing = "lancer"
		deselect()
	elseif key == Hotkeys.shop.slow then
		State.placing = "slow"
		deselect()
	elseif key == Hotkeys.shop.cannon then
		State.placing = "cannon"
		deselect()
	elseif key == Hotkeys.shop.shock then
		State.placing = "shock"
		deselect()
	elseif key == Hotkeys.shop.poison then
		State.placing = "poison"
		deselect()
	elseif key == Hotkeys.actions.fastForward then
		State.speed = (State.speed == 1) and 4 or 1
	elseif key == Hotkeys.actions.skipPrep then
		if State.inPrep then
			State.prepTimer = 0
			Waves.startWave()
		end
	elseif key == Hotkeys.actions.upgrade then
		if State.selectedTower then
			Towers.upgradeTower(State.selectedTower)
		end
	elseif key == Hotkeys.actions.sell then
		if State.selectedTower then
			Towers.sellTower(State.selectedTower)
		end
	elseif key == Hotkeys.actions.toggleMeter then
		State.stats.showDamageMeter = not State.stats.showDamageMeter
	elseif key == Hotkeys.actions.toggleMeterInfo then
		if State.stats.showDamageMeter then
			State.stats.damageView = (State.stats.damageView + 1) % 2
		end
	end
end

return {
	updateHover = updateHover,
	mousepressed = mousepressed,
	mousereleased = mousereleased,
	keypressed = keypressed,
}