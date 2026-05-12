local Theme = require("core.theme")
local Button = require("ui.button")
local Steam = require("core.steam")
local Fonts = require("core.fonts")
local Text = require("ui.text")
local Overlay = require("ui.overlay")
local L = require("core.localization")

local lg = love.graphics
local floor = math.floor

local Screen = {}

local buttons

local btnW = 260
local btnH = 44
local gap = 22

local colorGood = Theme.ui.good
local colorText = Theme.ui.text
local colorBackdrop = Theme.ui.backdrop
local colorOutline = Theme.outline.color

local outlineW = Theme.outline.width
local baseRadius = 6 * 3
local outerRadius = baseRadius + outlineW * 0.5
local innerRadius = baseRadius - outlineW * 0.25

-- Panel sizing
local boxW = 520
local boxH = 360

function Screen.enter()
	local sw, sh = lg.getDimensions()
	local cx = floor(sw * 0.5)

	local boxY = floor(sh * 0.42 - boxH * 0.5)

	buttons = {
		{
			label = L("overlay.wishlistSteam"),
			w = btnW,
			h = btnH,
			onClick = function()
				Steam.openStorePage(4095520)
				Overlay.hide()
			end
		},

		{
			label = L("overlay.closeButton"),
			w = btnW,
			h = btnH,
			onClick = function()
				Overlay.hide()
			end
		}
	}

	local step = btnH + gap

	-- Button stack height
	local stackH = (#buttons - 1) * step + btnH
	local buttonsStartY = boxY + boxH - stackH - 32

	for i, btn in ipairs(buttons) do
		btn.x = cx - btn.w * 0.5
		btn.y = buttonsStartY + (i - 1) * step
	end
end

function Screen.update(dt)
	for _, btn in ipairs(buttons) do
		local mx, my = love.mouse.getPosition()
		Button.update(btn, mx, my, dt)
	end
end

function Screen.draw()
	local sw, sh = lg.getDimensions()
	local cx = floor(sw * 0.5)

	-- Dim background
	lg.setColor(0, 0, 0, 0.45)
	lg.rectangle("fill", 0, 0, sw, sh)

	local boxX = cx - boxW * 0.5
	local boxY = floor(sh * 0.42 - boxH * 0.5)

	-- Panel outline
	lg.setColor(colorOutline)
	lg.rectangle("fill", boxX - outlineW, boxY - outlineW, boxW + outlineW * 2, boxH + outlineW * 2, outerRadius)

	-- Panel background
	lg.setColor(colorBackdrop)
	lg.rectangle("fill", boxX, boxY, boxW, boxH, innerRadius)

	-- Title
	local titleY = boxY + 32

	Fonts.set("title")
	lg.setColor(colorGood)
	Text.printfShadow(L("overlay.demoCompleteTitle"), boxX, titleY, boxW, "center")

	-- Message
	local textY = titleY + 64

	Fonts.set("menu")
	lg.setColor(colorText)

	Text.printfShadow(L("overlay.demoCompleteText"), boxX, textY, boxW, "center")

	-- Buttons
	for _, btn in ipairs(buttons) do
		Button.draw(btn)
	end
end

function Screen.mousepressed(x, y, b)
	for _, btn in ipairs(buttons) do
		if Button.mousepressed(btn, x, y, b) then
			return true
		end
	end
end

function Screen.mousereleased(x, y, b)
	for _, btn in ipairs(buttons) do
		if Button.mousereleased(btn, x, y, b) then
			return true
		end
	end
end

return Screen