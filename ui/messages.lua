local Constants = require("core.constants")
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

local list = {}
local activeTip = nil
local tipRect = nil

local function getBaseY()
	local _, sh = lg.getDimensions()

	return sh - Constants.UI_H - 56
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
	return true
end

function Messages.clearTip(id)
	if activeTip and (not id or activeTip.id == id) then
		activeTip = nil
		tipRect = nil
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
		local font = lg.getFont()
		local label = activeTip.text .. "   " .. activeTip.dismissText
		local w = math.min(sw - 48, font:getWidth(label) + 28)
		local h = font:getHeight() + 16
		local x = (sw - w) * 0.5
		local y = 24
		tipRect = {x = x, y = y, w = w, h = h}
		lg.setColor(0.10, 0.11, 0.15, 0.94)
		lg.rectangle("fill", x, y, w, h, 8)
		lg.setColor(1, 1, 1, 1)
		Text.printfShadow(label, x + 10, y + 8, w - 20, "center")
	end
end

function Messages.mousepressed(x, y, button)
	if button ~= 1 or not activeTip or not tipRect then
		return false
	end
	if x >= tipRect.x and x <= tipRect.x + tipRect.w and y >= tipRect.y and y <= tipRect.y + tipRect.h then
		local callback = activeTip.onDismiss
		activeTip = nil
		tipRect = nil
		if callback then callback() end
		return true
	end
	return false
end

return Messages
