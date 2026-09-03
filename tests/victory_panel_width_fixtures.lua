-- Dependency-free source checks for the Victory screen's panel width.
local file = assert(io.open("ui/menu/screens/victory.lua", "r"))
local source = file:read("*a")
file:close()

assert(source:find("local panelW = 820", 1, true),
	"victory backdrop must narrow by 80 pixels so each column narrows by 40 pixels")
assert(source:find("local boxW = min(panelW, sw - edge * 2)", 1, true),
	"victory backdrop must continue to derive its width from the column container")

print("victory panel width fixtures passed")
