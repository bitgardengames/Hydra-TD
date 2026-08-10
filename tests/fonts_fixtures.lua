-- Dependency-free font selection fixtures. Run from the repository root with Lua/LuaJIT.
package.path = "./?.lua;" .. package.path

local Fonts = require("core.fonts")
local ui = {}
local menu = {}

Fonts.ui = ui
Fonts.menu = menu

-- Explicit retrieval must not depend on the font most recently selected for drawing.
love = {graphics = {setFont = function() end}}
Fonts.set("ui")
assert(Fonts.get("menu") == menu, "explicit retrieval ignored the requested font")

-- Existing callers may omit the kind to retrieve the current drawing font.
assert(Fonts.get() == ui, "no-argument retrieval did not return the current font")
Fonts.set("menu")
assert(Fonts.get() == menu, "no-argument retrieval did not follow the current font")

print("font selection fixtures passed")
