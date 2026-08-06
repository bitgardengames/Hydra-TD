local State = require("core.state")
local Theme = require("core.theme")
local Waves = require("systems.waves")
local Text = require("ui.text")
local L = require("core.localization")
local CampaignUnlocks = require("systems.campaign_unlocks")

local lg = love.graphics
local floor = math.floor

local colorText = Theme.ui.text
local colorWave = Theme.ui.wave
local colorPanel = Theme.ui.panel2
local colorBackdrop = Theme.ui.backdrop
local colorOutline = Theme.outline.color

local SCREEN_PAD = 16
local PANEL_PAD = 12
local PANEL_W = 440
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
		local threats = #group.tags > 0 and L("hud.threatTags", table.concat(group.tags, " • ")) or nil
		local counter = #group.counterHints > 0 and L("hud.counterHint", table.concat(group.counterHints, " ")) or nil
		entries[i] = {
			name = CampaignUnlocks.hasEnhancedWavePreview() and L("hud.compositionEntry", group.count, group.name) or L("hud.compositionUnknown", group.count),
			threats = threats,
			counter = counter,
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
	local counterW = PANEL_W - PANEL_PAD * 2 - 8
	local bodyH = 0
	for _, entry in ipairs(previewCache.entries) do
		bodyH = bodyH + textH
		if entry.threats then bodyH = bodyH + textH end
		if entry.counter then
			local _, lines = font:getWrap(entry.counter, counterW)
			entry.counterLineCount = math.max(1, #lines)
			bodyH = bodyH + textH * entry.counterLineCount
		end
		bodyH = bodyH + ROW_GAP
	end
	bodyH = math.max(textH, bodyH - ROW_GAP)
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
		rowY = rowY + textH
		if entry.threats then
			lg.setColor(Theme.ui.warn)
			Text.printShadow(entry.threats, innerX + 8, rowY)
			rowY = rowY + textH
		end
		if entry.counter then
			lg.setColor(Theme.ui.good)
			Text.printfShadow(entry.counter, innerX + 8, rowY, innerW - 8, "left")
			rowY = rowY + textH * (entry.counterLineCount or 1)
		end
		rowY = rowY + ROW_GAP
	end
end

return WavePreview
