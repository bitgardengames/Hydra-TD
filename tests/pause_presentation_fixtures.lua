-- Dependency-free pause presentation fixtures. Run from the repository root with Lua/LuaJIT.
local Presentation = require("ui.pause_presentation")

local function near(actual, expected)
	return math.abs(actual - expected) < 1e-9
end

local start = Presentation.pose(0, false)
assert(start.panelScale == nil and start.panelRise == nil,
	"the pause backdrop and buttons must not expose an animated pose")
assert(near(start.contextAlpha, 0) and near(start.contextSlide, 12), "start context pose changed")

local midpoint = Presentation.pose(0.5, false)
assert(midpoint.contextAlpha > 0 and midpoint.contextAlpha < 0.5,
	"midpoint context must trail the panel")
assert(midpoint.contextSlide > 6 and midpoint.contextSlide < 12,
	"midpoint context must still be sliding")

local final = Presentation.pose(1, false)
assert(near(final.contextAlpha, 1) and near(final.contextSlide, 0), "final context pose changed")

local reduced = Presentation.pose(0, true)
assert(near(reduced.contextAlpha, 1) and near(reduced.contextSlide, 0),
	"reduced-motion context must be final")

print("pause presentation fixtures passed")
