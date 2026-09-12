local source = debug.getinfo(1, "S").source:sub(2)
local root = source:match("^(.*[/\\])tests[/\\]") or "./"
package.path = root .. "?.lua;" .. root .. "?/init.lua;" .. package.path

package.loaded["core.camera"] = {wx = 100, wy = 50, wscale = 2}
package.loaded["core.constants"] = {TILE = 64, GRID_W = 32, GRID_H = 14}
package.loaded["core.state"] = {worldMapIndex = 3, wave = 17, waveTime = 20.04}
package.loaded["world.towers"] = {towers = {
	{kind = "cannon", gx = 12, gy = 9, level = 3},
	{kind = "slow", gx = 13, gy = 9, level = 4},
}}

love = {
	graphics = {getDimensions = function() return 1920, 1080 end},
	system = {setClipboardText = function(text) love.clipboard = text end},
}

local SceneExport = require("core.scene_export")
local exported = SceneExport.copy()

assert(exported:find("\t\tduration = 14,", 1, true), "default scene duration was not exported")
assert(exported:find("\t\tmap = 3,", 1, true), "current map was not exported")
assert(exported:find('{kind = "cannon", gx = 12, gy = 9, level = 3},', 1, true),
	"tower placement and level were not exported")
assert(exported:find("\t\twave = 17,", 1, true), "current wave was not exported")
assert(exported:find("\t\twarmup = 20.0,", 1, true), "current wave time was not exported")
assert(exported:find("camera = {gx = 16, gy = 7, ox = -476, oy = -160, zoom = 2.0}", 1, true),
	"current camera framing was not exported")
assert(love.clipboard == exported, "scene was not copied to the clipboard")

print("scene export fixtures passed")
