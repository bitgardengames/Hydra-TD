local Constants = require("core.constants")
local Theme = require("core.theme")
local Sound = require("systems.sound")
local Text = require("ui.text")

local Messages = {}

local lg = love.graphics
local min = math.min

local MAX = 5
local LIFE = 8
local FADE_IN = 0.18
local FADE_OUT = 0.5

local X = 36
local PADDING_X = 8
local PADDING_Y = 4
local GAP = 4
local TIP_MARGIN = 24
local TIP_PADDING_X = 12
local TIP_PADDING_Y = 8
local TIP_GAP = 10
local TIP_DISMISS_PADDING_X = 10
local TIP_DISMISS_PADDING_Y = 4
local TIP_MAX_WIDTH = 760
local TIP_MIN_MESSAGE_WIDTH = 240

local list = {}
local activeTip = nil
local tipRect = nil
local tipDismissRect = nil
local tipDismissPressed = false
local tipDismissHovered = false
local tipLayoutKey = nil

local function getBaseY()
	local _, sh = lg.getDimensions()

	return sh - Constants.UI_H - 56
end

local function pointInRect(px, py, rect)
	return rect and px >= rect.x and px <= rect.x + rect.w and py >= rect.y and py <= rect.y + rect.h
end

local function setColor(color, alpha)
	lg.setColor(color[1], color[2], color[3], alpha or color[4] or 1)
end

local function clearTipState()
	activeTip = nil
	tipRect = nil
	tipDismissRect = nil
	tipDismissPressed = false
	tipDismissHovered = false
	tipLayoutKey = nil
end

