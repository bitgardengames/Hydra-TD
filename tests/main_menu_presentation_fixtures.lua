local Presentation = require("ui.main_menu_presentation")

local start = Presentation.pose(0, false)
assert(start.titleAlpha == 0 and start.titleLift == 7,
	"the title entrance must begin hidden and slightly lifted")
assert(start.panelAlpha == nil and start.panelLift == nil,
	"the button backdrop must not expose an animated pose")
assert(start.buttonAlpha == nil and start.buttonLift == nil and start.buttonPointerReady == nil,
	"buttons must not expose presentation animation or delayed input state")

local titleFirst = Presentation.pose(0.06, false)
assert(titleFirst.titleAlpha > 0, "the title must reveal")

local reduced = Presentation.pose(0, true)
assert(reduced.titleAlpha == 1 and reduced.titleLift == 0,
	"reduced motion must present the title immediately")

print("main menu presentation fixtures passed")
