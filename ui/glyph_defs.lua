local Theme = require("core.theme")
local Fonts = require("core.fonts")
local Text = require("ui.text")
local Glyphs = require("ui.glyphs")

local lg = love.graphics

local font = Fonts.ui
local colorText = Theme.ui.text

local BUTTON_RADIUS = 0.50

-- Helpers
local function drawKeycap(w, h, r)
	lg.setColor(Theme.ui.button)
	lg.rectangle("fill", 0, 0, w, h, r, r)
end

local function drawCenteredLabel(text, w, h, font, yBias)
	lg.setFont(font)

	local y = (h - font:getHeight()) * 0.5 + 1 + (yBias or 0)

	Text.printfShadow(text, 0, y, w, "center")
end

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
