local Theme = require("core.theme")
local Button = require("ui.button")
local Fonts = require("core.fonts")
local Text = require("ui.text")
local Overlay = require("ui.overlay")
local L = require("core.localization")

local Screen, button = {}, nil
local enterAnim = Overlay.newEnterAnimation()

function Screen.enter()
	enterAnim = Overlay.newEnterAnimation()
	local sw, sh = love.graphics.getDimensions()
	button = {label = L("tutorial.continue"), w = 240, h = 44, x = sw * 0.5 - 120, y = sh * 0.5 + 54,
		onClick = function() Overlay.hide() end}
end

function Screen.update(dt)
	Overlay.updateEnterAnimation(enterAnim, dt)
	Button.update(button, love.mouse.getX(), love.mouse.getY(), dt)
end

function Screen.draw()
	local lg = love.graphics
	local sw, sh = lg.getDimensions()
	local w, h = 520, 220
	local x, y = (sw - w) * 0.5, (sh - h) * 0.5
	local cx, cy = x + w * 0.5, y + h * 0.5
	lg.setColor(0, 0, 0, Overlay.dimAlpha(enterAnim, 0.5)); lg.rectangle("fill", 0, 0, sw, sh)
	Overlay.pushPanelTransform(cx, cy, enterAnim)
	lg.setColor(Theme.outline.color); lg.rectangle("fill", x - 3, y - 3, w + 6, h + 6, 18)
	lg.setColor(Theme.ui.backdrop); lg.rectangle("fill", x, y, w, h, 16)
	Fonts.set("title"); lg.setColor(Theme.ui.good)
	Text.printfShadow(L("tutorial.completeTitle"), x + 20, y + 30, w - 40, "center")
	Fonts.set("menu"); lg.setColor(Theme.ui.text)
	Text.printfShadow(L("tutorial.complete"), x + 30, y + 88, w - 60, "center")
	Button.draw(button)
	Overlay.popPanelTransform()
end

function Screen.mousepressed(x, y, mouseButton)
	Button.mousepressed(button, x, y, mouseButton); return true
end
function Screen.mousereleased(x, y, mouseButton)
	Button.mousereleased(button, x, y, mouseButton); return true
end
function Screen.keypressed(key)
	if key == "escape" or key == "return" then Overlay.hide() end
	return true
end

return Screen
