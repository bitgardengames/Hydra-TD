local Presentation = require("ui.main_menu_presentation")

local start = Presentation.pose(0, 1, false)
assert(start.titleAlpha == 0 and start.panelAlpha == 0 and start.buttonAlpha == 0,
	"the full entrance must begin hidden")
assert(start.titleLift == 7 and start.panelLift == 5 and start.buttonLift == 6,
	"entrance elements must use only a small vertical lift")

local titleFirst = Presentation.pose(0.06, 1, false)
assert(titleFirst.titleAlpha > 0 and titleFirst.panelAlpha == 0 and titleFirst.buttonAlpha == 0,
	"the title must reveal first")

local panelSecond = Presentation.pose(0.14, 1, false)
assert(panelSecond.panelAlpha > 0 and panelSecond.buttonAlpha == 0,
	"the panel must precede the buttons")

local firstButton = Presentation.pose(0.28, 1, false)
local secondButton = Presentation.pose(0.28, 2, false)
assert(firstButton.buttonAlpha > secondButton.buttonAlpha,
	"buttons must reveal with a small stagger")
assert(not Presentation.pose(0.22, 1, false).buttonPointerReady,
	"buttons must reject pointer input early in their reveal")
assert(Presentation.pose(0.38, 1, false).buttonPointerReady,
	"buttons must accept pointer input once substantially visible")

local reduced = Presentation.pose(0, 4, true)
assert(reduced.titleAlpha == 1 and reduced.panelAlpha == 1 and reduced.buttonAlpha == 1,
	"reduced motion must present the complete menu immediately")
assert(reduced.titleLift == 0 and reduced.panelLift == 0 and reduced.buttonLift == 0,
	"reduced motion must remove all entrance lift")
assert(reduced.buttonPointerReady, "reduced motion buttons must be immediately interactive")

print("main menu presentation fixtures passed")
