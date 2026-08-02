local State = require("core.state")
local Theme = require("core.theme")
local Waves = require("systems.waves")
local Text = require("ui.text")
local L = require("core.localization")

local lg = love.graphics
local floor = math.floor

local colorText = Theme.ui.text
local colorWave = Theme.ui.wave
local colorPanel = Theme.ui.panel2
local colorBackdrop = Theme.ui.backdrop
local colorOutline = Theme.outline.color

local SCREEN_PAD = 16
local PANEL_PAD = 12
local PANEL_W = 420
local HEADER_H = 30
local HEADER_GAP = 8
local ROW_GAP = 5

local outlineW = Theme.outline.width
local baseRadius = 6 * 3
local outerRadius = baseRadius + outlineW * 0.5
local innerRadius = baseRadius - outlineW * 0.25
local outerSmallRadius = 6 + outlineW * 0.5
local innerSmallRadius = 6 - outlineW * 0.25

local previewCache = {
	wave = nil,
	title = "",
	total = "",
	entries = {},
}

local WavePreview = {}

local function refreshPreview()
	if previewCache.wave == State.wave then
		return
	end

	local preview = Waves.getWavePreview(State.wave)
	previewCache.wave = State.wave
	previewCache.title = L("hud.upcomingWave", State.wave)
	previewCache.total = L("hud.waveTotal", preview.count)

	local entries = previewCache.entries
	for i = #entries, 1, -1 do
		entries[i] = nil
	end

	for i = 1, #preview.composition do
		local group = preview.composition[i]
		entries[i] = {
			name = L("hud.compositionEntry", group.count, group.name),
			timing = L("hud.groupTiming", i, group.delay, group.spacing),
			tags = table.concat(group.tags, " · "),
			hint = table.concat(group.counterHints, " "),
		}
	end
end

function WavePreview.draw()
	if not State.inPrep then
		return
	end

	refreshPreview()

	local font = lg.getFont()
	local textH = font:getHeight()
	local rowH = textH * 4 + ROW_GAP
	local bodyH = math.max(textH, #previewCache.entries * rowH - ROW_GAP)
	local panelH = PANEL_PAD * 2 + HEADER_H + HEADER_GAP + bodyH
	local x = SCREEN_PAD
	local y = SCREEN_PAD

	lg.setColor(colorOutline)
	lg.rectangle("fill", x - outlineW, y - outlineW, PANEL_W + outlineW * 2, panelH + outlineW * 2, outerRadius)

	lg.setColor(colorBackdrop)
	lg.rectangle("fill", x, y, PANEL_W, panelH, innerRadius)

	local innerX = x + PANEL_PAD
	local innerW = PANEL_W - PANEL_PAD * 2
	local headerY = y + PANEL_PAD

	lg.setColor(colorOutline)
	lg.rectangle("fill", innerX - outlineW, headerY - outlineW, innerW + outlineW * 2, HEADER_H + outlineW * 2, outerSmallRadius)

	lg.setColor(colorPanel)
	lg.rectangle("fill", innerX, headerY, innerW, HEADER_H, innerSmallRadius)

	local titleY = headerY + floor((HEADER_H - textH) * 0.5 + 0.5)
	lg.setColor(colorWave)
	Text.printShadow(previewCache.title, innerX + 8, titleY)

	lg.setColor(colorText)
	Text.printShadow(previewCache.total, innerX + innerW - 8 - font:getWidth(previewCache.total), titleY)

	local rowY = headerY + HEADER_H + HEADER_GAP
	for i = 1, #previewCache.entries do
		local entry = previewCache.entries[i]
		lg.setColor(colorText)
		Text.printShadow(entry.name, innerX, rowY)
		lg.setColor(colorWave)
		Text.printShadow(entry.timing, innerX, rowY + textH)
		if entry.tags ~= "" then
			lg.setColor(colorWave)
			Text.printShadow(entry.tags, innerX, rowY + textH * 2)
			lg.setColor(colorText)
			Text.printfShadow(entry.hint, innerX, rowY + textH * 3, innerW, "left")
		end
		rowY = rowY + rowH
	end
end

return WavePreview
