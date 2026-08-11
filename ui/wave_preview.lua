local State = require("core.state")
local Theme = require("core.theme")
local Waves = require("systems.waves")
local Hotkeys = require("core.hotkeys")
local DrawEntities = require("render.draw_entities")
local Text = require("ui.text")
local L = require("core.localization")

local lg = love.graphics
local floor = math.floor

local colorText = Theme.ui.text
local colorPanel = Theme.ui.panel2
local colorBackdrop = Theme.ui.backdrop
local colorOutline = Theme.outline.color

local COMBAT_X = 16
local COMBAT_Y = 16
local COMBAT_W = 244
local COMBAT_H = 48
local COMBAT_PAD = 8
local COMBAT_BAR_H = 8
local COMBAT_BAR_FILL_DURATION = 0.25

local SCREEN_PAD = 16
local PANEL_PAD = 12
local PANEL_W = 400
local HEADER_H = 30
local HEADER_GAP = 8
local ROW_GAP = 5
local PORTRAIT_W = 46
local PORTRAIT_H = 42
local TEXT_GAP = 6

local outlineW = Theme.outline.width
local baseRadius = 6 * 3
local outerRadius = baseRadius + outlineW * 0.5
local innerRadius = baseRadius - outlineW * 0.25
local outerSmallRadius = 6 + outlineW * 0.5
local innerSmallRadius = 6 - outlineW * 0.25

local previewCache = {
	wave = nil,
	mapIndex = nil,
	endless = nil,
	title = "",
	total = "",
	entries = {},
	startKey = nil,
	startPrompt = "",
}

local combatProgress = {
	wave = nil,
	total = nil,
	fraction = 0,
	targetFraction = 0,
	startFraction = 0,
	fillStartedAt = nil,
}

local WavePreview = {}

local function drawCombatProgress()
	local progress = Waves.getProgress()
	local total = progress.totalScheduled
	if total <= 0 then return end

	local x, y = COMBAT_X, COMBAT_Y
	local innerW = COMBAT_W - COMBAT_PAD * 2
	local font = lg.getFont()
	local cleared = math.min(total, progress.clearedCount)
	local clearedFrac = cleared / total
	local now = love.timer.getTime()
	if combatProgress.wave ~= State.wave or combatProgress.total ~= total then
		combatProgress.wave = State.wave
		combatProgress.total = total
		combatProgress.fraction = clearedFrac
		combatProgress.targetFraction = clearedFrac
		combatProgress.startFraction = clearedFrac
		combatProgress.fillStartedAt = nil
	elseif clearedFrac < combatProgress.targetFraction then
		-- Progress should only fill during a wave. Snap backward if the wave state is
		-- corrected rather than playing the fill animation in reverse.
		combatProgress.fraction = clearedFrac
		combatProgress.targetFraction = clearedFrac
		combatProgress.startFraction = clearedFrac
		combatProgress.fillStartedAt = nil
	elseif clearedFrac > combatProgress.targetFraction then
		combatProgress.startFraction = combatProgress.fraction
		combatProgress.targetFraction = clearedFrac
		combatProgress.fillStartedAt = now
	end

	if combatProgress.fillStartedAt then
		local elapsed = now - combatProgress.fillStartedAt
		local fillT = math.min(1, elapsed / COMBAT_BAR_FILL_DURATION)
		local easedT = 1 - (1 - fillT) ^ 3
		combatProgress.fraction = combatProgress.startFraction
			+ (combatProgress.targetFraction - combatProgress.startFraction) * easedT
		if fillT == 1 then
			combatProgress.fraction = combatProgress.targetFraction
			combatProgress.fillStartedAt = nil
		end
	end
	local title = L("hud.combatWave", State.wave)
	local count = L("hud.waveProgress", cleared, total)

	lg.setColor(colorOutline)
	lg.rectangle("fill", x - outlineW, y - outlineW, COMBAT_W + outlineW * 2,
		COMBAT_H + outlineW * 2, outerSmallRadius)
	lg.setColor(colorBackdrop)
	lg.rectangle("fill", x, y, COMBAT_W, COMBAT_H, innerSmallRadius)

	lg.setColor(colorText)
	Text.printShadow(title, x + COMBAT_PAD, y + COMBAT_PAD)
	lg.setColor(colorText)
	Text.printShadow(count, x + COMBAT_W - COMBAT_PAD - font:getWidth(count), y + COMBAT_PAD)

	local barY = y + COMBAT_H - COMBAT_PAD - COMBAT_BAR_H
	lg.setColor(colorPanel)
	lg.rectangle("fill", x + COMBAT_PAD, barY, innerW, COMBAT_BAR_H, 4)
	if combatProgress.fraction > 0 then
		lg.setColor(Theme.ui.good)
		lg.rectangle("fill", x + COMBAT_PAD, barY, innerW * combatProgress.fraction, COMBAT_BAR_H, 4)
	end

