local Theme = require("core.theme")
local Fonts = require("core.fonts")
local Text = require("ui.text")
local Button = require("ui.button")

local lg = love.graphics
local lm = love.mouse
local floor = math.floor
local min = math.min

local TutorialTip = {}

local active = nil
local buttons = {}
local animT = 0

local colorText = Theme.ui.text
local colorBackdrop = Theme.ui.backdrop
local colorOutline = Theme.outline.color
local colorGood = Theme.ui.good or {0.5, 1, 0.5, 1}
local outlineW = Theme.outline.width

local panelW = 420
local panelPad = 18
local btnW = 166
local btnH = 36
local btnGap = 14

local function buildButtons()
	buttons = {}

	if not active then
		return
	end

	local source = active.buttons
	if not source then
		source = {
			{label = active.dismissLabel or "Dismiss", onClick = active.onDismiss},
		}

		if active.onDontShow then
			source[#source + 1] = {label = active.dontShowLabel or "Don't show again", onClick = active.onDontShow}
		end
	end

	for i, def in ipairs(source) do
		buttons[i] = {
			label = def.label,
			w = def.w or btnW,
			h = def.h or btnH,
			onClick = def.onClick,
		}
	end
end

function TutorialTip.show(options)
	active = options
	animT = 0
	buildButtons()
end

function TutorialTip.hide()
	active = nil
	buttons = {}
	animT = 0
end

function TutorialTip.isActive()
	return active ~= nil
end

local function layout()
	local sw, sh = lg.getDimensions()
	local anchor = active and active.anchor or nil
	local x = sw - panelW - 28
	local y = 86

	if anchor == "bottom" then
		y = sh - 196
	elseif anchor == "center" or (active and active.modal) then
		x = floor((sw - panelW) * 0.5)
		y = floor(sh * 0.42 - 96)
	end

	local textW = panelW - panelPad * 2
	Fonts.set("menu")
	local _, bodyLines = lg.getFont():getWrap(active.body or "", textW)
	local bodyH = #bodyLines * lg.getFont():getHeight()
	Fonts.set("title")
	local titleH = lg.getFont():getHeight()
	local buttonH = (#buttons > 0) and (btnH + 16) or 0
	local h = panelPad * 2 + titleH + 12 + bodyH + buttonH

	return x, y, panelW, h
end

local function positionButtons(x, y, w, h)
	local totalW = 0
	for i, btn in ipairs(buttons) do
		totalW = totalW + btn.w
		if i > 1 then
			totalW = totalW + btnGap
		end
	end

	local bx = x + w - panelPad - totalW
	local by = y + h - panelPad - btnH

	for _, btn in ipairs(buttons) do
		btn.x = bx
		btn.y = by
		bx = bx + btn.w + btnGap
	end
end

function TutorialTip.update(dt)
	if not active then
		return
	end

	animT = min(1, animT + dt * 9)

	local x, y, w, h = layout()
	positionButtons(x, y, w, h)

	for _, btn in ipairs(buttons) do
		Button.update(btn, lm.getX(), lm.getY(), dt)
	end
end

function TutorialTip.draw()
	if not active then
		return
	end

	local sw, sh = lg.getDimensions()
	local x, y, w, h = layout()
	local ease = animT * animT * (3 - 2 * animT)
	local dy = (1 - ease) * -10
	local alpha = ease

	if active.modal then
		lg.setColor(0, 0, 0, 0.35 * alpha)
		lg.rectangle("fill", 0, 0, sw, sh)
	end

	y = y + dy
	positionButtons(x, y, w, h)

	lg.setColor(colorOutline[1], colorOutline[2], colorOutline[3], alpha)
	lg.rectangle("fill", x - outlineW, y - outlineW, w + outlineW * 2, h + outlineW * 2, 14, 14)
	lg.setColor(colorBackdrop[1], colorBackdrop[2], colorBackdrop[3], 0.96 * alpha)
	lg.rectangle("fill", x, y, w, h, 12, 12)
	lg.setColor(1, 1, 1, 0.06 * alpha)
	lg.rectangle("fill", x, y, w, 46, 12, 12)

	Fonts.set("title")
	lg.setColor(colorGood[1], colorGood[2], colorGood[3], alpha)
	Text.printShadow(active.title or "", x + panelPad, y + panelPad)

	Fonts.set("menu")
	lg.setColor(colorText[1], colorText[2], colorText[3], alpha)
	Text.printfShadow(active.body or "", x + panelPad, y + panelPad + lg.getFont():getHeight() + 18, w - panelPad * 2, "left")

	for _, btn in ipairs(buttons) do
		Button.draw(btn)
	end
end

local function pointInButton(btn, x, y)
	return btn.x and x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h
end

function TutorialTip.mousepressed(x, y, button)
	if not active then
		return false
	end

	for _, btn in ipairs(buttons) do
		if pointInButton(btn, x, y) then
			return Button.mousepressed(btn, x, y, button)
		end
	end

	return active.modal == true
end

function TutorialTip.mousereleased(x, y, button)
	if not active then
		return false
	end

	for _, btn in ipairs(buttons) do
		if Button.mousereleased(btn, x, y, button) then
			return true
		end
	end

	return active.modal == true
end

return TutorialTip
