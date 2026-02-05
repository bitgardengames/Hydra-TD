-- ui/hotkey_display.lua
local Hotkeys = require("core.hotkeys")
local Cursor  = require("core.cursor")
local State   = require("core.state")

local HotkeyDisplay = {}

-- ======================
-- Config
-- ======================

HotkeyDisplay.enabled = true   -- later: bind to Save.data.settings.showHotkeys
HotkeyDisplay.size = 18
HotkeyDisplay.padding = 6

-- ======================
-- Device detection
-- ======================

local function usingController()
	-- This mirrors your existing behavior:
	-- virtual cursor = controller intent
	return Cursor.usingVirtual == true
end

-- ======================
-- Glyph registry (v1)
-- ======================

-- For now this assumes Xbox-style glyph images.
-- Later this becomes swappable sets.
local GLYPHS = {
	a = "assets/ui/glyphs/a.png",
	b = "assets/ui/glyphs/b.png",
	x = "assets/ui/glyphs/x.png",
	y = "assets/ui/glyphs/y.png",

	leftshoulder  = "assets/ui/glyphs/lb.png",
	rightshoulder = "assets/ui/glyphs/rb.png",

	start = "assets/ui/glyphs/start.png",
	back  = "assets/ui/glyphs/back.png",

	leftstick  = "assets/ui/glyphs/l3.png",
	rightstick = "assets/ui/glyphs/r3.png",

	dpup    = "assets/ui/glyphs/dp_up.png",
	dpdown  = "assets/ui/glyphs/dp_down.png",
	dpleft  = "assets/ui/glyphs/dp_left.png",
	dpright = "assets/ui/glyphs/dp_right.png",
}

local glyphCache = {}

function HotkeyDisplay.load()
	for key, path in pairs(GLYPHS) do
		local img = love.graphics.newImage(path)
		img:setFilter("linear", "linear")
		glyphCache[key] = img
	end
end

-- ======================
-- Resolution
-- ======================

local function resolveAction(action)
	if usingController() then
		return Hotkeys.pad.actions[action]
	end

	return Hotkeys.kb.actions[action]
end

-- ======================
-- Drawing
-- ======================

function HotkeyDisplay.draw(action, x, y, opts)
	if not HotkeyDisplay.enabled then
		return
	end

	opts = opts or {}

	local key = resolveAction(action)
	if not key then
		return
	end

	local scale = opts.scale or 1
	local alpha = opts.alpha or 1

	love.graphics.setColor(1, 1, 1, alpha)

	-- Controller → glyph
	if usingController() then
		local img = glyphCache[key]
		if not img then
			return
		end

		local size = HotkeyDisplay.size * scale
		local sx = size / img:getWidth()
		local sy = size / img:getHeight()

		love.graphics.draw(img, x, y, 0, sx, sy)
		return
	end

	-- Keyboard → text
	local label = "[" .. key:upper() .. "]"
	love.graphics.print(label, x, y)
end

-- ======================
-- Measurement helper
-- ======================

function HotkeyDisplay.getWidth(action, font, scale)
	if not HotkeyDisplay.enabled then
		return 0
	end

	local key = resolveAction(action)
	if not key then
		return 0
	end

	if usingController() then
		return HotkeyDisplay.size * (scale or 1)
	end

	font = font or love.graphics.getFont()
	return font:getWidth("[" .. key:upper() .. "]")
end

return HotkeyDisplay