local function updateTipLayout(font)
	local sw = lg.getWidth()
	local message = activeTip.text
	local dismissText = activeTip.dismissText
	local dismissW = font:getWidth(dismissText) + TIP_DISMISS_PADDING_X * 2
	local dismissH = font:getHeight() + TIP_DISMISS_PADDING_Y * 2
	local maxW = math.min(TIP_MAX_WIDTH, sw - TIP_MARGIN * 2)
	local innerW = maxW - TIP_PADDING_X * 2
	local inline = innerW - TIP_GAP - dismissW >= TIP_MIN_MESSAGE_WIDTH
	local textAreaW = inline and (innerW - TIP_GAP - dismissW) or innerW
	local wrappedW, lines = font:getWrap(message, textAreaW)
	-- Keep the measured wrapping width when copy wraps; shrinking to the widest
	-- returned line could change the wrap after the rectangle was constructed.
	local messageW = #lines > 1 and textAreaW or math.min(textAreaW, wrappedW)
	local messageH = math.max(1, #lines) * font:getHeight()
	local contentW
	local contentH

	if inline then
		contentW = messageW + TIP_GAP + dismissW
		contentH = math.max(messageH, dismissH)
	else
		contentW = math.max(messageW, dismissW)
		contentH = messageH + TIP_GAP + dismissH
	end

	local w = math.min(maxW, contentW + TIP_PADDING_X * 2)
	local h = contentH + TIP_PADDING_Y * 2
	local x = (sw - w) * 0.5
	local y = 24
	textAreaW = inline and (w - TIP_PADDING_X * 2 - TIP_GAP - dismissW) or (w - TIP_PADDING_X * 2)
	local dismissX = inline and (x + w - TIP_PADDING_X - dismissW) or (x + TIP_PADDING_X)
	local dismissY = inline and (y + TIP_PADDING_Y + (contentH - dismissH) * 0.5)
		or (y + TIP_PADDING_Y + messageH + TIP_GAP)

	tipRect = {x = x, y = y, w = w, h = h, textW = textAreaW}
	tipDismissRect = {x = dismissX, y = dismissY, w = dismissW, h = dismissH}
end

local function removeAt(index)
	for i = index, #list - 1 do
		list[i] = list[i + 1]
	end
	list[#list] = nil
end

function Messages.add(text, r, g, b)
	local h = lg.getFont():getHeight()

	list[#list + 1] = {
		text = text,
		t = 0,
		yOffset = 0,
		targetOffset = 0,
		r = r or 1,
		g = g or 1,
		b = b or 1,
		scale = 0.96, -- subtle pop start
	}

	-- Push older messages
	for i = 1, #list - 1 do
		local m = list[i]
		m.targetOffset = m.targetOffset + (h + GAP)
	end

	if #list > MAX then
		removeAt(1)
	end

	Sound.play("message")
end

-- Contextual tips are deliberately separate from transient messages: there can
-- only ever be one, and the small close target is the only input they consume.
function Messages.showTip(id, text, dismissText, onDismiss)
	if activeTip then
		return false
	end

	activeTip = {id = id, text = text, dismissText = dismissText, onDismiss = onDismiss}
	tipLayoutKey = nil
	return true
end

function Messages.clearTip(id)
	if activeTip and (not id or activeTip.id == id) then
		clearTipState()
	end
end

function Messages.hasTip()
	return activeTip ~= nil
end

function Messages.update(dt)
	for i = #list, 1, -1 do
		local m = list[i]

		m.t = m.t + dt

		local diff = m.targetOffset - m.yOffset
		m.yOffset = m.yOffset + diff * min(1, dt * 16)

		if m.t < 0.25 then
			local t = m.t / 0.25
			t = t * t * (3 - 2 * t)
			m.scale = 0.96 + 0.04 * t
		else
			m.scale = 1
		end

		if m.t > LIFE then
			removeAt(i)
		end
	end
end

function Messages.draw()
	local font = lg.getFont()
	local h = font:getHeight()
	local baseY = getBaseY()

	for i = 1, #list do
		local m = list[i]

		local alpha = 1
		if m.t < FADE_IN then
			alpha = m.t / FADE_IN
		elseif m.t > LIFE - FADE_OUT then
			alpha = (LIFE - m.t) / FADE_OUT
		end

		local ageFactor = (i - 1) / MAX
		local dim = 1 - ageFactor * 0.25
		local yy = baseY - m.yOffset

		local textW = font:getWidth(m.text)
		local w = textW + PADDING_X * 2
		local boxH = h + PADDING_Y * 2

		local cx = X + textW * 0.5
		local cy = yy + h * 0.5

		lg.push()
		lg.translate(cx, cy)
		lg.scale(m.scale, m.scale)
		lg.translate(-cx, -cy)

		lg.setColor(0.125, 0.125, 0.125, 0.75 * alpha * dim)
		lg.rectangle("fill", X - PADDING_X, yy - PADDING_Y, w, boxH, 6)

		lg.setColor(m.r * dim, m.g * dim, m.b * dim, alpha)
		Text.printShadow(m.text, X, yy)

		lg.pop()
	end

	if activeTip then
		local sw = lg.getWidth()
		local message = activeTip.text
		local dismissText = activeTip.dismissText
		local layoutKey = table.concat({sw, lg.getHeight(), tostring(font), message, dismissText}, "\0")
		if layoutKey ~= tipLayoutKey then
			updateTipLayout(font)
			tipLayoutKey = layoutKey
		end
		local x, y, w, h = tipRect.x, tipRect.y, tipRect.w, tipRect.h
		local dismissX, dismissY = tipDismissRect.x, tipDismissRect.y
		local dismissW, dismissH = tipDismissRect.w, tipDismissRect.h

		local mx, my = love.mouse.getPosition()
		local dismissHovered = pointInRect(mx, my, tipDismissRect)
		if dismissHovered and not tipDismissHovered then
			Sound.play("uiMove")
		end
		tipDismissHovered = dismissHovered

		lg.setColor(0.10, 0.11, 0.15, 0.94)
		lg.rectangle("fill", x, y, w, h, 8)
		setColor(Theme.outline.color, 0.85)
		lg.rectangle("line", x, y, w, h, 8)

		local lift = (tipDismissHovered and not tipDismissPressed) and 2 or 0
		local chipY = dismissY - lift
		setColor(tipDismissHovered and Theme.ui.buttonHover or Theme.ui.button, 1)
		lg.rectangle("fill", dismissX, chipY, dismissW, dismissH, 6)
		setColor(tipDismissHovered and Theme.ui.selected or Theme.outline.color, 1)
		lg.rectangle("line", dismissX, chipY, dismissW, dismissH, 6)

		setColor(Theme.ui.text, 1)
		Text.printfShadow(message, x + TIP_PADDING_X, y + TIP_PADDING_Y, tipRect.textW, "left")
		Text.printfShadow(dismissText, dismissX, chipY + TIP_DISMISS_PADDING_Y, dismissW, "center")
	end
end

function Messages.mousepressed(x, y, button)
	if button ~= 1 or not activeTip or not tipDismissRect then
		return false
	end

	if pointInRect(x, y, tipDismissRect) then
		tipDismissPressed = true

		return true
	end

	return pointInRect(x, y, tipRect)
end

function Messages.mousereleased(x, y, button)
	if button ~= 1 or not activeTip then
		return false
	end

	local wasPressed = tipDismissPressed
	tipDismissPressed = false

	if wasPressed and pointInRect(x, y, tipDismissRect) then
		local callback = activeTip.onDismiss
		clearTipState()
		Sound.play("uiConfirm")
		if callback then callback() end

		return true
	end

	return pointInRect(x, y, tipRect)
end

return Messages
