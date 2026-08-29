local Constants = require("core.constants")
local Hotkeys = require("core.hotkeys")
local Camera = require("core.camera")
local Theme = require("core.theme")
local State = require("core.state")
local Towers = require("world.towers")
local Enemies = require("world.enemies")
local Floaters = require("ui.floaters")
local Waves = require("systems.waves")
local Menu = require("ui.menu.menu")
local BottomBar = require("ui.bottom_bar")
local Button = require("ui.button")
local Sound = require("systems.sound")
local L = require("core.localization")
local ModulePicker = require("ui.module_picker")
local CampaignUnlocks = require("systems.campaign_unlocks")
local GameSpeed = require("core.game_speed")
local DamageMeter = require("ui.damage_meter")

local floor = math.floor

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
end

local function showFloaterAtScreen(x, y, message)
	local wx, wy = Camera.screenToWorld(x, y)
	Floaters.add(wx, wy, message, colorBad[1], colorBad[2], colorBad[3])
end

local function affordabilityMessage(cost)
	return L("floater.placement.insufficientFunds", cost, State.money, math.max(0, cost - State.money))
end

local function releaseShopButton(b, x, y)
	if b.unlocked == false then
		Sound.play("uiBack")
		showFloaterAtScreen(x, y, CampaignUnlocks.getLockMessage(b.kind) or L("floater.cannotPlace"))
		return
	end

	local ok, why = beginTowerPlacement(b.kind)
	if ok then
		Sound.play("uiConfirm")
	elseif why == "locked" then
		Sound.play("uiBack")
		showFloaterAtScreen(x, y, CampaignUnlocks.getLockMessage(b.kind) or L("floater.cannotPlace"))
	end
end

local function releaseInspectButton(b)
	if b.onClick then
		b.onClick()
	end
end

-- The bottom bar is visually split into panels, but all of its buttons obey
-- the same press/release contract. Keeping that routing in one ordered table
-- makes adding a panel a data change instead of another pair of input branches.
local bottomBarGroups = {
	{ buttons = BottomBar.getShopButtons, release = releaseShopButton },
	{ buttons = BottomBar.getInspectButtons, release = releaseInspectButton },
}

local function pressBottomBar(x, y)
	for i = 1, #bottomBarGroups do
		local group = bottomBarGroups[i]
		if Button.pressInList(group.buttons(), x, y) then
			return true
		end
	end

	return false
end

local function releaseBottomBar(x, y)
	for i = 1, #bottomBarGroups do
		local group = bottomBarGroups[i]
		Button.releaseInList(group.buttons(), x, y, group.release)
	end
end

local function showPlacementError(why, kind, wx, wy)
	local failure = Towers.PLACEMENT_FAILURE
	local message
	if why == failure.INSUFFICIENT_FUNDS then
		local def = Towers.TowerDefs[kind]
		local cost = def and def.cost or 0
		message = affordabilityMessage(cost)
	elseif why == failure.ENEMY_PATH then
		message = L("floater.placement.enemyPath")
	elseif why == failure.OCCUPIED_TILE then
		message = L("floater.placement.occupiedTile")
	elseif why == failure.INVALID_TILE then
		message = L("floater.placement.invalidTile")
	elseif why == failure.UNKNOWN_TOWER then
		message = L("floater.placement.unknownTower")
	elseif why == failure.TOWER_LOCKED then
		message = CampaignUnlocks.getLockMessage(kind) or L("floater.placement.towerLocked")
	end
	if message then
		Floaters.add(wx, wy, message, colorBad[1], colorBad[2], colorBad[3])
	end
end

local function placeTower(gx, gy, wx, wy)
	if not gx then
		return
	end

	local kind = State.placing
	local ok, why = Towers.addTower(kind, gx, gy)
	if ok then
		cancelPlacement()
		deselect()
	else
		showPlacementError(why, kind, wx, wy)
	end
end

local function selectWorldEntity(wx, wy)
	local enemy = findEnemyAt(wx, wy)
	if enemy then
		State.selectedEnemy = enemy
		State.selectedTower = nil
		return
	end

	local gx, gy = worldToGrid(wx, wy)
	if State.placing then
		placeTower(gx, gy, wx, wy)
		return
	end

	local tower = gx and Towers.findTowerAt(gx, gy)
	if tower then
		State.selectedTower = tower
		State.selectedEnemy = nil
	else
		deselect()
	end
end

local function pressWorld(x, y, button)
	if button == 2 then
		cancelPlacement()
		deselect()
		return
	end
	if button ~= 1 then
		return
	end

	local wx, wy = Camera.screenToWorld(x, y)
	selectWorldEntity(wx, wy)
end

local function mousepressed(x, y, button)
	if State.mode == "pause" then
		Menu.mousepressedPause(x, y, button)
		return
	end
	if Menu.handlesMode(State.mode) then
		Menu.mousepressed(x, y, button)
		return
	end

	if State.lives <= 0 then
		return
	end

	if button == 1 and State.mode == "game" then
		if DamageMeter.mousepressed(x, y, button) then
			return
		end
		if pressBottomBar(x, y) then
			return
		end
	end

	pressWorld(x, y, button)
end

local function mousereleased(x, y, button)
	if Menu.mousereleased then
		Menu.mousereleased(x, y, button)
	end

	if button ~= 1 or State.mode ~= "game" then
		return
	end
	if DamageMeter.mousereleased(x, y, button) then
		return
	end

	releaseBottomBar(x, y)
end

local gameplayActions = {
	fastForward = function()
		GameSpeed.cycle()
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
}

local function runGameplayAction(action)
	local handler = gameplayActions[action]
	if not handler then
		return false
	end

	handler()
	return true
end

local function handleEscape()
	if State.mode == "pause" then
		-- Resuming intentionally preserves the multiplier selected for this run.
		State.mode = "game"
		Sound.exitPause()
		return true
	end
	if State.mode ~= "game" then
		return false
	end

	if State.placing then
		cancelPlacement()
	elseif State.selectedTower or State.selectedEnemy then
		deselect()
	else
		State.mode = "pause"
		Sound.enterPause()
	end
	return true
end

local function handleGameplayHotkey(key)
	local bindingKind, bindingId = Hotkeys.getBinding(key)
	if bindingKind == "action" then
		return runGameplayAction(bindingId)
	end
	if bindingKind ~= "shop" then
		return false
	end

	if beginTowerPlacement(bindingId) then
		deselect()
	end
	return true
end

local function keypressed(key)
	if key == Hotkeys.getActionKey("escape") and handleEscape() then
		return
	end

	-- Menu screens
	if Menu.handlesMode(State.mode) then
		Menu.keypressed(key)

		return
	end

	handleGameplayHotkey(key)
end

return {
	updateHover = updateHover,
	mousepressed = mousepressed,
	mousereleased = mousereleased,
	keypressed = keypressed,
}
