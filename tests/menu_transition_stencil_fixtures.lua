-- Dependency-free menu transition regression fixture. Run from the repository root with Lua/LuaJIT.

local file = assert(io.open("ui/menu/menu.lua", "r"))
local menuSource = file:read("*a")
file:close()

assert(menuSource:find("love.graphics.newCanvas(w, h)", 1, true),
	"the transition canvas must only use supported canvas settings")
assert(not menuSource:find("love.graphics.newCanvas(w, h, {stencil = true})", 1, true),
	"stencil must not be passed as a canvas creation setting")
assert(menuSource:find("love.graphics.setCanvas({canvas, stencil = true})", 1, true),
	"the transition render target must request a stencil buffer for stencil-clipped screen effects")

print("menu transition stencil fixtures passed")
