-- Narrow regression fixture for the tower firing animation exporter.
package.path = "./?.lua;./?/init.lua;" .. package.path

local Constants = require("core.constants")
local exportedPaths = {}
local registeredEnemies = 0

love = {
	filesystem = { createDirectory = function() end },
	math = { random = math.random },
	graphics = {
		newCanvas = function()
			return {
				newImageData = function()
					return {
						encode = function(_, _, path)
							exportedPaths[#exportedPaths + 1] = path
						end,
					}
				end,
			}
		end,
		setCanvas = function() end,
		clear = function() end,
		push = function() end,
		translate = function() end,
		scale = function() end,
		pop = function() end,
	},
}

local Towers = { towers = {} }
function Towers.clear() Towers.towers = {} end
function Towers.addTower(kind, x, y)
	Towers.towers[1] = { kind = kind, x = x, y = y, angle = 0, recoil = 0 }
end
function Towers.updateTowers() end

package.loaded["world.towers"] = Towers
package.loaded["world.tower_defs"] = {}
package.loaded["world.enemies"] = { enemies = {} }
package.loaded["world.projectiles"] = {
	clear = function() end,
	spawn = function() end,
	update = function() end,
	draw = function() end,
}
package.loaded["world.effects"] = {
	clear = function() end,
	update = function() end,
	draw = function() end,
}
package.loaded["world.spatial_grid"] = {
	clear = function() end,
	updateEnemy = function() registeredEnemies = registeredEnemies + 1 end,
}
package.loaded["render.draw_entities"] = {
	drawTowerVisual = function() end,
	drawTowerFX = function() end,
}

for _, moduleName in ipairs({
	"core.theme", "world.enemy_defs", "render.draw", "render.draw_world",
	"core.camera", "ui.title",
}) do
	package.loaded[moduleName] = {}
end

local source = assert(io.open("tools/art_export.lua", "r")):read("*a")
local _, definitionCount = source:gsub("function%s+Export%.exportTowerFiringAnimations%s*%(", "")
assert(definitionCount == 1, "exportTowerFiringAnimations must be defined exactly once")

local Export = require("tools.art_export")
Export.exportTowerFiringAnimations()

local expectedFrames = 30
assert(registeredEnemies == #Constants.TOWER_LIST,
	"each tower export must register its target in the spatial grid")
assert(#exportedPaths == #Constants.TOWER_LIST * expectedFrames,
	"each tower must export exactly " .. expectedFrames .. " frames")

for _, kind in ipairs(Constants.TOWER_LIST) do
	local count = 0
	local prefix = "export/anim/" .. kind .. "/frame_"
	for _, path in ipairs(exportedPaths) do
		if path:sub(1, #prefix) == prefix then count = count + 1 end
	end
	assert(count == expectedFrames, kind .. " exported " .. count .. " frames")
end

print("art export firing animation fixtures passed")
