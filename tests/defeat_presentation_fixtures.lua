-- Dependency-free defeat vignette fixtures. Run from the repository root with Lua/LuaJIT.
local Presentation = require("ui.defeat_presentation")

local function near(actual, expected)
	return math.abs(actual - expected) < 1e-9
end

local period = 3
local samples = 120
for i = 0, samples do
	local elapsed = period * i / samples
	local alpha = Presentation.vignetteAlpha(elapsed, false)
	assert(alpha >= 0.06 and alpha <= 0.09, "vignette pulse must remain conservatively bounded")
	assert(near(alpha, Presentation.vignetteAlpha(elapsed + period, false)),
		"vignette pulse must repeat seamlessly")
end

local seam = 0.0001
assert(math.abs(Presentation.vignetteAlpha(period - seam, false)
	- Presentation.vignetteAlpha(period + seam, false)) < 0.00001,
	"vignette pulse must remain smooth across its loop seam")

local reduced = Presentation.vignetteAlpha(0, true)
for _, elapsed in ipairs({0.25, 1.5, 3, 30}) do
	assert(near(Presentation.vignetteAlpha(elapsed, true), reduced),
		"reduced motion must use a static vignette")
end

local file = assert(io.open("ui/menu/screens/game_over.lua", "r"))
local source = file:read("*a")
file:close()
local dim = assert(source:find('lg.rectangle("fill", 0, 0, sw, sh)', 1, true))
local vignette = assert(source:find("EdgeVignette.draw", dim, true))
local panel = assert(source:find("-- PANEL TRANSFORM", vignette, true))
assert(dim < vignette and vignette < panel,
	"the vignette must draw after the static dim overlay and before the panel transform")

print("defeat presentation fixtures passed")
