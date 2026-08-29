-- Settings descriptions belong in hover tooltips rather than a panel footer.
local file = assert(io.open("ui/menu/screens/settings.lua", "r"))
local source = file:read("*a")
file:close()

assert(source:find('local Tooltip = require("ui.tooltip")', 1, true),
	"settings must use the shared tooltip")
assert(source:find('rows = {{kind = "text", text = describedRow.description}}', 1, true),
	"setting descriptions must be presented as tooltip text")
assert(not source:find('L("settings.sliderKeyboardDesc")', 1, true),
	"volume sliders must not display a Left / Right hint")
assert(not source:find("helpY", 1, true),
	"settings must not reserve a footer for descriptions")

print("settings tooltip fixtures passed")
