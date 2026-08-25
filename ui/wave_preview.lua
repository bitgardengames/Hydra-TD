local State = require("core.state")
local Theme = require("core.theme")
local Waves = require("systems.waves")
local EnemyDefs = require("world.enemy_defs")
local Hotkeys = require("core.hotkeys")
local DrawEntities = require("render.draw_entities")
local Text = require("ui.text")
local Tooltip = require("ui.tooltip")
local L = require("core.localization")

local lg = love.graphics
local floor = math.floor

local colorText = Theme.ui.text
local colorPanel = Theme.ui.panel2
local colorBackdrop = Theme.ui.backdrop
local colorOutline = Theme.outline.color

local SCREEN_PAD = 16
local PANEL_PAD = 12
local PANEL_W = 320
local HEADER_H = 30
local HEADER_GAP = 8
local ROW_GAP = 5
local PORTRAIT_W = 46
local PORTRAIT_H = 42
local TEXT_GAP = 6
local COMBAT_BAR_H = 10
local COMBAT_H = 70
local RESIZE_DURATION = 0.22
local COMBAT_BAR_FILL_DURATION = 0.25
local COMPLETE_PULSE_DURATION = 0.18

local outlineW = Theme.outline.width
local baseRadius = 6 * 3
local outerRadius = baseRadius + outlineW * 0.5
local innerRadius = baseRadius - outlineW * 0.25
local outerSmallRadius = 6 + outlineW * 0.5
local innerSmallRadius = 6 - outlineW * 0.25

