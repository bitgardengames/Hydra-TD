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
local Sound = require("systems.sound")
local L = require("core.localization")
local ModulePicker = require("ui.module_picker")

local getTime = love.timer.getTime
local floor = math.floor
local min = math.min

local lastPadConfirm = 0
local PAD_CLICK_COOLDOWN = 0.12
local TILE = Constants.TILE

local findEnemyAt = Enemies.findEnemyAt

local colorBad = Theme.ui.bad

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

local function controllerCancel()
	-- Cancel placement first
	if State.placing then
		cancelPlacement()

		return true
	end

	-- Then deselect
	if State.selectedTower or State.selectedEnemy then
		deselect()

		return true
	end

	return false
end

local function updateHover()
	State.hoverGX, State.hoverGY = screenToGrid(Cursor.x, Cursor.y)
end

local function hitButton(list, x, y)
	if not list then
		return nil
	end

	for _, b in ipairs(list) do
		if x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h then
			return b
		end
	end

	return nil
end

local function handleButtonPressRelease(list, x, y, isPress, onReleaseInside)
	if isPress then
		local b = hitButton(list, x, y)
		if b and b.anim then
			b.anim.pressed = true
		end

		return b
	end

	if not list then
		return nil
	end

	for _, b in ipairs(list) do
		if b.anim then
			local wasPressed = b.anim.pressed
			b.anim.pressed = false

			if wasPressed and x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h then
				if onReleaseInside then
					onReleaseInside(b)
				end

				return b
			end
		end
	end

	return nil
end

local function mousepressed(x, y, button)
	-- Menu screens
	if State.mode == "menu" or State.mode == "campaign" or State.mode == "settings" then
		Menu.mousepressed(x, y, button)

		return
	end

	-- Overlay screens
	if State.mode == "game_over" or State.mode == "victory" then
		Menu.mousepressed(x, y, button)

		return
	end

	-- Pause overlay
	if State.mode == "pause" then
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
		local shopButton = handleButtonPressRelease(buttons, x, y, true)

		if shopButton then
			if shopButton.canAfford then
				State.placing = shopButton.kind
				State.selectedTower = nil
				--Sound.play("ui_click")
			else
				--Sound.play("ui_deny")
			end

			return
		end

		-- Inspect panel (upgrade & sell)
		local btns = BottomBar.getInspectButtons()
		if handleButtonPressRelease(btns, x, y, true) then
			return
		end
	end

	-- World interaction
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
	-- Shop buttons
	local buttons = BottomBar.getShopButtons()
	handleButtonPressRelease(buttons, x, y, false, function(b)
		if b.canAfford then
			State.placing = b.kind
			State.selectedTower = nil
		end
	end)

	-- Inspect buttons
	local btns = BottomBar.getInspectButtons()
	handleButtonPressRelease(btns, x, y, false, function(b)
		if b.onClick then
			b.onClick()
		end
	end)

	if Menu.mousereleased then
		Menu.mousereleased(x, y, button)
	end
end

