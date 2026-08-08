local Theme = require("core.theme")
local Button = require("ui.button")
local Fonts = require("core.fonts")
local Text = require("ui.text")
local Overlay = require("ui.overlay")
local Steam = require("core.steam")
local L = require("core.localization")

local lg = love.graphics
local floor = math.floor

local Screen = {}

local buttons
local enterAnim = Overlay.newEnterAnimation()

local btnW = 260
local btnH = 44
local gap = 64

local colorGood = Theme.ui.good
local colorText = Theme.ui.text
local colorBackdrop = Theme.ui.backdrop
local colorOutline = Theme.outline.color

local outlineW = Theme.outline.width
local baseRadius = 6 * 3
local outerRadius = baseRadius + outlineW * 0.5
local innerRadius = baseRadius - outlineW * 0.25

function Screen.enter()
	enterAnim = Overlay.newEnterAnimation()
	local sw, sh = lg.getDimensions()
	local cx = floor(sw * 0.5)

	-- Panel layout
	local boxH = 260
	local boxY = floor(sh * 0.42 - boxH * 0.5)

	local startY = boxY + 150

	buttons = {
		{
			label = L("overlay.reviewButton"),
			w = btnW,
			h = btnH,
			onClick = function()
				--[[if Steam.openReview then
					Steam.openReview()
				end]]

				Overlay.hide()
			end
		},

		{
			label = L("overlay.continue"),
			w = btnW,
			h = btnH,
			onClick = function()
				Overlay.hide()
			end
		},
	}

	for i, btn in ipairs(buttons) do
		btn.x = cx - btn.w * 0.5
		btn.y = startY + (i - 1) * gap
	end
end

function Screen.update(dt)
	Overlay.updateEnterAnimation(enterAnim, dt)
	Button.updateList(buttons, dt)
end

function Screen.draw()
	local sw, sh = lg.getDimensions()
	local cx = floor(sw * 0.5)

	-- Dim background
	lg.setColor(0, 0, 0, Overlay.dimAlpha(enterAnim, 0.45))
	lg.rectangle("fill", 0, 0, sw, sh)

	-- Panel layout
	local boxW = 520
	local boxH = 260
	local boxX = cx - boxW * 0.5
	local boxY = floor(sh * 0.42 - boxH * 0.5)
	local boxCX, boxCY = boxX + boxW * 0.5, boxY + boxH * 0.5

	Overlay.pushPanelTransform(boxCX, boxCY, enterAnim)

	-- Panel outline
	lg.setColor(colorOutline)
	lg.rectangle("fill", boxX - outlineW, boxY - outlineW, boxW + outlineW * 2, boxH + outlineW * 2, outerRadius)

	-- Panel background
	lg.setColor(colorBackdrop)
	lg.rectangle("fill", boxX, boxY, boxW, boxH, innerRadius)

	-- Title
	local titleY = boxY + 26

	Fonts.set("title")

	lg.setColor(colorGood)
	Text.printfShadow(L("overlay.reviewTitle"), boxX, titleY, boxW, "center")

	-- Message
	local textY = titleY + 56

	Fonts.set("menu")

	lg.setColor(colorText)

	Text.printfShadow(L("overlay.reviewText"), boxX, textY, boxW, "center")

	-- Buttons
	Button.drawList(buttons)

	Overlay.popPanelTransform()
end

function Screen.mousepressed(x, y, button)
	return Button.mousepressedList(buttons, x, y, button)
end

function Screen.mousereleased(x, y, button)
	return Button.mousereleasedList(buttons, x, y, button)
end

function Screen.keypressed(key)
	if key == "escape" then
		Overlay.hide()
		return true
	end
end

return Screen
