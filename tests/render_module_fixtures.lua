-- Regression checks for render preparation ownership and the compatibility facade.
local enemy = {
	x = 20, y = 30, prevX = 10, prevY = 20,
	nudgeX = 2, nudgeY = 4, prevNudgeX = 0, prevNudgeY = 2,
	animT = 8, prevAnimT = 4,
}
package.loaded["core.state"] = { renderAlpha = 0.5 }
package.loaded["world.enemies"] = { enemies = { enemy } }
local state = dofile("render/enemy_render_state.lua")
state.prepare()
local prepared = { enemy.rx, enemy.ry, enemy.prevRX, enemy.prevRY, enemy.eyeDX, enemy.eyeDY, enemy.rAnimT }

-- Drawing is deliberately not involved in state preparation. Repeated calls to a
-- renderer cannot advance interpolation now that it has no prepare dependency.
local rendererSource = assert(io.open("render/enemy_renderer.lua", "r")):read("*a")
assert(not rendererSource:find("prepareEnemyRenderData", 1, true))
assert(not rendererSource:find("EnemyRenderState.prepare", 1, true))
for i, value in ipairs(prepared) do
	assert(({ enemy.rx, enemy.ry, enemy.prevRX, enemy.prevRY, enemy.eyeDX, enemy.eyeDY, enemy.rAnimT })[i] == value)
end

local enemyAPI = {
	drawEnemy = function() end, drawEnemies = function() end,
	newEnemyPortrait = function() end, drawEnemyPortrait = function() end,
	getEnemyHealthRenderCounters = function() end,
}
local towerAPI = {
	drawTowerBase = function() end, drawTowerCore = function() end,
	drawTowerGhost = function() end, drawTowerVisual = function() end,
	drawTowerFX = function() end, drawTowers = function() end,
	drawSuppressionProjectiles = function() end,
}
package.loaded["render.enemy_renderer"] = enemyAPI
package.loaded["render.tower_renderer"] = towerAPI
local facade = dofile("render/draw_entities.lua")
for name in pairs(enemyAPI) do assert(type(facade[name]) == "function", name .. " missing") end
for name in pairs(towerAPI) do assert(type(facade[name]) == "function", name .. " missing") end
print("render module fixtures passed")