local function keypressed(key)
	-- Toggle pause
	if key == Hotkeys.getActionKey("escape") then
		if State.mode == "pause" then
			State.mode = "game"
			Sound.exitPause()

			return
		elseif State.mode == "game" then
			-- Cancel placement
			if State.placing then
				cancelPlacement()

				return
			end

			-- Deselect
			if State.selectedTower or State.selectedEnemy then
				deselect()

				return
			end

			State.mode = "pause"
			Sound.enterPause()

			return
		end
	end

	-- Menu screens
	if State.mode == "menu" or State.mode == "campaign" or State.mode == "settings" or State.mode == "pause" then
		Menu.keypressed(key)

		return
	end

	-- Victory / game over
	if State.gameOver and State.victory then
		if key == Hotkeys.getActionKey("endless") then
			State.gameOver = false
			State.victory = false
			State.endless = true
			State.inPrep = true

			return
		elseif key == Hotkeys.getActionKey("nextMap") then
			local nextIndex = min(State.worldMapIndex + 1, #Maps)

			State.worldMapIndex = nextIndex
			State.mapIndex = State.resolveMapIndex(nextIndex)

			State.endless = false
			State.gameOver = false
			State.victory = false
			State.mode = "campaign"

			return
		end
	end

	-- Gameplay hotkeys
	if key == Hotkeys.getShopKey("lancer") then
		State.placing = "lancer"
		deselect()
	elseif key == Hotkeys.getShopKey("slow") then
		State.placing = "slow"
		deselect()
	elseif key == Hotkeys.getShopKey("cannon") then
		State.placing = "cannon"
		deselect()
	elseif key == Hotkeys.getShopKey("shock") then
		State.placing = "shock"
		deselect()
	elseif key == Hotkeys.getShopKey("poison") then
		State.placing = "poison"
		deselect()
	elseif key == Hotkeys.getShopKey("plasma") then
		State.placing = "plasma"
		deselect()
	elseif key == Hotkeys.getActionKey("fastForward") then
		State.speed = (State.speed == 1) and 4 or 1
	elseif key == Hotkeys.getActionKey("skipPrep") then
		if State.inPrep then
			Waves.startWave()
		end
	elseif key == Hotkeys.getActionKey("upgrade") then
		if State.selectedTower then
			ModulePicker.openTowerUpgrade(State.selectedTower)
		end
	elseif key == Hotkeys.getActionKey("sell") then
		if State.selectedTower then
			Towers.sellTower(State.selectedTower)
		end
	elseif key == Hotkeys.getActionKey("toggleMeter") then
		State.combatStats.showDamageMeter = not State.combatStats.showDamageMeter
	elseif key == Hotkeys.getActionKey("toggleMeterInfo") then
		if State.combatStats.showDamageMeter then
			State.combatStats.damageView = (State.combatStats.damageView + 1) % 2
		end
	end
end

local function gamepadpressed(joystick, button)
	Cursor.enableVirtual()

	-- Settings screen gets raw D-Pad input (no mouse emulation)
	if State.mode ~= "game" then
		Menu.gamepadpressed(joystick, button)
	end

	-- Shop selection (d-pad > towers)
	local shopKind = Hotkeys.padShopKindFromButton(joystick, button)

	if shopKind and State.mode == "game" then
		State.placing = shopKind
		deselect()

		return
	end

	-- Resolve pad action
	local action = Hotkeys.padActionFromButton(button)

	if not action then
		return
	end

	-- Global actions
	if action == "pause" then
		if State.mode == "pause" then
			State.mode = "game"
			Sound.exitPause()
		elseif State.mode == "game" then
			State.mode = "pause"
			Sound.enterPause()
		end

		return
	end

	-- Menu / overlay screens
	if State.mode ~= "game" then
		if action == "confirm" then
			local now = getTime()

			if now - lastPadConfirm > PAD_CLICK_COOLDOWN then
				mousepressed(Cursor.x, Cursor.y, 1)
				lastPadConfirm = now
			end

			return
		end

		if action == "cancel" or action == "back" then
			mousepressed(Cursor.x, Cursor.y, 2)

			return
		end

		return
	end

	-- Gameplay actions
	if action == "confirm" then
		local now = getTime()

		if now - lastPadConfirm > PAD_CLICK_COOLDOWN then
			mousepressed(Cursor.x, Cursor.y, 1)
			lastPadConfirm = now
		end

		return
	end

	-- Cancel / deselect
	if action == "cancel" or action == "back" then
		controllerCancel()

		return
	end

	-- Fast-forward
	if action == "fastForward" then
		State.speed = (State.speed == 1) and 4 or 1

		return
	end

	-- Skip prep
	if action == "skipPrep" then
		if State.inPrep then
			Waves.startWave()
		end

		return
	end

	-- Upgrade tower
	if action == "upgrade" then
		if State.selectedTower then
			ModulePicker.openTowerUpgrade(State.selectedTower)
		end

		return
	end

	-- Sell tower
	if action == "sell" then
		if State.selectedTower then
			Towers.sellTower(State.selectedTower)
		end

		return
	end

	-- Toggle damage meter
	if action == "toggleMeter" then
		State.combatStats.showDamageMeter = not State.combatStats.showDamageMeter

		return
	end

	-- Toggle damage meter info
	if action == "toggleMeterInfo" then
		if State.combatStats.showDamageMeter then
			State.combatStats.damageView = (State.combatStats.damageView + 1) % 2
		end

		return
	end
end

local function gamepadreleased(joystick, button)
	-- noop
end

return {
	updateHover = updateHover,
	mousepressed = mousepressed,
	mousereleased = mousereleased,
	gamepadpressed = gamepadpressed,
	gamepadreleased  = gamepadreleased,
	keypressed = keypressed,
}
