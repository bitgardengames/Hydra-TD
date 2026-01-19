local Constants = require("core.constants")
local Hotkeys = require("core.hotkeys")
local Camera = require("core.camera")
local Theme = require("core.theme")
local State = require("core.state")
local Towers = require("world.towers")
local Enemies = require("world.enemies")
local Floaters = require("ui.floaters")
local Waves = require("systems.waves")
local Maps = require("world.maps")
local Menu = require("ui.menu")

local lm = love.mouse
local floor = math.floor

local findEnemyAt = Enemies.findEnemyAt

local colorBad = Theme.ui.bad

local function worldToGrid(wx, wy)
	if wx < 0 or wy < 0 then
		return nil, nil
	end

	local worldW = Constants.GRID_W * Constants.TILE
	local worldH = Constants.GRID_H * Constants.TILE

	if wx >= worldW or wy >= worldH then
		return nil, nil
	end

	return floor(wx / Constants.TILE) + 1, floor(wy / Constants.TILE) + 1
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
	local mx, my = lm.getPosition()

	State.hoverGX, State.hoverGY = screenToGrid(mx, my)
end

local function mousepressed(x, y, button)
	if State.mode == "menu" or State.mode == "campaign" or State.mode == "settings" then
		Menu.mousepressed(x, y, button)

		return
	end

	if State.lives <= 0 then
		return
	end

	local wx, wy = Camera.screenToWorld(x, y)

	if button == 1 then
		-- Try enemy selection
		local enemy = findEnemyAt(wx, wy)

		if enemy then
			State.selectedEnemy = enemy
			State.selectedTower = nil

			return
		end

        if wy >= Constants.GRID_H * Constants.TILE then
            deselect()

            return
        end

        local gx, gy = worldToGrid(wx, wy)

		-- Placement mode
		if State.placing then
			if gx then
				local ok, why = Towers.addTower(State.placing, gx, gy)

				if not ok then
					if why == "path" or why == "occupied" then
						Floaters.addFloater(wx, wy, "Can't", colorBad[1], colorBad[2], colorBad[3])
					elseif why == "money" then
						Floaters.addFloater(wx, wy, "Need $", colorBad[1], colorBad[2], colorBad[3])
					end
				end
			end

			return
		end

		-- Try tower selection
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

local function keypressed(key)
	if State.gameOver and State.victory then
		if key == Hotkeys.actions.endless then
			State.gameOver = false
			State.victory = false
			State.endless = true
			State.inPrep = true
			State.prepTimer = 6.0

			return
		elseif key == Hotkeys.actions.nextMap then
			-- Advance campaign
			State.mapIndex = math.min(State.mapIndex + 1, #Maps)

			-- Clear victory state
			State.endless = false
			State.gameOver = false
			State.victory = false

			-- Return to campaign screen
			State.mode = "campaign"

			return
		end
	end

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
	elseif key == Hotkeys.actions.pause then
		State.paused = not State.paused
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
	keypressed = keypressed,
}