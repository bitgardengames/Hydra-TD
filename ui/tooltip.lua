local Theme = require("core.theme")
local Text = require("ui.text")
local Fonts = require("core.fonts")
local Cursor = require("core.cursor")
local Constants = require("core.constants")

local lg = love.graphics
local max = math.max
local sub = string.sub

local Tooltip = {}

Tooltip.active = nil
Tooltip.padding = 8
Tooltip.titleSpacing = 10
Tooltip.lineHeight = 18
Tooltip.maxWidth = 260
Tooltip.corner = 6
Tooltip.minLabelStatGap = 20

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

local function getTitleFont()
	return Fonts.ui
end

function Tooltip.show(def)
	local t = Tooltip.active

	-- If content changed, rebuild + recalc
	if not t or t.title ~= def.title or t.rows ~= def.rows then
		t = {
			title = def.title,
			rows = def.rows or {},
			x = 0,
			y = 0,
			w = 0,
			h = 0,
		}

		Tooltip.active = t
		Tooltip.recalculate()
	end

	-- Always update position
	t.x = Cursor.x + 14
	t.y = Cursor.y + 14

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

	-- Title font
	Fonts.set("ui")
	local font = getFont()

	-- Panel
	lg.setColor(colorPanel)
	lg.rectangle("fill", t.x, t.y, t.w, t.h, Tooltip.corner, Tooltip.corner)

	lg.setColor(colorBorder)
	lg.rectangle("line", t.x, t.y, t.w, t.h, Tooltip.corner, Tooltip.corner)

	local x = t.x + Tooltip.padding
	local y = t.y + Tooltip.padding

	-- Title
	if t.title then
		lg.setColor(colorText)
		Text.printShadow(t.title, x, y)

		y = y + Tooltip.lineHeight + Tooltip.titleSpacing
	end

	-- Row font
	Fonts.set("tooltip")

	-- Rows
	for _, row in ipairs(t.rows) do
		local kind = row.kind or "kv"

		if kind == "text" then
			lg.setColor(row.color or colorMuted)
			Text.printShadow(row.text or "", x, y)

			y = y + Tooltip.lineHeight + (row.padAfter or 0)

		else
			local label = row.label or ""
			local value = tostring(row.value or "")
			local delta = row.delta

			-- Label (left)
			lg.setColor(row.color or colorText)
			Text.printShadow(label, x, y)

			-- Stats block (right-anchored, left-aligned internally)
			local statsRightX = t.x + t.w - Tooltip.padding
			local statsX = statsRightX - (t.statsBlockW or 0)

			-- Value
			lg.setColor(row.color or colorText)
			Text.printShadow(value, statsX, y)

			-- Delta
			if delta then
				local dc = colorGood

				if sub(delta, 1, 1) == "-" then
					dc = colorBad
				end

				local valueW = font:getWidth(value)
				local deltaText = "(" .. tostring(delta) .. ")"

				lg.setColor(dc)
				Text.printShadow(deltaText, statsX + valueW + 6, y)
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
	local titleFont = getTitleFont()

	local w = 0
	local h = Tooltip.padding * 2

	-- Track the widest label, and the widest "stats block" (value + delta)
	local maxLabelW = 0
	local maxStatsW = 0

	if t.title then
		w = max(w, titleFont:getWidth(t.title))
		h = h + Tooltip.lineHeight + Tooltip.titleSpacing
	end

	for _, row in ipairs(t.rows) do
		local kind = row.kind or "kv"

		if kind == "text" then
			local text = row.text or ""

			w = max(w, font:getWidth(text))
			h = h + Tooltip.lineHeight + (row.padAfter or 0)
		else
			local label = row.label or ""
			local value = tostring(row.value or "")
			local delta = row.delta
			local labelW = font:getWidth(label)
			local statsW = font:getWidth(value)

			maxLabelW = max(maxLabelW, labelW)

			if delta then
				local deltaText = "(" .. tostring(delta) .. ")"

				statsW = statsW + 6 + font:getWidth(deltaText)
			end

			maxStatsW = max(maxStatsW, statsW)

			h = h + Tooltip.lineHeight
		end
	end

	-- Minimum spacing between label and stats
	t.statsOffset = maxLabelW + Tooltip.minLabelStatGap

	-- Stats block width = actual text width
	t.statsBlockW = maxStatsW

	-- Key value width = label + gap + stats
	local kvW = t.statsOffset + t.statsBlockW

	w = max(w, kvW)

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