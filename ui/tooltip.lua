local Theme = require("core.theme")
local Text = require("ui.text")
local Fonts = require("core.fonts")

local lg = love.graphics
local max = math.max
local sub = string.sub

local Tooltip = {}

Tooltip.active = nil
Tooltip.cached = nil
Tooltip.padding = 8
Tooltip.titleSpacing = 10
Tooltip.lineHeight = 18
Tooltip.maxWidth = 260
Tooltip.corner = 6
Tooltip.minLabelStatGap = 20
Tooltip.safeInset = 6

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

-- contentKey identifies the semantic contents of a tooltip. Callers may omit it
-- when they retain the definition table, but must replace that table (or pass a
-- new key/version) whenever any displayed value changes.
function Tooltip.show(def, contentKey)
	contentKey = contentKey or def
	local t = Tooltip.cached

	-- A tooltip is hidden at the beginning of each draw pass. Keep its measured
	-- layout cached across that hide/show cycle and only rebuild for new content.
	if not t or t.contentKey ~= contentKey then
		t = {
			contentKey = contentKey,
			title = def.title,
			rows = def.rows or {},
			x = 0,
			y = 0,
			w = 0,
			h = 0,
		}

		Tooltip.cached = t
		Tooltip.active = t
		Tooltip.recalculate()
	end
	Tooltip.active = t

	-- Always update position
	t.x = love.mouse.getX() + 14
	t.y = love.mouse.getY() + 14

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

	t.x = love.mouse.getX() + 14
	t.y = love.mouse.getY() + 14

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
	local oldScissor = {lg.getScissor()}

	-- A tooltip can be higher than the viewport. Keep its contents inside the
	-- panel; the bottom is deliberately clipped instead of moving the panel to
	-- a negative y coordinate.
	lg.setScissor(t.x, t.y, t.w, t.h)

	-- Title
	if t.title then
		lg.setColor(colorText)
		for _, line in ipairs(t.titleLines or {t.title}) do
			Text.printShadow(line, x, y)
			y = y + Tooltip.lineHeight
		end

		y = y + Tooltip.titleSpacing
	end

	-- Row font
	Fonts.set("tooltip")

	-- Rows
	for index, row in ipairs(t.rows) do
		local layout = t.rowLayouts and t.rowLayouts[index] or {}
		local kind = row.kind or "kv"

		if kind == "text" then
			lg.setColor(row.color or colorMuted)
			for _, line in ipairs(layout.lines or {row.text or ""}) do
				Text.printShadow(line, x, y)
				y = y + Tooltip.lineHeight
			end

			y = y + (row.padAfter or 0)

		else
			local label = row.label or ""
			local value = tostring(row.value or "")
			local delta = row.delta

			-- Label (left). On narrow screens stats are placed on the next line.
			lg.setColor(row.color or colorText)
			for _, line in ipairs(layout.labelLines or {label}) do
				Text.printShadow(line, x, y)
				y = y + Tooltip.lineHeight
			end
			y = y - Tooltip.lineHeight

			-- Stats block (right-anchored, left-aligned internally)
			local statsRightX = t.x + t.w - Tooltip.padding
			local statsX = statsRightX - (t.statsBlockW or 0)

			if t.stackStats then
				y = y + Tooltip.lineHeight
				statsX = x
			end

			if layout.statsLines and #layout.statsLines > 1 then
				lg.setColor(row.color or colorText)
				for _, line in ipairs(layout.statsLines) do
					Text.printShadow(line, statsX, y)
					y = y + Tooltip.lineHeight
				end
				y = y - Tooltip.lineHeight
				value = nil
			end

			-- Value
			if value then
				lg.setColor(row.color or colorText)
				Text.printShadow(value, statsX, y)
			end

			-- Delta
			if delta and value then
				local dc = row.deltaColor or colorGood

				if not row.deltaColor and sub(delta, 1, 1) == "-" then
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

	if oldScissor[1] then
		lg.setScissor(unpack(oldScissor))
	else
		lg.setScissor()
	end
end

function Tooltip.recalculate()
	local t = Tooltip.active

	if not t then
		return
	end

	local font = getFont()
	local titleFont = getTitleFont()
	local sw = lg.getWidth()
	local usableW = max(1, sw - Tooltip.safeInset * 2)
	local contentLimit = max(1, math.min(Tooltip.maxWidth, usableW - Tooltip.padding * 2))

	local w = 0
	local h = Tooltip.padding * 2

	-- Track the widest label, and the widest "stats block" (value + delta)
	local maxLabelW = 0
	local maxStatsW = 0
	t.rowLayouts = {}

	if t.title then
		local wrappedW, lines = titleFont:getWrap(t.title, contentLimit)
		t.titleLines = lines
		w = max(w, wrappedW)
		h = h + #lines * Tooltip.lineHeight + Tooltip.titleSpacing
	else
		t.titleLines = nil
	end

	for index, row in ipairs(t.rows) do
		local kind = row.kind or "kv"
		local layout = {}
		t.rowLayouts[index] = layout

		if kind == "text" then
			local text = row.text or ""
			local wrappedW, lines = font:getWrap(text, contentLimit)

			layout.lines = lines
			w = max(w, wrappedW)
			h = h + #lines * Tooltip.lineHeight + (row.padAfter or 0)
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
	t.stackStats = kvW > contentLimit
	if t.stackStats then
		kvW = 0
		-- Wrap both halves independently and put stats below their labels.
		for index, row in ipairs(t.rows) do
			if (row.kind or "kv") ~= "text" then
				local layout = t.rowLayouts[index]
				local label = row.label or ""
				local stats = tostring(row.value or "")
				if row.delta then
					stats = stats .. " (" .. tostring(row.delta) .. ")"
				end
				local labelW, labelLines = font:getWrap(label, contentLimit)
				local statsW, statsLines = font:getWrap(stats, contentLimit)
				layout.labelLines = labelLines
				layout.statsLines = statsLines
				kvW = max(kvW, labelW, statsW)
				h = h + (#labelLines - 1 + #statsLines) * Tooltip.lineHeight
			end
		end
	end

	w = math.min(contentLimit, max(w, kvW))

	t.w = w + Tooltip.padding * 2
	t.contentH = h
	t.h = h
	t.layoutScreenW = sw
end

function Tooltip.clampToScreen()
	local t = Tooltip.active

	if not t then
		return
	end

	local sw, sh = lg.getDimensions()
	local inset = Tooltip.safeInset
	local usableW = max(1, sw - inset * 2)
	local usableH = max(1, sh - inset * 2)

	-- Screen dimensions can change while a tooltip remains active.
	if t.layoutScreenW ~= sw or t.w > usableW then
		Tooltip.recalculate()
	end
	t.w = math.min(t.w, usableW)
	t.h = math.min(t.contentH or t.h, usableH)
	t.x = math.max(inset, math.min(t.x, sw - inset - t.w))

	if (t.contentH or t.h) > usableH then
		t.y = inset
	else
		t.y = math.max(inset, math.min(t.y, sh - inset - t.h))
	end
end

function Tooltip.resize()
	Tooltip.recalculate()
	Tooltip.clampToScreen()
end

return Tooltip
