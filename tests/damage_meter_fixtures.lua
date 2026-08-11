-- Dependency-free damage meter behavior fixtures. Run from the repository root.
package.path = "./?.lua;" .. package.path

local drawnText = {}
local sounds = {}

love = {
	graphics = {
		getWidth = function() return 1280 end,
		getFont = function() return {getHeight = function() return 12 end} end,
		setColor = function() end,
		rectangle = function() end,
	},
	mouse = {getPosition = function() return 0, 0 end},
}

local stats = {
	showDamageMeter = true,
	damageView = 0,
	damageByTower = {cannon = 25, lancer = 100, slow = 50},
	totalDamage = 175,
	bossDamageByTower = {},
	bossTotalDamage = 0,
}

package.loaded["core.state"] = {combatStats = stats}
package.loaded["core.localization"] = function(key) return key end
package.loaded["systems.sound"] = {play = function(name) sounds[#sounds + 1] = name end}
package.loaded["world.towers"] = {TowerDefs = {
	cannon = {nameKey = "tower.cannon", color = {1, 1, 1}},
	lancer = {nameKey = "tower.lancer", color = {1, 1, 1}},
	slow = {nameKey = "tower.slow", color = {1, 1, 1}},
}}
package.loaded["ui.text"] = {
	printShadow = function(value) drawnText[#drawnText + 1] = value end,
	printfShadow = function(value) drawnText[#drawnText + 1] = value end,
}

local DamageMeter = require("ui.damage_meter")

DamageMeter.update(1)
DamageMeter.draw()

local positions = {}
for i, value in ipairs(drawnText) do positions[value:match("^(tower%.[^ ]+)") or value] = i end
assert(positions["tower.lancer"] < positions["tower.slow"], "highest damage is drawn first")
assert(positions["tower.slow"] < positions["tower.cannon"], "lowest damage is drawn last")

-- The header is always a two-way selector, even before any boss damage exists.
local headerY = 16 + 12 + 15
local bossTabX = 1280 - 210 - 24 - 16 + 12 + 158
assert(DamageMeter.mousepressed(bossTabX, headerY, 1), "boss tab accepts presses")
assert(DamageMeter.mousereleased(bossTabX, headerY, 1), "boss tab accepts clicks")
assert(stats.damageView == 1, "boss tab changes the damage view")
assert(sounds[#sounds] == "uiConfirm", "tab click confirms with UI feedback")

DamageMeter.update(1)
drawnText = {}
DamageMeter.draw()
assert(drawnText[#drawnText] == "damage.noneBoss", "empty boss view explains that no damage exists")

print("damage meter fixtures passed")