local previewCache = {
	wave = nil,
	mapIndex = nil,
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

local panel = {
	mode = nil,
	height = nil,
	startHeight = nil,
	targetHeight = nil,
	resizeStartedAt = nil,
	completedAt = nil,
}

local WavePreview = {}

local function buildEnemyTooltip(group)
	local rows = {}
	local def = EnemyDefs[group.kind]
	if def and def.descriptionKey then
		rows[#rows + 1] = {kind = "text", text = L(def.descriptionKey), padAfter = 4}
	end
	if #group.tags > 0 then
		rows[#rows + 1] = {kind = "text", text = L("hud.threatTags", table.concat(group.tags, ", "))}
	end
	return {title = group.name, rows = rows}
end

local function refreshPreview()
	if previewCache.wave == State.wave
		and previewCache.mapIndex == State.mapIndex then
		return
	end

	local preview = Waves.getWavePreview(State.wave)
	previewCache.wave = State.wave
	previewCache.mapIndex = State.mapIndex
	previewCache.title = L("hud.upcomingWave", State.wave)
	previewCache.total = L("hud.waveTotal", preview.count)

	local entries = previewCache.entries
	for i = #entries, 1, -1 do entries[i] = nil end
	for i = 1, #preview.composition do
		local group = preview.composition[i]
		entries[i] = {
			name = L("hud.compositionEntry", group.count, group.name),
			portrait = DrawEntities.newEnemyPortrait(group.kind),
			tooltip = buildEnemyTooltip(group),
		}
	end
end

local function getPreviewHeight()
	refreshPreview()
	local textH = lg.getFont():getHeight()
	local bodyH = 0
	for _, entry in ipairs(previewCache.entries) do
		entry.rowH = math.max(PORTRAIT_H, textH)
		bodyH = bodyH + entry.rowH + ROW_GAP
	end
	bodyH = math.max(textH, bodyH - ROW_GAP)
	return PANEL_PAD * 2 + HEADER_H + HEADER_GAP + bodyH + HEADER_GAP + textH
end

local function updateCombatProgress(now)
	local progress = Waves.getProgress()
	local total = progress.totalScheduled
	if total <= 0 then return nil end
	local cleared = math.min(total, progress.clearedCount)
	local clearedFrac = cleared / total

	if combatProgress.wave ~= State.wave or combatProgress.total ~= total then
		combatProgress.wave = State.wave
		combatProgress.total = total
		combatProgress.fraction = clearedFrac
		combatProgress.targetFraction = clearedFrac
		combatProgress.startFraction = clearedFrac
		combatProgress.fillStartedAt = nil
	elseif clearedFrac < combatProgress.targetFraction then
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
		local fillT = math.min(1, (now - combatProgress.fillStartedAt) / COMBAT_BAR_FILL_DURATION)
		local easedT = 1 - (1 - fillT) ^ 3
		combatProgress.fraction = combatProgress.startFraction
			+ (combatProgress.targetFraction - combatProgress.startFraction) * easedT
		if fillT == 1 then
			combatProgress.fraction = combatProgress.targetFraction
			combatProgress.fillStartedAt = nil
		end
	end

	combatProgress.title = L("hud.upcomingWave", State.wave)
	combatProgress.count = L("hud.waveProgress", cleared, total)
	return combatProgress
end

local function drawPanel(height, pulse)
	local x, y = SCREEN_PAD, SCREEN_PAD
	lg.setColor(colorOutline)
	lg.rectangle("fill", x - outlineW, y - outlineW, PANEL_W + outlineW * 2,
		height + outlineW * 2, outerRadius)
	lg.setColor(colorBackdrop)
	lg.rectangle("fill", x, y, PANEL_W, height, innerRadius)
	if pulse > 0 then
		lg.setColor(Theme.ui.good)
		lg.rectangle("line", x - outlineW * (1 + pulse), y - outlineW * (1 + pulse),
			PANEL_W + outlineW * (2 + pulse * 2), height + outlineW * (2 + pulse * 2), outerRadius)
	end
end

local function drawHeader(title, count)
	local innerX = SCREEN_PAD + PANEL_PAD
	local innerW = PANEL_W - PANEL_PAD * 2
	local headerY = SCREEN_PAD + PANEL_PAD
	local font = lg.getFont()
	local textH = font:getHeight()

	lg.setColor(colorOutline)
	lg.rectangle("fill", innerX - outlineW, headerY - outlineW,
		innerW + outlineW * 2, HEADER_H + outlineW * 2, outerSmallRadius)
	lg.setColor(colorPanel)
	lg.rectangle("fill", innerX, headerY, innerW, HEADER_H, innerSmallRadius)

	local titleY = headerY + floor((HEADER_H - textH) * 0.5 + 0.5)
	lg.setColor(colorText)
	Text.printShadow(title, innerX + 8, titleY)
	Text.printShadow(count, innerX + innerW - 8 - font:getWidth(count), titleY)
	return innerX, innerW, headerY
end

local function drawCombat(now)
	local progress = updateCombatProgress(now)
	if not progress then return end
	local innerX, innerW, headerY = drawHeader(progress.title, progress.count)
	local barY = headerY + HEADER_H + HEADER_GAP
	lg.setColor(colorPanel)
	lg.rectangle("fill", innerX, barY, innerW, COMBAT_BAR_H, 4)
	if progress.fraction > 0 then
		lg.setColor(Theme.ui.good)
		lg.rectangle("fill", innerX, barY, innerW * progress.fraction, COMBAT_BAR_H, 4)
	end
end

local function drawPreview()
	local innerX, innerW, headerY = drawHeader(previewCache.title, previewCache.total)
	local font = lg.getFont()
	local textH = font:getHeight()
	local rowY = headerY + HEADER_H + HEADER_GAP
	local animT = love.timer.getTime()
	local mouseX, mouseY = love.mouse.getPosition()
	for i = 1, #previewCache.entries do
		local entry = previewCache.entries[i]
		local textX = innerX + PORTRAIT_W + TEXT_GAP
		local textY = rowY + floor((entry.rowH - textH) * 0.5)
		DrawEntities.drawEnemyPortrait(entry.portrait,
			innerX + PORTRAIT_W * 0.5, rowY + entry.rowH * 0.5, animT)
		lg.setColor(colorText)
		Text.printShadow(entry.name, textX, textY)
		if mouseX >= innerX and mouseX <= innerX + innerW
			and mouseY >= rowY and mouseY <= rowY + entry.rowH then
			Tooltip.show(entry.tooltip)
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

function WavePreview.draw()
	local now = love.timer.getTime()
	local mode = State.inPrep and "preview" or "combat"
	local targetHeight = mode == "preview" and getPreviewHeight() or COMBAT_H

	if not panel.mode then
		panel.mode = mode
		panel.height = targetHeight
		panel.targetHeight = targetHeight
	elseif panel.mode ~= mode or panel.targetHeight ~= targetHeight then
		if panel.mode == "combat" and mode == "preview" then panel.completedAt = now end
		panel.mode = mode
		panel.startHeight = panel.height
		panel.targetHeight = targetHeight
		panel.resizeStartedAt = now
	end

	if panel.resizeStartedAt then
		local resizeT = math.min(1, (now - panel.resizeStartedAt) / RESIZE_DURATION)
		local easedT = 1 - (1 - resizeT) ^ 3
		panel.height = panel.startHeight + (panel.targetHeight - panel.startHeight) * easedT
		if resizeT == 1 then
			panel.height = panel.targetHeight
			panel.resizeStartedAt = nil
		end
	end

	local pulse = 0
	if panel.completedAt then
		local pulseT = (now - panel.completedAt) / COMPLETE_PULSE_DURATION
		if pulseT < 1 then pulse = math.sin(pulseT * math.pi) else panel.completedAt = nil end
	end
	drawPanel(panel.height, pulse)

	-- Clip the changing information to the single resizing card, so transitioning
	-- between the compact progress view and the taller roster never spawns a
	-- second panel or lets its contents escape the animated bounds.
	local sx, sy, sw, sh = lg.getScissor()
	lg.setScissor(SCREEN_PAD, SCREEN_PAD, PANEL_W, panel.height)
	if mode == "preview" then drawPreview() else drawCombat(now) end
	if sx then lg.setScissor(sx, sy, sw, sh) else lg.setScissor() end
end

return WavePreview
