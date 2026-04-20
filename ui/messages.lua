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

local pool = {}
local list = {}

local font, fontH

local function getFont()
	if font ~= lg.getFont() then
		font = lg.getFont()
		fontH = font:getHeight()
	end

	return font, fontH
end

local function getBaseY()
	local _, sh = lg.getDimensions()

	return sh - Constants.UI_H - 56
end

local function alloc()
	return table.remove(pool) or {
		text = "",
		t = 0,
		yOffset = 0,
		targetOffset = 0,
		r = 1, g = 1, b = 1,
		scale = 1,
	}
end

local function free(m)
	m.text = ""
	m.t = 0
	m.yOffset = 0
	m.targetOffset = 0
	m.scale = 1
	pool[#pool + 1] = m
end

function Messages.add(text, r, g, b)
	local _, h = getFont()

	local m = alloc()
	m.text = text
	m.t = 0
	m.yOffset = 0
	m.targetOffset = 0
	m.r = r or 1
	m.g = g or 1
	m.b = b or 1
	m.scale = 0.96 -- subtle pop start

	list[#list + 1] = m

	-- Push older messages
	for i = 1, #list - 1 do
		local o = list[i]
		o.targetOffset = o.targetOffset + (h + GAP)
	end

	-- Trim oldest
	if #list > MAX then
		local old = list[1]

		for i = 1, #list - 1 do
			list[i] = list[i + 1]
		end
		list[#list] = nil

		free(old)
	end

	Sound.play("message")
end

function Messages.update(dt)
	for i = #list, 1, -1 do
		local m = list[i]

		m.t = m.t + dt

		-- Better push easing (snappy then settle)
		local diff = m.targetOffset - m.yOffset
		m.yOffset = m.yOffset + diff * min(1, dt * 16)

		-- Scale pop (ease out)
		if m.t < 0.25 then
			local t = m.t / 0.25
			t = t * t * (3 - 2 * t) -- smoothstep
			m.scale = 0.96 + 0.04 * t
		else
			m.scale = 1
		end

		if m.t > LIFE then
			free(m)

			for j = i, #list - 1 do
				list[j] = list[j + 1]
			end
			list[#list] = nil
		end
	end
end

function Messages.draw()
	local font, h = getFont()
	local baseY = getBaseY()

	for i = 1, #list do
		local m = list[i]

		local alpha = 1

		if m.t < FADE_IN then
			alpha = m.t / FADE_IN
		end

		if m.t > LIFE - FADE_OUT then
			alpha = (LIFE - m.t) / FADE_OUT
		end

		local ageFactor = (i - 1) / MAX
		local dim = 1 - ageFactor * 0.25

		local yy = baseY - m.yOffset

		local textW = font:getWidth(m.text)
		local w = textW + PADDING_X * 2
		local boxH = h + PADDING_Y * 2

		local sx = m.scale
		local sy = m.scale

		local cx = X + textW * 0.5
		local cy = yy + h * 0.5

		lg.push()
		lg.translate(cx, cy)
		lg.scale(sx, sy)
		lg.translate(-cx, -cy)

		-- Backdrop
		lg.setColor(0.125, 0.125, 0.125, 0.75 * alpha * dim)
		lg.rectangle("fill", X - PADDING_X, yy - PADDING_Y, w, boxH, 6)

		-- Text
		lg.setColor(m.r * dim, m.g * dim, m.b * dim, alpha)
		Text.printShadow(m.text, X, yy)

		lg.pop()
	end
end

return Messages
