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
local COMPLETE_PULSE_DURATION = 0.12
local COMPLETE_EXIT_DURATION = 0.10
local PREVIEW_ENTER_DURATION = 0.14

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
	title = "",
	count = "",
}

local transition = {
	wasInPrep = nil,
	startedAt = nil,
}

local WavePreview = {}

local function drawCombatProgress(offsetX, scale, celebrating, completed)
	local progress = Waves.getProgress()
	local total = completed and completed.total or progress.totalScheduled
	if total <= 0 then return end

	local x, y = COMBAT_X + (offsetX or 0), COMBAT_Y
	local innerW = COMBAT_W - COMBAT_PAD * 2
	local font = lg.getFont()
	local cleared = completed and total or math.min(total, progress.clearedCount)
	local clearedFrac = cleared / total
	local now = love.timer.getTime()
	if completed then
		combatProgress.fraction = 1
	elseif combatProgress.wave ~= State.wave or combatProgress.total ~= total then
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

	if not completed and combatProgress.fillStartedAt then
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
	local title = completed and completed.title or L("hud.upcomingWave", State.wave)
	local count = completed and completed.count or L("hud.waveProgress", cleared, total)
	if not completed then
		combatProgress.title = title
		combatProgress.count = count
	end

	if scale then
		lg.push()
		lg.translate(x + COMBAT_W * 0.5, y + COMBAT_H * 0.5)
		lg.scale(scale, scale)
		lg.translate(-(x + COMBAT_W * 0.5), -(y + COMBAT_H * 0.5))
	end

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
	if celebrating then
		lg.setColor(Theme.ui.good)
		lg.rectangle("line", x - outlineW * 2, y - outlineW * 2,
			COMBAT_W + outlineW * 4, COMBAT_H + outlineW * 4, outerSmallRadius)
	end

	if scale then lg.pop() end
end

local function drawCompletedCombatCard(elapsed)
	local pulseT = math.min(1, elapsed / COMPLETE_PULSE_DURATION)
	local scale = 1 + math.sin(pulseT * math.pi) * 0.055
	local exitT = math.max(0, math.min(1,
		(elapsed - COMPLETE_PULSE_DURATION) / COMPLETE_EXIT_DURATION))
	local easedExit = exitT * exitT
	-- Keep the completed wave visible even though gameplay has already advanced State.wave.
	drawCombatProgress(-easedExit * (COMBAT_W + SCREEN_PAD * 2), scale, exitT == 0, {
		total = combatProgress.total,
		title = combatProgress.title,
		count = L("hud.waveProgress", combatProgress.total, combatProgress.total),
	})
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
		entries[i] = {
			name = L("hud.compositionEntry", group.count, group.name),
			portrait = DrawEntities.newEnemyPortrait(group.kind),
		}
	end
end

local function drawPreview(offsetX)
	lg.push()
	lg.translate(offsetX or 0, 0)

	refreshPreview()

	local font = lg.getFont()
	local textH = font:getHeight()
	local bodyH = 0
	for _, entry in ipairs(previewCache.entries) do
		entry.rowH = math.max(PORTRAIT_H, textH)
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
		local textY = rowY + floor((entry.rowH - textH) * 0.5)
		DrawEntities.drawEnemyPortrait(entry.portrait, innerX + PORTRAIT_W * 0.5, rowY + entry.rowH * 0.5, animT)
		lg.setColor(colorText)
		Text.printShadow(entry.name, textX, textY)
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
	lg.pop()
end

function WavePreview.draw()
	local now = love.timer.getTime()
	if transition.wasInPrep == nil then transition.wasInPrep = State.inPrep end

	if not State.inPrep then
		-- Starting the next wave always wins over presentation, even midway through
		-- the completion flourish.
		transition.wasInPrep = false
		transition.startedAt = nil
		drawCombatProgress()
		return
	end

	if transition.wasInPrep == false then
		transition.startedAt = now
	end
	transition.wasInPrep = true

	if transition.startedAt then
		local elapsed = now - transition.startedAt
		local exitEnd = COMPLETE_PULSE_DURATION + COMPLETE_EXIT_DURATION
		if elapsed < exitEnd then
			drawCompletedCombatCard(elapsed)
			return
		end
		local enterT = math.min(1, (elapsed - exitEnd) / PREVIEW_ENTER_DURATION)
		if enterT < 1 then
			local eased = 1 - (1 - enterT) ^ 3
			drawPreview((1 - eased) * (PANEL_W + SCREEN_PAD))
			return
		end
		transition.startedAt = nil
	end

	drawPreview()
end

return WavePreview
