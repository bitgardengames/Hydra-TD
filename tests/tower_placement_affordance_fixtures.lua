-- Dependency-free input fixtures. Run from the repository root with Lua/LuaJIT.
package.path = "./?.lua;" .. package.path

local state = {
	mode = "game",
	lives = 10,
	money = 25,
	placing = nil,
	selectedTower = nil,
	selectedEnemy = nil,
}
local floaters = {}
local shopButton = {kind = "basic", cost = 100, canAfford = false, unlocked = true}

love = {mouse = {getPosition = function() return 40, 50 end}}

package.loaded["core.constants"] = {TILE = 32}
package.loaded["core.hotkeys"] = {getBinding = function() return nil end, getActionKey = function() return "escape" end}
package.loaded["core.camera"] = {
	screenToWorld = function(x, y) return x, y end,
}
package.loaded["core.theme"] = {ui = {bad = {1, 0, 0}}}
package.loaded["core.state"] = state
package.loaded["world.towers"] = {
	TowerDefs = {basic = {cost = 100}},
	PLACEMENT_FAILURE = {INSUFFICIENT_FUNDS = "insufficient_funds"},
	addTower = function()
		return false, "insufficient_funds"
	end,
	findTowerAt = function() return nil end,
}
package.loaded["world.enemies"] = {findEnemyAt = function() return nil end}
package.loaded["ui.floaters"] = {
	add = function(x, y, message)
		floaters[#floaters + 1] = {x = x, y = y, message = message}
	end,
}
package.loaded["systems.waves"] = {startWave = function() end}
package.loaded["ui.menu.menu"] = {
	handlesMode = function() return false end,
	mousereleased = function() end,
}
package.loaded["ui.bottom_bar"] = {
	getAbilityButtons = function() return {} end,
	getShopButtons = function() return {shopButton} end,
	getInspectButtons = function() return {} end,
}
package.loaded["ui.button"] = {
	pressInList = function() return false end,
	releaseInList = function(buttons, x, y, callback)
		for _, button in ipairs(buttons) do callback(button, x, y) end
	end,
}
package.loaded["systems.sound"] = {play = function() end, enterPause = function() end, exitPause = function() end}
package.loaded["core.localization"] = function(key, cost, money, shortfall)
	if key == "floater.placement.insufficientFunds" then
		return ("cost=%d money=%d shortfall=%d"):format(cost, money, shortfall)
	end
	return key
end
package.loaded["ui.module_picker"] = {openTowerUpgrade = function() end}
package.loaded["systems.abilities"] = {cancelTargeting = function() end, beginTargeting = function() end}
package.loaded["systems.campaign_unlocks"] = {isTowerUnlocked = function() return true end}
package.loaded["core.game_speed"] = {cycle = function() end}
package.loaded["ui.damage_meter"] = {mousepressed = function() return false end, mousereleased = function() return false end}

local Input = require("ui.input")

Input.mousereleased(10, 20, 1)
assert(state.placing == "basic", "selecting an unaffordable tower did not enter placement mode")
assert(#floaters == 0, "selecting an unaffordable tower displayed an affordability floater")

Input.mousepressed(64, 96, 1)
assert(#floaters == 1, "attempting the unaffordable placement did not display a floater")
assert(floaters[1].message == "cost=100 money=25 shortfall=75", "placement displayed the wrong affordability message")

print("tower placement affordance fixtures passed")