end

local function refreshPreview()
	if previewCache.wave == State.wave
		and previewCache.mapIndex == State.mapIndex
		and previewCache.endless == State.endless then
		return
	end

	local preview = Waves.getWavePreview(State.wave)
	previewCache.wave = State.wave
	previewCache.mapIndex = State.mapIndex
	previewCache.endless = State.endless
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
			name = L("hud.compositionEntry", group.count, group.name),
			threats = threats,
			counter = counter,
			portrait = DrawEntities.newEnemyPortrait(group.kind),
		}
	end
end

function WavePreview.draw()
	if not State.inPrep then
		drawCombatProgress()
		return
	end

	refreshPreview()

	local font = lg.getFont()
	local textH = font:getHeight()
	local counterW = PANEL_W - PANEL_PAD * 2 - PORTRAIT_W - TEXT_GAP - 8
	local bodyH = 0
	for _, entry in ipairs(previewCache.entries) do
		local textBlockH = textH
		if entry.threats then textBlockH = textBlockH + textH end
		if entry.counter then
			local _, lines = font:getWrap(entry.counter, counterW)
			entry.counterLineCount = math.max(1, #lines)
			textBlockH = textBlockH + textH * entry.counterLineCount
		end
		entry.rowH = math.max(PORTRAIT_H, textBlockH)
		bodyH = bodyH + entry.rowH + ROW_GAP
	end
	bodyH = math.max(textH, bodyH - ROW_GAP)
	local panelH = PANEL_PAD * 2 + HEADER_H + HEADER_GAP + bodyH + HEADER_GAP + textH
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
	lg.setColor(colorText)
	Text.printShadow(previewCache.title, innerX + 8, titleY)

	lg.setColor(colorText)
	Text.printShadow(previewCache.total, innerX + innerW - 8 - font:getWidth(previewCache.total), titleY)

	local rowY = headerY + HEADER_H + HEADER_GAP
	local animT = love.timer.getTime()
	for i = 1, #previewCache.entries do
		local entry = previewCache.entries[i]
		local textX = innerX + PORTRAIT_W + TEXT_GAP
		local textY = rowY + floor((entry.rowH - (textH
			+ (entry.threats and textH or 0)
			+ (entry.counter and textH * (entry.counterLineCount or 1) or 0))) * 0.5)
		DrawEntities.drawEnemyPortrait(entry.portrait, innerX + PORTRAIT_W * 0.5, rowY + entry.rowH * 0.5, animT)
		lg.setColor(colorText)
		Text.printShadow(entry.name, textX, textY)
		textY = textY + textH
		if entry.threats then
			lg.setColor(Theme.ui.warn)
			Text.printShadow(entry.threats, textX + 8, textY)
			textY = textY + textH
		end
		if entry.counter then
			lg.setColor(Theme.ui.good)
			Text.printfShadow(entry.counter, textX + 8, textY, innerW - PORTRAIT_W - TEXT_GAP - 8, "left")
		end
		rowY = rowY + entry.rowH + ROW_GAP
	end

	local startKey = Hotkeys.getDisplay("skipPrep")
	if previewCache.startKey ~= startKey then
		previewCache.startKey = startKey
		previewCache.startPrompt = L("hud.prep", startKey)
	end
	lg.setColor(Theme.ui.good)
	Text.printShadow(previewCache.startPrompt,
		innerX + floor((innerW - font:getWidth(previewCache.startPrompt)) * 0.5 + 0.5),
		rowY + HEADER_GAP - ROW_GAP)
end

return WavePreview
