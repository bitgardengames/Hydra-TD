local Theme = require("core.theme")
local Button = require("ui.button")
local Fonts = require("core.fonts")
local Text = require("ui.text")
local Overlay = require("ui.overlay")
local L = require("core.localization")

local Screen = {}
local buttons = {}

function Screen.enter()
	local sw, sh = love.graphics.getDimensions()
	local x, y = sw * 0.5, sh * 0.5
	buttons = {
		{label = L("tutorial.start"), w = 280, h = 44, x = x - 140, y = y + 42,
			onClick = function() Overlay.hide(); require("systems.onboarding").startTutorial() end},
		{label = L("tutorial.skip"), w = 280, h = 44, x = x - 140, y = y + 102,
			onClick = function() Overlay.hide(); require("systems.onboarding").skip() end},
	}
end

function Screen.update(dt)
	local mx, my = love.mouse.getPosition()
	for _, button in ipairs(buttons) do Button.update(button, mx, my, dt) end
end

function Screen.draw()
	local lg = love.graphics
	local sw, sh = lg.getDimensions()
	local w, h = 560, 290
	local x, y = (sw - w) * 0.5, (sh - h) * 0.5
	lg.setColor(0, 0, 0, 0.55); lg.rectangle("fill", 0, 0, sw, sh)
	lg.setColor(Theme.outline.color); lg.rectangle("fill", x - 3, y - 3, w + 6, h + 6, 18)
	lg.setColor(Theme.ui.backdrop); lg.rectangle("fill", x, y, w, h, 16)
	Fonts.set("title"); lg.setColor(Theme.ui.text)
	Text.printfShadow(L("tutorial.offerTitle"), x + 24, y + 28, w - 48, "center")
	Fonts.set("menu")
	Text.printfShadow(L("tutorial.offerText"), x + 42, y + 88, w - 84, "center")
	for _, button in ipairs(buttons) do Button.draw(button) end
end

function Screen.mousepressed(x, y, button)
	for _, b in ipairs(buttons) do if Button.mousepressed(b, x, y, button) then return true end end
	return true
end

function Screen.mousereleased(x, y, button)
	for _, b in ipairs(buttons) do if Button.mousereleased(b, x, y, button) then return true end end
	return true
end

function Screen.keypressed(key)
	if key == "escape" then Overlay.hide(); require("systems.onboarding").skip(); return true end
	return true
end

return Screen
