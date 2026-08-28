local Effects = require("world.effects")
local State = require("core.state")
local Projectiles = require("world.projectiles")
local DrawWorld = require("render.draw_world")
local EnemyRenderer = require("render.enemy_renderer")
local EnemyRenderState = require("render.enemy_render_state")
local TowerRenderer = require("render.tower_renderer")
local BottomBar = require("ui.bottom_bar")
local WavePreview = require("ui.wave_preview")
local BossHealthBar = require("ui.boss_hp")
local DamageMeter = require("ui.damage_meter")
local Floaters = require("ui.floaters")
local Tooltip = require("ui.tooltip")
local Fonts = require("core.fonts")
local Messages = require("ui.messages")
local MapWorldCache = require("world.map_world_cache")

local function drawWorld()
	MapWorldCache.build()
	MapWorldCache.draw()
	DrawWorld.drawAnimatedScatter()

	DrawWorld.drawGrid()
	DrawWorld.drawAbilityPreview()

	TowerRenderer.drawTowerGhost()
	TowerRenderer.drawTowers()
	EnemyRenderState.prepare(nil, nil, State.presentationDt, State.presentationFrameId)
	EnemyRenderer.drawEnemies()
	TowerRenderer.drawSuppressionProjectiles()

	Projectiles.draw()
	Effects.draw()
end

local function drawUI()
	Tooltip.hide()
	Effects.drawOverlay()

	Fonts.set("ui")

	BottomBar.draw()
	WavePreview.draw()
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
