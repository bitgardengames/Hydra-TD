local Theme = require("core.theme")
local Fonts = require("core.fonts")
local Cursor = require("core.cursor")
local Constants = require("core.constants")

local lg = love.graphics
local max = math.max
local sub = string.sub

local Tooltip = {}

Tooltip.active = nil
Tooltip.padding = 8
Tooltip.lineHeight = 18
Tooltip.maxWidth = 260
Tooltip.corner = 6

-- Colors
local colorPanel = Theme.ui.panel
local colorBorder = Theme.ui.shadow
local colorText = Theme.ui.text
local colorGood = Theme.ui.good
local colorBad = Theme.ui.bad
local colorMuted = {colorText[1], colorText[2], colorText[3], 0.7}

local function getFont()
	return Fonts.tooltip
end

function Tooltip.show(def)
	Tooltip.active = {
		title = def.title,
		rows = def.rows or {},
		x = Cursor.x + 14,
		y = Cursor.y + 14,
		w = 0,
		h = 0,
	}

	Tooltip.recalculate()
	Tooltip.clampToScreen()
end

function Tooltip.hide()
	Tooltip.active = nil
end

function Tooltip.update(dt)
	local t = Tooltip.active

	if not t then
		return
	end

	t.x = Cursor.x + 14
	t.y = Cursor.y + 14

	Tooltip.clampToScreen()
end

function Tooltip.draw()
	local t = Tooltip.active

	if not t then
		return
	end

	local lastFont =

	Fonts.set("tooltip")

	local font = getFont()

	-- Panel
	lg.setColor(colorPanel)
	lg.rectangle("fill", t.x, t.y, t.w, t.h, Tooltip.corner, Tooltip.corner)

	lg.setColor(colorBorder)
	lg.rectangle("line", t.x, t.y, t.w, t.h, Tooltip.corner, Tooltip.corner)

	local x = t.x + Tooltip.padding
	local y = t.y + Tooltip.padding
	local rightX = t.x + t.w - Tooltip.padding

	-- Title
	if t.title then
		lg.setColor(colorText)
		lg.print(t.title, x, y)

		y = y + Tooltip.lineHeight + 4
	end

	-- Rows
	for _, row in ipairs(t.rows) do
		local kind = row.kind or "kv"

		if kind == "text" then
			lg.setColor(row.color or colorMuted)
			lg.print(row.text or "", x, y)

			y = y + Tooltip.lineHeight + (row.padAfter or 0)

		else
			local label = row.label or ""
			local value = tostring(row.value or "")
			local delta = row.delta

			lg.setColor(row.color or colorText)
			lg.print(label, x, y)

			local valueW = font:getWidth(value)
			lg.print(value, rightX - valueW, y)

			if delta then
				local dc = colorGood
				if sub(delta, 1, 1) == "-" then
					dc = colorBad
				end

				local deltaText = tostring(delta)
				local deltaW = font:getWidth(deltaText)

				lg.setColor(dc)
				lg.print(deltaText, rightX - valueW - deltaW - 6, y)
			end

			y = y + Tooltip.lineHeight
		end
	end
end

function Tooltip.recalculate()
	local t = Tooltip.active

	if not t then
		return
	end

	local font = getFont()

	local w = 0
	local h = Tooltip.padding * 2

	if t.title then
		--lg.setFont(font)
		w = max(w, font:getWidth(t.title))
		h = h + Tooltip.lineHeight + 4
	end

	for _, row in ipairs(t.rows) do
		local kind = row.kind or "kv"

		if kind == "text" then
			local text = row.text or ""

			w = max(w, font:getWidth(text))
			h = h + Tooltip.lineHeight + (row.padAfter or 0)
		else
			local labelW = font:getWidth(row.label or "")
			local valueW = font:getWidth(tostring(row.value or ""))
			local deltaW = row.delta and (font:getWidth(tostring(row.delta)) + 6) or 0
			local rowW = labelW + valueW + deltaW + 12

			w = max(w, rowW)
			h = h + Tooltip.lineHeight
		end
	end

	-- Respect maxWidth if someone feeds a very long single-line description
	w = max(0, math.min(w, Tooltip.maxWidth))

	t.w = w + Tooltip.padding * 2
	t.h = h
end

function Tooltip.clampToScreen()
	local t = Tooltip.active

	if not t then
		return
	end

	local sw, sh = lg.getDimensions()

	if t.x + t.w > sw then
		t.x = sw - t.w - 6
	end

	if t.y + t.h > sh then
		t.y = sh - t.h - 6
	end
end

return Tooltip