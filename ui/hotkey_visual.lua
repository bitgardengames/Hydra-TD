local Hotkeys = require("core.hotkeys")
local Text = require("ui.text")
local Theme = require("core.theme")

local HotkeyVisual = {}

local lg = love.graphics
local colorText = Theme.ui.text

-- Draw the configured display label and report the space occupied by that label.
-- Callers remain responsible for any panel-specific padding around it.
function HotkeyVisual.draw(action, x, y)
	local label = Hotkeys.getDisplay(action)

	if not label then
		return 0
	end

	local font = lg.getFont()

	lg.setColor(colorText)
	Text.printShadow(label, x, y)

	return font:getWidth(label)
end

return HotkeyVisual
