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
local BottomBar = require("ui.bottom_bar")
local Sound = require("systems.sound")
local L = require("core.localization")
local ModulePicker = require("ui.module_picker")
local Abilities = require("systems.abilities")
local CampaignUnlocks = require("systems.campaign_unlocks")

local getTime = love.timer.getTime
local floor = math.floor
local min = math.min

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

local function beginTowerPlacement(kind)
	if not CampaignUnlocks.isTowerUnlocked(kind) then
		return false, "locked"
	end

	State.placing = kind
	State.selectedTower = nil

	return true
end

local function updateHover()
	State.hoverGX, State.hoverGY = screenToGrid(love.mouse.getPosition())
	if State.abilityTargeting then
		State.abilityTargeting.x, State.abilityTargeting.y = Camera.screenToWorld(love.mouse.getPosition())
	end
end

local function hitButton(list, x, y)
	if not list then
		return nil
	end

	for i = 1, #list do
		local b = list[i]
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

	for i = 1, #list do
		local b = list[i]
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

local function handlePanelButtons(getButtons, x, y, isPress, onReleaseInside)
	return handleButtonPressRelease(getButtons(), x, y, isPress, onReleaseInside)
end

local function rejectAbilityButton(b, x, y)
	Sound.play("uiError")

	if b.anim then
		b.anim.errorT = 1
	end

	local wx, wy = Camera.screenToWorld(x, y)
	Floaters.add(wx, wy, b.lockMessage or L("floater.abilityCoolingDown"), colorBad[1], colorBad[2], colorBad[3])
end

local function tryBeginAbilityTargeting(b, x, y)
	if b.enabled == true then
		Abilities.beginTargeting(b.abilityId)
	else
		rejectAbilityButton(b, x, y)
	end
end

local function mousepressed(x, y, button)
	if State.mode == "pause" then
		if Menu.mousepressedPause(x, y, button) then
			return
		end
	elseif Menu.handlesMode(State.mode) then
		Menu.mousepressed(x, y, button)
		return
	end

	if State.lives <= 0 then
		return
	end

	local wx, wy = Camera.screenToWorld(x, y)

	-- Shop UI
	if button == 1 and State.mode == "game" then
		local abilityButton = handlePanelButtons(BottomBar.getAbilityButtons, x, y, true)
		if abilityButton then
			return
		end
		-- Tower shop
		local shopButton = handlePanelButtons(BottomBar.getShopButtons, x, y, true)

		if shopButton then
			return
		end

		-- Inspect panel (upgrade & sell)
		if handlePanelButtons(BottomBar.getInspectButtons, x, y, true) then
			return
		end
	end

	-- World interaction
	if button == 1 then
		if State.abilityTargeting then
			Abilities.activate(wx, wy)
			return
		end
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
					elseif why == "locked" then
						Floaters.add(wx, wy, CampaignUnlocks.getLockMessage(State.placing) or L("floater.cannotPlace"), colorBad[1], colorBad[2], colorBad[3])
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
		Abilities.cancelTargeting()
	end
end

local function mousereleased(x, y, button)
	if Menu.mousereleased then
		Menu.mousereleased(x, y, button)
	end

	if button ~= 1 or State.mode ~= "game" then
		return
	end

	-- Shop buttons
	handlePanelButtons(BottomBar.getAbilityButtons, x, y, false, function(b)
		tryBeginAbilityTargeting(b, x, y)
	end)

	-- Shop buttons
	handlePanelButtons(BottomBar.getShopButtons, x, y, false, function(b)
		if b.unlocked == false then
			Sound.play("uiBack")

			local wx, wy = Camera.screenToWorld(x, y)
			Floaters.add(wx, wy, CampaignUnlocks.getLockMessage(b.kind) or L("floater.cannotPlace"), colorBad[1], colorBad[2], colorBad[3])

			return
		end

		if b.canAfford ~= true then
			Sound.play("uiBack")

			local wx, wy = Camera.screenToWorld(x, y)
			Floaters.add(wx, wy, L("floater.needMoney"), colorBad[1], colorBad[2], colorBad[3])

			return
		end

		local ok, why = beginTowerPlacement(b.kind)
		if ok then
			Sound.play("uiConfirm")
		elseif why == "locked" then
			Sound.play("uiBack")

			local wx, wy = Camera.screenToWorld(x, y)
			Floaters.add(wx, wy, CampaignUnlocks.getLockMessage(b.kind) or L("floater.cannotPlace"), colorBad[1], colorBad[2], colorBad[3])
		end
	end)

	-- Inspect buttons
	handlePanelButtons(BottomBar.getInspectButtons, x, y, false, function(b)
		if b.onClick then
			b.onClick()
		end
	end)
end

local gameplayActions = {
	fastForward = function()
		State.speed = (State.speed == 1) and 4 or 1
	end,
	skipPrep = function()
		if State.inPrep then
			Waves.startWave()
		end
	end,
	upgrade = function()
		if State.selectedTower then
			ModulePicker.openTowerUpgrade(State.selectedTower)
		end
	end,
	sell = function()
		if State.selectedTower then
			Towers.sellTower(State.selectedTower)
		end
	end,
	toggleMeter = function()
		State.combatStats.showDamageMeter = not State.combatStats.showDamageMeter
	end,
	toggleMeterInfo = function()
		if State.combatStats.showDamageMeter then
			State.combatStats.damageView = (State.combatStats.damageView + 1) % 2
		end
	end,
}

local function runGameplayAction(action)
	local handler = gameplayActions[action]
	if not handler then
		return false
	end

	handler()
	return true
end

local gameplayHotkeyActions = {
	"fastForward",
	"skipPrep",
	"upgrade",
	"sell",
	"toggleMeter",
	"toggleMeterInfo",
}

local function getGameplayHotkeyAction(key)
	for _, action in ipairs(gameplayHotkeyActions) do
		if key == Hotkeys.getActionKey(action) then
			return action
		end
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
			if State.abilityTargeting then
				Abilities.cancelTargeting()
				return
			end
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
	if Menu.handlesMode(State.mode) then
		Menu.keypressed(key)

		return
	end

	-- Victory / game over
	if State.gameOver and State.victory then
		if key == Hotkeys.getActionKey("endless") and CampaignUnlocks.isEndlessUnlocked() then
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
	local towerKind

	for _, kind in ipairs(Constants.TOWER_LIST) do
		if key == Hotkeys.getShopKey(kind) then
			towerKind = kind
			break
		end
	end

	if towerKind then
		if beginTowerPlacement(towerKind) then
			deselect()
		end
	else
		runGameplayAction(getGameplayHotkeyAction(key))
	end
end

return {
	updateHover = updateHover,
	mousepressed = mousepressed,
	mousereleased = mousereleased,
	keypressed = keypressed,
}
