-- Dependency-free pause presentation fixtures. Run from the repository root with Lua/LuaJIT.
local Presentation = require("ui.pause_presentation")

local function near(actual, expected)
	return math.abs(actual - expected) < 1e-9
end

local start = Presentation.pose(0, false)
assert(near(start.panelScale, 0.96) and near(start.panelRise, 16), "start panel pose changed")
assert(near(start.contextAlpha, 0) and near(start.contextSlide, 12), "start context pose changed")

local midpoint = Presentation.pose(0.5, false)
assert(near(midpoint.panelScale, 0.98) and near(midpoint.panelRise, 8), "midpoint must use smoothstep")
assert(midpoint.contextAlpha > 0 and midpoint.contextAlpha < 0.5,
	"midpoint context must trail the panel")
assert(midpoint.contextSlide > 6 and midpoint.contextSlide < 12,
	"midpoint context must still be sliding")

local final = Presentation.pose(1, false)
assert(near(final.panelScale, 1) and near(final.panelRise, 0), "final panel pose changed")
assert(near(final.contextAlpha, 1) and near(final.contextSlide, 0), "final context pose changed")

local reduced = Presentation.pose(0, true)
assert(near(reduced.panelScale, 1) and near(reduced.panelRise, 0), "reduced-motion panel must be final")
assert(near(reduced.contextAlpha, 1) and near(reduced.contextSlide, 0),
	"reduced-motion context must be final")

print("pause presentation fixtures passed")
