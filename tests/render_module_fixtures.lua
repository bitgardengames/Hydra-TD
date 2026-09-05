-- Regression checks for render preparation ownership and the compatibility facade.
local enemy = {
	x = 20, y = 30, prevX = 10, prevY = 20,
	nudgeX = 2, nudgeY = 4, prevNudgeX = 0, prevNudgeY = 2,
	animT = 8, prevAnimT = 4,
}
package.loaded["core.state"] = { renderAlpha = 0.5 }
package.loaded["world.enemies"] = { enemies = { enemy } }
local state = dofile("render/enemy_render_state.lua")
state.prepare(nil, nil, 1 / 60, 1)
local prepared = { enemy.rx, enemy.ry, enemy.prevRX, enemy.prevRY, enemy.eyeDX, enemy.eyeDY, enemy.rAnimT }

-- A second render pass with the same presentation timestamp must be inert.
state.prepare(nil, 1, 1 / 60, 1)
assert(enemy.rx == prepared[1] and enemy.prevRX == prepared[3] and enemy.eyeDX == prepared[5],
	"same-frame preparation advanced render smoothing twice")

-- Drawing is deliberately not involved in state preparation. Repeated calls to a
-- renderer cannot advance interpolation now that it has no prepare dependency.
local rendererSource = assert(io.open("render/enemy_renderer.lua", "r")):read("*a")
assert(not rendererSource:find("prepareEnemyRenderData", 1, true))
assert(not rendererSource:find("EnemyRenderState.prepare", 1, true))
assert(rendererSource:find("local colorSlow = Theme.projectiles.slow", 1, true))
assert(rendererSource:find("local sr, sg, sb = colorSlow[1], colorSlow[2], colorSlow[3]", 1, true))
local selectionRing = assert(rendererSource:match("%-%- Selection Ring(.-)end"))
assert(selectionRing:find('lg.circle("line", ix, iy, e.radius + 4)', 1, true),
	"selected enemies retain their yellow outline")
assert(not selectionRing:find('lg.circle("fill", ix, iy, e.radius + 4)', 1, true),
	"selected enemies do not receive a yellow fill")
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
