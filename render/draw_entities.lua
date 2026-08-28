-- Compatibility facade for legacy callers. New code should require the focused renderer.
local EnemyRenderer = require("render.enemy_renderer")
local TowerRenderer = require("render.tower_renderer")
local result = {}
for name, fn in pairs(EnemyRenderer) do result[name] = fn end
for name, fn in pairs(TowerRenderer) do result[name] = fn end
return result
