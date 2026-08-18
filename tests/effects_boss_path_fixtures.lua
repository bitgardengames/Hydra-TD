-- Dependency-free boss presentation fixtures. Run from the repository root
-- with Lua/LuaJIT.
package.path = "./?.lua;./?/init.lua;" .. package.path

package.loaded["systems.sound"] = {}
package.loaded["core.save"] = {data = {settings = {highDensityParticles = true}}}
package.loaded["core.camera"] = {}

love = {
	graphics = {},
	math = {random = function() return 0.25 end},
}

local Effects = require("world.effects")
local path = {{0, 0}, {32, 0}, {64, 32}}

Effects.presentationEvent("boss_incoming", {path = path})
assert(Effects.presentation[1].path == path, "boss incoming cue starts with its path highlight")

Effects.presentationEvent("boss_spawn", {x = 0, y = 0})
assert(Effects.presentation[1].path == nil, "boss spawn removes the incoming path highlight")
assert(Effects.presentation[1].kind == "boss_incoming",
	"boss spawn preserves the incoming cue for non-path presentation")
assert(Effects.presentation[2].kind == "boss_spawn", "boss spawn still creates its own presentation cue")

print("effects boss path fixtures passed")
