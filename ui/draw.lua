local Effects = require("world.effects")
local Projectiles = require("world.projectiles")
local DrawWorld = require("ui.draw_world")
local DrawEntities = require("ui.draw_entities")
local BottomBar = require("ui.bottom_bar")
local BossHealthBar = require("ui.boss_hp")
local DamageMeter = require("ui.damage_meter")
local Floaters = require("ui.floaters")
local Fonts = require("core.fonts")

local function drawWorld()
	DrawWorld.drawWorld()
	DrawWorld.drawGrid()

	DrawEntities.drawTowerGhost()
	DrawEntities.drawTowers()
	DrawEntities.drawEnemies()
	DrawEntities.drawEnemyOverlays()

	Projectiles.draw()
	Effects.draw()
end

local function drawUI()
	Fonts.set("ui")

	BottomBar.draw()
	BossHealthBar.draw()
	DamageMeter.draw()

	Fonts.set("floaters")

	Floaters.draw()
end

return {
	drawWorld = drawWorld,
	drawUI = drawUI,
}