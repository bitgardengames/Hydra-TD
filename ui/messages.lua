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
end

return Messages
