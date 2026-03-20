local Effects = require("world.effects")
local Projectiles = require("world.projectiles")
local DrawWorld = require("render.draw_world")
local DrawEntities = require("render.draw_entities")
local BottomBar = require("ui.bottom_bar")
local BossHealthBar = require("ui.boss_hp")
local DamageMeter = require("ui.damage_meter")
local Floaters = require("ui.floaters")
local Tooltip = require("ui.tooltip")
local Fonts = require("core.fonts")
local Messages = require("ui.messages")

local function drawWorld()
	DrawWorld.drawWorld()
	DrawWorld.drawGrid()

	DrawEntities.drawTowerGhost()
	DrawEntities.drawTowers()
	DrawEntities.drawEnemies()

	Projectiles.draw()
	Effects.draw()
end

local function drawUI()
	Tooltip.hide()

	Fonts.set("ui")

	BottomBar.draw()
	BossHealthBar.draw()
	DamageMeter.draw()
	Messages.draw()

	Fonts.set("floaters")

	Floaters.draw()

	Tooltip.draw()
end

return {
	drawWorld = drawWorld,
	drawUI = drawUI,
}