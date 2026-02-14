local Theme = require("core.theme")
local Fonts = require("core.fonts")
local Text = require("ui.text")
local Glyphs = require("ui.glyphs")

local lg = love.graphics

local font = Fonts.ui
local colorText = Theme.ui.text

local PS_SYMBOL_SCALE = 0.45
local BUTTON_RADIUS = 0.50

local xboxColors = {
	a = {0.36, 0.78, 0.36},
	b = {0.86, 0.36, 0.36},
	x = {0.36, 0.56, 0.86},
	y = {0.86, 0.78, 0.36},
}

local psColors = {
	triangle = {0.42, 0.89, 0.87},
	square = {0.97, 0.62, 0.78},
	circle = {0.97, 0.37, 0.40},
	cross = {0.46, 0.49, 0.88},
}

-- Helpers
local function drawWithShadow(drawFn)
	shadowColor = Theme.ui.shadow

	lg.push()
	lg.translate(1, 1)
	lg.setColor(shadowColor)

	drawFn()

	lg.pop()
end

local function drawKeycap(w, h, r)
	lg.setColor(Theme.ui.button)
	lg.rectangle("fill", 0, 0, w, h, r, r)
end

local function drawCircle(cx, cy, r)
	lg.setColor(Theme.ui.button)
	lg.circle("fill", cx, cy, r)
end

local function drawCenteredLabel(text, w, h, font, yBias)
	lg.setFont(font)

	local y = (h - font:getHeight()) * 0.5 + 1 + (yBias or 0)

	Text.printfShadow(text, 0, y, w, "center")
end

local function drawArrow(w, h, rotation)
	local side = h * 0.5
	local triH = side * math.sqrt(3) * 0.5
	local cxOffset = triH / 3

	lg.push()
	lg.translate(w * 0.5, h * 0.5)
	lg.rotate(rotation or 0)

	lg.polygon("fill", triH - cxOffset, 0, -cxOffset, -side * 0.5, -cxOffset,  side * 0.5)

	lg.pop()
end

-- Gamepad face buttons
local function registerFace(id, label, color, xoffset)
	Glyphs.register(id, function(w, h)
		local r = h * BUTTON_RADIUS
		drawCircle(w * 0.5, h * 0.5, r)

		lg.setColor(color)
		drawCenteredLabel(label, w + (xoffset or 0), h, font, -1)
	end)
end

registerFace("pad_a", "A", xboxColors.a)
registerFace("pad_b", "B", xboxColors.b, 1)
registerFace("pad_x", "X", xboxColors.x)
registerFace("pad_y", "Y", xboxColors.y)

-- Playstation shapes
local function registerPS(id, drawSymbol, color)
	Glyphs.register(id, function(w, h)
		local r = h * BUTTON_RADIUS
		drawCircle(w * 0.5, h * 0.5, r)

		lg.setLineWidth(2)

		drawWithShadow(function()
			drawSymbol(w, h, r * PS_SYMBOL_SCALE)
		end)

		lg.setColor(color)
		drawSymbol(w, h, r * PS_SYMBOL_SCALE)
	end)
end

local function psCross(w, h, s)
	local cx, cy = w * 0.5, h * 0.5
	local half = s * 0.88

	lg.line(cx - half, cy - half, cx + half, cy + half)
	lg.line(cx - half, cy + half, cx + half, cy - half)
end

local function psCircle(w, h, r)
	lg.circle("line", w * 0.5, h * 0.5, r)
end

local function psSquare(w, h, s)
	lg.rectangle("line", w * 0.5 - s, h * 0.5 - s, s * 2, s * 2)
end

local function psTriangle(w, h, s)
	local cx, cy = w * 0.5, h * 0.5

	lg.polygon("line", cx, cy - s, cx - s, cy + s * 0.85, cx + s, cy + s * 0.85)
end

registerPS("ps_cross", psCross, psColors.cross)
registerPS("ps_circle", psCircle, psColors.circle)
registerPS("ps_square", psSquare, psColors.square)
registerPS("ps_triangle", psTriangle, psColors.triangle)

-- D-Pad
local function registerDpad(id, rotation, yOffset)
	yOffset = yOffset or 0

	Glyphs.register(id, function(w, h)
		local r = h * BUTTON_RADIUS

		drawCircle(w * 0.5, h * 0.5, r)

		drawWithShadow(function()
			lg.push()
			lg.translate(0, yOffset)

			drawArrow(w, h, rotation)

			lg.pop()
		end)

		lg.setColor(colorText)
		lg.push()
		lg.translate(0, yOffset)

		drawArrow(w, h, rotation)

		lg.pop()
	end)
end

registerDpad("dpad_right", 0)
registerDpad("dpad_down", math.pi * 0.5, -1)
registerDpad("dpad_left", math.pi)
registerDpad("dpad_up", -math.pi * 0.5, 1)

-- Bumpers / triggers
Glyphs.register("pad_lb", function(w, h)
	local r = h * BUTTON_RADIUS

	drawKeycap(w, h, r)

	lg.setColor(colorText)
	drawCenteredLabel("LB", w + 1, h, font)
end)

Glyphs.register("pad_rb", function(w, h)
	local r = h * BUTTON_RADIUS

	drawKeycap(w, h, r)

	lg.setColor(colorText)
	drawCenteredLabel("RB", w + 1, h, font)
end)

-- Stick buttons
local function registerStick(id, label)
	Glyphs.register(id, function(w, h)
		local r  = h * BUTTON_RADIUS
		local cx = w * 0.5
		local cy = h * 0.5

		-- Filled button
		lg.setColor(Theme.ui.button)
		lg.circle("fill", cx, cy, r)

		-- Label
		lg.setColor(colorText)
		lg.setFont(font)

		local y = (h - font:getHeight()) * 0.5 + 1

		Text.printfShadow(label, 1, y, w, "center")
	end)
end

registerStick("pad_l3", "L3")
registerStick("pad_r3", "R3")

-- Keyboard keys
Glyphs.register("key_enter", {
	getWidth = function(h)
		lg.setFont(font)

		return font:getWidth("Enter") + h * 0.4
	end,

	draw = function(w, h)
		drawKeycap(w, h, h * 0.18)
		lg.setColor(colorText)
		drawCenteredLabel("Enter", w, h, font)
	end
})

Glyphs.register("key_tab", {
	getWidth = function(h)
		lg.setFont(font)

		return font:getWidth("Tab") + h * 0.4
	end,

	draw = function(w, h)
		drawKeycap(w, h, h * 0.18)
		lg.setColor(colorText)
		drawCenteredLabel("Tab", w, h, font)
	end
})

Glyphs.register("key_space", {
	getWidth = function(h)
		return font:getWidth("Space") + h * 0.4
	end,

	draw = function(w, h)
		drawKeycap(w, h, h * 0.18)
		lg.setColor(colorText)
		drawCenteredLabel("Space", w, h, font)
	end
})

Glyphs.register("key_printscreen", {
	getWidth = function(h)
		lg.setFont(font)

		return font:getWidth("Prt Sc") + h * 0.4
	end,

	draw = function(w, h)
		drawKeycap(w, h, h * 0.18)
		lg.setColor(colorText)
		drawCenteredLabel("Prt Sc", w, h, font)
	end
})