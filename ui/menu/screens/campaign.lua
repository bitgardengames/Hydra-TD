local Sound = require("systems.sound")
local Difficulty = require("systems.difficulty")
local Fonts = require("core.fonts")
local Theme = require("core.theme")
local State = require("core.state")
local Save = require("core.save")
local Maps = require("world.map_defs")
local MapPreviewCache = require("world.map_preview_cache")
local Text = require("ui.text")
local Button = require("ui.button")
local Medals = require("ui.medals")
local Tooltip = require("ui.tooltip")
local Backdrop = require("scenes.backdrop")
local Steam = require("core.steam")
local L = require("core.localization")
local CampaignUnlocks = require("systems.campaign_unlocks")
local CampaignWaveDefs = require("systems.campaign_wave_defs")
local RunModes = require("systems.run_modes")
local DrawEntities = require("render.draw_entities")
local AbilityIcons = require("ui.ability_icons")
local SelectionTransition = require("ui.campaign_selection_transition")
local UnlockPresentation = require("ui.campaign_unlock_presentation")

local lg = love.graphics
local floor = math.floor
local min = math.min
local max = math.max
local format = string.format

local Screen = {}
local DIFFICULTIES = {"easy", "normal", "hard"}
local MEDAL_NAMES = {"bronze", "silver", "gold"}
local DIFFICULTY_COLORS = {
	easy = Theme.ui.good,
	normal = Theme.ui.warn,
	hard = Theme.ui.bad,
}
local DIFFICULTY_HINTS = {
	easy = "campaign.difficultyEasy",
	normal = "campaign.difficultyNormal",
	hard = "campaign.difficultyHard",
}

local buttons = {}
local pulseTime = 0
local hoveredMedal
local listOffset = 0
local scrollbarDragging = false
local scrollbarGrabY = 0
local selection = {fromIndex = State.mapIndex, toIndex = State.mapIndex, elapsed = SelectionTransition.DURATION}
local unlockSequence = UnlockPresentation.new()

local LIST_ROW_H = 76
local LIST_PREVIEW_W = 96
local LIST_PREVIEW_H = 60
local MAIN_PREVIEW_HEIGHT_RATIO = 0.45

local function statsFor(mapId)
	return Save.data.mapStats and Save.data.mapStats[mapId]
end

local function isMapLocked(index)
	if RunModes.isEndless(State) then
		local stats = statsFor(Maps[index].id)
		return not (stats and stats.completedDifficulty)
	end
	return not Save.isMapUnlocked(index, Maps[index].id)
end

local function difficultyIndex(key)
	for i, value in ipairs(DIFFICULTIES) do
		if value == key then return i end
	end
	return 2
end

local function selectDifficulty(key)
	if Save.data.settings.difficulty == key then return end
	Save.data.settings.difficulty = key
	Difficulty.set(key)
	Save.markDirty()
	Sound.play("uiMove")
end

local function panel(x, y, w, h, selected)
	lg.setColor(selected and Theme.ui.selected or Theme.outline.color)
	lg.rectangle("fill", x - 2, y - 2, w + 4, h + 4, 10)
	lg.setColor(Theme.ui.panel2)
	lg.rectangle("fill", x, y, w, h, 8)
end

local function drawRewardIcon(reward, cx, cy)
	if reward.type == "tower" then
		lg.push("all")
		lg.translate(cx, cy)
		DrawEntities.drawTowerBase(reward.id, 0, 5, 1)
		DrawEntities.drawTowerCore(reward.id, 0, 5, -math.pi * 0.5, 0, 1)
		lg.pop()
	elseif reward.type == "ability" then
		AbilityIcons.draw(reward.id, cx, cy, 1, 1)
	end
end

local function layout()
	local sw, sh = lg.getDimensions()
	local margin = max(18, floor(sw * 0.022))
	local headerH = max(92, floor(sh * 0.144))
	local footerH = max(54, floor(sh * 0.098))
	local gap = 0
	local contentY = headerH
	local contentH = min(716, sh - headerH - footerH)
	local contentW = min(1380, sw - margin * 2)
	local contentX = floor((sw - contentW) * 0.5)
	local leftW = floor(contentW * 0.29)
	local rightW = floor(contentW * 0.255)
	local centerW = contentW - gap * 2 - leftW - rightW
	return {
		sw = sw, sh = sh, margin = margin, headerH = headerH, footerH = footerH,
		gap = gap, contentY = contentY, contentH = contentH,
		left = {x = contentX, y = contentY, w = leftW, h = contentH},
		center = {x = contentX + leftW + gap, y = contentY, w = centerW, h = contentH},
		right = {x = contentX + contentW - rightW, y = contentY, w = rightW, h = contentH},
	}
end

local function visibleRows(l)
	local rowH = LIST_ROW_H
	return rowH, max(1, floor((l.left.h - 88) / rowH))
end

local function scrollbarGeometry(l)
	local _, count = visibleRows(l)
	if #Maps <= count then return nil end
	local trackX = l.left.x + l.left.w - 13
	local trackY = l.left.y + 10
	local trackH = l.left.h - 90
	local thumbH = max(32, trackH * count / #Maps)
	local maxOffset = #Maps - count
	local thumbY = trackY + (trackH - thumbH) * listOffset / maxOffset
	return trackX, trackY, 6, trackH, thumbY, thumbH, maxOffset
end

local function scrollToThumb(l, thumbY)
	local _, trackY, _, trackH, _, thumbH, maxOffset = scrollbarGeometry(l)
	if not trackY then return end
	local travel = trackH - thumbH
	local progress = travel > 0 and (thumbY - trackY) / travel or 0
	listOffset = floor(max(0, min(1, progress)) * maxOffset + 0.5)
end

local function keepSelectedVisible(l)
	local _, count = visibleRows(l)
	if State.mapIndex <= listOffset then listOffset = State.mapIndex - 1 end
	if State.mapIndex > listOffset + count then listOffset = State.mapIndex - count end
	listOffset = max(0, min(listOffset, max(0, #Maps - count)))
end

local function reducedMotion()
	return Save.data.settings.cameraMotion == false
end

local function selectionPose()
	return SelectionTransition.sample(selection.fromIndex, selection.toIndex, selection.elapsed, reducedMotion())
end

local function selectMap(index)
	if index == State.mapIndex then return end
	selection.fromIndex = State.mapIndex
	selection.toIndex = index
	selection.elapsed = reducedMotion() and SelectionTransition.DURATION or 0
	State.mapIndex = index
end

local function navigate(direction)
	local nextIndex = State.mapIndex + direction
	if nextIndex < 1 or nextIndex > #Maps or (direction > 0 and isMapLocked(nextIndex)) then
		Sound.play("uiError")
		return
	end
	Tooltip.hide()
	selectMap(State.resolveMapIndex(nextIndex))
	keepSelectedVisible(layout())
	Sound.play("uiMove")
end

local function playMap()
	if isMapLocked(State.mapIndex) then Sound.play("uiError"); return end
	Tooltip.hide()
	Sound.play("uiConfirm")
	State.worldMapIndex = State.mapIndex
	RunModes.set(State, RunModes.get(State))
	State.ignoreStats = false
	State.mode = "game"
	Backdrop.stop()
	Difficulty.set(Save.data.settings.difficulty)
	resetGame()
	Sound.playMusic("gameplay")
end

local function goBack()
	Tooltip.hide()
	Save.flush()
	State.mode = "menu"
	Steam.setRichPresence(L("presence.menu"))
	Sound.play("uiBack")
end

local function drawHeader(l, pose, unlockPose)
	Fonts.set("title")
	lg.setColor(Theme.ui.text)
	Text.printShadow(L("campaign.title"), l.margin, 20)
	Fonts.set("ui")
	lg.setColor(Theme.ui.text[1], Theme.ui.text[2], Theme.ui.text[3], 0.72)
	Text.printShadow(L("campaign.selectMap"), l.margin, 66)

	local startX = l.left.x + l.left.w + 18
	local available = l.right.x - startX - 14
	local step = available / (#Maps - 1)
	local y = 49
	lg.setLineWidth(4)
	for i = 1, #Maps - 1 do
		lg.setColor(i < pose.markerIndex and Theme.ui.good or Theme.ui.panel)
		lg.line(startX + (i - 1) * step, y, startX + i * step, y)
	end
	if unlockPose and unlockPose.sourceIndex < unlockPose.targetIndex then
		local fromX = startX + (unlockPose.sourceIndex - 1) * step
		local toX = startX + (unlockPose.targetIndex - 1) * step
		lg.setColor(Theme.ui.good)
		lg.line(fromX, y, fromX + (toX - fromX) * unlockPose.line, y)
	end
	for i = 1, #Maps do
		local x = startX + (i - 1) * step
		local locked = isMapLocked(i)
		lg.setColor(locked and Theme.ui.panel or Theme.ui.good)
		lg.circle("fill", x, y, 15)
		lg.setColor(Theme.outline.color)
		lg.circle("line", x, y, 15)
		Fonts.set("ui")
		lg.setColor(Theme.ui.text)
		lg.printf(locked and "•" or tostring(i), x - 12, y - 9, 24, "center")
	end
	if unlockPose and unlockPose.stamp > 0 then
		local x = startX + (unlockPose.targetIndex - 1) * step
		lg.setColor(Theme.ui.good[1], Theme.ui.good[2], Theme.ui.good[3], 0.8 * unlockPose.stamp)
		lg.setLineWidth(3)
		lg.circle("line", x, y, 18 + 13 * unlockPose.stamp)
	end
	local markerX = startX + (pose.markerIndex - 1) * step
	lg.setColor(Theme.ui.warn)
	lg.circle("fill", markerX, y, 19)
	lg.setColor(Theme.outline.color)
	lg.circle("line", markerX, y, 19)
	Fonts.set("ui")
	lg.setColor(Theme.outline.color)
	lg.printf(tostring(State.mapIndex), markerX - 12, y - 9, 24, "center")
	lg.setLineWidth(1)

	local total = 0
	for _, map in ipairs(Maps) do
		local stats = statsFor(map.id)
		total = total + (stats and Medals.getCount(stats.completedDifficulty) or 0)
	end
	local badgeW = 150
	panel(l.sw - l.margin - badgeW, 15, badgeW, 51)
	-- The campaign total is medal progress, not a generic score. Show all three
	-- finishes here so the summary uses the same bronze/silver/gold language as
	-- the map rows and detail panel.
	Medals.draw(l.sw - l.margin - badgeW + 10, 31, 3, 9, 5)
	Fonts.set("menu")
	lg.setColor(Theme.ui.text)
	lg.printf(format("%d/%d", total, #Maps * 3), l.sw - l.margin - 68, 26, 62, "center")
end

local function drawMapList(l, pose, unlockPose)
	panel(l.left.x, l.left.y, l.left.w, l.left.h)
	local rowH, count = visibleRows(l)
	local rowX = l.left.x + 10
	local rowW = l.left.w - 31
	for visible = 1, count do
		local index = listOffset + visible
		local map = Maps[index]
		if not map then break end
		local y = l.left.y + 10 + (visible - 1) * rowH
		local selected = index == State.mapIndex
		local locked = isMapLocked(index)
		lg.setColor(selected and {Theme.ui.panel[1], Theme.ui.panel[2], Theme.ui.panel[3], 0.35} or Theme.ui.panel)
		lg.rectangle("fill", rowX, y, rowW, rowH - 7, 7)
		if unlockPose and index == unlockPose.targetIndex and unlockPose.row > 0 then
			lg.setColor(Theme.ui.good[1], Theme.ui.good[2], Theme.ui.good[3], 0.32 * unlockPose.row)
			lg.rectangle("fill", rowX, y, rowW, rowH - 7, 7)
		end
		local entry = MapPreviewCache.get(map.id)
		if entry then
			local scale = min(1, LIST_PREVIEW_W / entry.canvas:getWidth(), LIST_PREVIEW_H / entry.canvas:getHeight())
			lg.setColor(1, 1, 1, locked and 0.28 or 0.9)
			lg.draw(entry.canvas, rowX + 4, y + 5, 0, scale, scale)
		end
		local textX = rowX + LIST_PREVIEW_W + 12
		Fonts.set("ui")
		lg.setColor(Theme.ui.text)
		lg.print(index .. "  " .. L(map.nameKey), textX, y + 7)
		if locked then
			lg.setColor(Theme.ui.text[1], Theme.ui.text[2], Theme.ui.text[3], 0.55)
			lg.print(L("campaign.locked"), textX, y + 31)
		else
			local stats = statsFor(map.id)
			Medals.draw(textX, y + 31, stats and Medals.getCount(stats.completedDifficulty) or 0, 7, 6, pulseTime)
		end
	end
	-- The highlight travels independently of listOffset, so selecting a visible
	-- row never nudges the scroll viewport just to create the animation.
	local highlightY = l.left.y + 10 + (pose.rowIndex - listOffset - 1) * rowH
	lg.setColor(Theme.ui.selected)
	lg.setLineWidth(3)
	lg.rectangle("line", rowX, highlightY, rowW, rowH - 7, 7)
	lg.setLineWidth(1)

	local trackX, trackY, trackW, trackH, thumbY, thumbH = scrollbarGeometry(l)
	if trackX then
		lg.setColor(Theme.ui.text[1], Theme.ui.text[2], Theme.ui.text[3], 0.14)
		lg.rectangle("fill", trackX, trackY, trackW, trackH, 3)
		lg.setColor(scrollbarDragging and Theme.ui.warn or Theme.ui.selected)
		lg.rectangle("fill", trackX, thumbY, trackW, thumbH, 3)
	end
end

local function rewardDestination(l, count, index)
	local pad, w = 20, l.center.w - 40
	local cellW = w / math.max(1, count)
	return l.center.x + pad + (index - 0.5) * cellW, l.center.y + l.center.h - 48
end

local function drawUnlockRewards(l, event, pose)
	if not event then return end
	for index, reward in ipairs(event.rewards) do
		local rewardPose = pose.rewards[index]
		if rewardPose and rewardPose.visible then
			local targetX, targetY = rewardDestination(l, #event.rewards, index)
			local startX = l.left.x + l.left.w + 20
			local startY = l.headerH - 18
			local p = rewardPose.progress
			local x = startX + (targetX - startX) * p
			local y = startY + (targetY - startY) * p - math.sin(math.pi * p) * 54
			local scale = 1.35 - 0.35 * p
			lg.push("all")
			lg.translate(x, y)
			lg.scale(scale, scale)
			drawRewardIcon(reward, 0, 0)
			lg.pop()
		end
	end
end

local function drawCenter(l, map, mapIndex, entry)
	local pad = 20
	local x, y, w = l.center.x + pad, l.center.y + 18, l.center.w - pad * 2
	Fonts.set("title")
	lg.setColor(Theme.ui.text)
	lg.print(L(map.nameKey), x, y)
	Fonts.set("ui")
	lg.setColor(Theme.ui.text[1], Theme.ui.text[2], Theme.ui.text[3], 0.75)
	lg.print(L("campaign.mapOf", mapIndex, #Maps), x, y + 43)

	local stats = statsFor(map.id)
	local earned = stats and Medals.getCount(stats.completedDifficulty) or 0
	local clusterW = Medals.getClusterSize(13, 9)
	Medals.draw(x + w - clusterW, y + 5, earned, 13, 9, pulseTime)
	Fonts.set("ui")
	lg.setColor(Theme.ui.text[1], Theme.ui.text[2], Theme.ui.text[3], 0.65)
	lg.printf(L("campaign.bestMedals"), x + w - clusterW - 82, y + 12, 72, "right")

	local previewY = y + 70
	local maxPreviewH = max(120, floor(l.center.h * MAIN_PREVIEW_HEIGHT_RATIO))
	local scale = min(w / entry.canvas:getWidth(), maxPreviewH / entry.canvas:getHeight())
	local previewW, previewH = entry.canvas:getWidth() * scale, entry.canvas:getHeight() * scale
	local previewX = x + (w - previewW) * 0.5
	lg.setColor(1, 1, 1, isMapLocked(mapIndex) and 0.35 or 1)
	lg.draw(entry.canvas, previewX, previewY, 0, scale, scale)
	lg.setColor(Theme.outline.color)
	lg.setLineWidth(3)
	lg.rectangle("line", previewX, previewY, previewW, previewH, 7)
	lg.setLineWidth(1)

	local infoY = previewY + previewH + 12
	lg.setColor(Theme.ui.panel)
	lg.rectangle("fill", x, infoY, w, 52, 7)
	Fonts.set("ui")
	lg.setColor(Theme.ui.text)
	lg.printf(L("campaign.hints." .. map.id), x + 12, infoY + 8, w - 24, "left")

	local statY = infoY + 64
	local cellGap = 3
	local cellW = (w - cellGap * 4) / 5
	local def = Difficulty.defs[Save.data.settings.difficulty or "normal"] or Difficulty.defs.normal
	local values = {
		{L("campaign.waves"), tostring(CampaignWaveDefs.getFinalWave(map) or "—")},
		{L("campaign.enemies"), tostring(CampaignWaveDefs.getTotalEnemyCount(map) or "—")},
		{L("campaign.lives"), tostring(def.startLives)},
		{L("campaign.startingMoney"), format("$%d", def.startMoney)},
		{L("campaign.sellRefund"), format("%d%%", floor(def.sellRefund * 100 + 0.5))},
	}
	for i, item in ipairs(values) do
		local cellX = x + (i - 1) * (cellW + cellGap)
		lg.setColor(Theme.ui.panel)
		lg.rectangle("fill", cellX, statY, cellW, 55, 7)
		Fonts.set("ui")
		lg.setColor(Theme.ui.text[1], Theme.ui.text[2], Theme.ui.text[3], 0.65)
		lg.printf(item[1], cellX, statY + 5, cellW, "center")
		lg.setColor(Theme.ui.text)
		lg.printf(item[2], cellX, statY + 27, cellW, "center")
	end

	local rewardsY = statY + 67
	if rewardsY + 62 < l.center.y + l.center.h then
		lg.setColor(Theme.ui.panel)
		lg.rectangle("fill", x, rewardsY, w, 62, 7)
		lg.setColor(Theme.ui.text)
		lg.print(L("campaign.completionRewards"), x + 10, rewardsY + 5)

		local rewardCellY = rewardsY + 31
		local rewards = CampaignUnlocks.getRewardsForMap(map)
		if #rewards == 0 then
			lg.setColor(Theme.ui.text[1], Theme.ui.text[2], Theme.ui.text[3], 0.72)
			lg.printf(L("campaign.noUnlockReward"), x + 10, rewardCellY - 2, w - 20, "center")
		else
			Fonts.set("ui")
			local rewardCellW = w / #rewards
			for i, reward in ipairs(rewards) do
				local cellX = x + (i - 1) * rewardCellW
				local rewardText = reward.labelKey and L(reward.labelKey) or reward.label or reward.id
				local iconSize = 34
				local textW = Fonts.get():getWidth(rewardText)
				local contentW = min(rewardCellW - 12, iconSize + textW)
				local iconX = cellX + (rewardCellW - contentW) * 0.5 + iconSize * 0.5
				drawRewardIcon(reward, iconX, rewardCellY + 7)
				lg.setColor(Theme.ui.text)
				lg.printf(rewardText, iconX + iconSize * 0.5, rewardCellY - 2,
					max(0, cellX + rewardCellW - 6 - (iconX + iconSize * 0.5)), "left")
			end
		end
	end
end

local function drawRight(l, map)
	panel(l.right.x, l.right.y, l.right.w, l.right.h)
	local pad = 20
	local x, y, w = l.right.x + pad, l.right.y + 18, l.right.w - pad * 2
	Fonts.set("menu")
	lg.setColor(Theme.ui.text)
	lg.print(L("settings.difficulty"), x, y)
	Fonts.set("ui")
	lg.setColor(Theme.ui.text[1], Theme.ui.text[2], Theme.ui.text[3], 0.65)
	lg.print(L("campaign.difficultyDescription"), x, y + 31)
	local selected = Save.data.settings.difficulty or "normal"
	local cardY = y + 61
	for i, key in ipairs(DIFFICULTIES) do
		local cy = cardY + (i - 1) * 67
		local active = key == selected
		lg.setColor(active and Theme.ui.buttonSelected or Theme.ui.panel)
		lg.rectangle("fill", x, cy, w, 57, 7)
		lg.setColor(DIFFICULTY_COLORS[key])
		lg.circle("fill", x + 20, cy + 20, 10)
		lg.setColor(Theme.outline.color)
		lg.circle("fill", x + 17, cy + 18, 2)
		lg.circle("fill", x + 23, cy + 18, 2)
		Fonts.set("ui")
		lg.setColor(Theme.ui.text)
		lg.print(L("difficulty." .. key), x + 40, cy + 8)
		lg.setColor(Theme.ui.text[1], Theme.ui.text[2], Theme.ui.text[3], 0.62)
		lg.print(L(DIFFICULTY_HINTS[key]), x + 40, cy + 30)
	end

	local play = buttons.play
	play.x, play.y, play.w, play.h = x, l.right.y + l.right.h - 74, w, 52
	play.label = L("campaign.playMap") .. "  •  " .. L(map.nameKey) .. " - " .. L("difficulty." .. selected)
	play.enabled = not isMapLocked(State.mapIndex)
	Fonts.set("ui")
	Button.draw(play)
end

function Screen.load()
	buttons = {
		play = {id = "play", label = L("campaign.playMap"), onClick = playMap},
		back = {id = "back", label = L("menu.back"), w = 140, h = 42, onClick = goBack},
	}
end

function Screen.update(dt)
	pulseTime = pulseTime + dt
	Backdrop.update(dt)
	Medals.update(dt)
	selection.elapsed = min(SelectionTransition.DURATION, selection.elapsed + dt)
	UnlockPresentation.update(unlockSequence, dt)
	local l = layout()
	if scrollbarDragging then
		if love.mouse.isDown(1) then
			local _, my = love.mouse.getPosition()
			scrollToThumb(l, my - scrollbarGrabY)
		else
			scrollbarDragging = false
		end
	end
	buttons.back.x, buttons.back.y = l.left.x + 14, l.left.y + l.left.h - 56
	buttons.back.w = l.left.w - 28
	local rightPad = 20
	buttons.play.x = l.right.x + rightPad
	buttons.play.y = l.right.y + l.right.h - 74
	buttons.play.w = l.right.w - rightPad * 2
	buttons.play.h = 52
	buttons.play.enabled = not isMapLocked(State.mapIndex)
	local mx, my = love.mouse.getPosition()
	for _, button in pairs(buttons) do Button.update(button, mx, my, dt) end

	local map = Maps[State.mapIndex]
	local stats = statsFor(map.id)
	local count = stats and Medals.getCount(stats.completedDifficulty) or 0
	hoveredMedal = nil
	if count > 0 then
		-- Medal tooltips remain available in both the list and detail presentation.
		local step = 35
		local lcenter = l.center
		local clusterW = Medals.getClusterSize(13, 9)
		local startX = lcenter.x + lcenter.w - 20 - clusterW
		for tier = 1, count do
			if mx >= startX + (tier - 1) * step and mx <= startX + (tier - 1) * step + 26
				and my >= lcenter.y + 23 and my <= lcenter.y + 49 then hoveredMedal = tier end
		end
	end
	if hoveredMedal then
		local key = DIFFICULTIES[hoveredMedal]
		local timestamp = stats.medalEarnedAt and stats.medalEarnedAt[key]
		local date = type(timestamp) == "number" and os.date(L("campaign.medalDateFormat"), timestamp)
			or L("campaign.medalDateUnavailable")
		Tooltip.show({title = L("campaign.medalTooltipTitle", L("campaign.medals." .. MEDAL_NAMES[hoveredMedal]), L("difficulty." .. key)), rows = {{label = L("campaign.medalEarnedOn"), value = date}}})
	else Tooltip.hide() end
end

function Screen.draw()
	Backdrop.draw()
	local l = layout()
	lg.setColor(Theme.ui.screenDim)
	lg.rectangle("fill", 0, 0, l.sw, l.sh)
	local pose = selectionPose()
	local unlockEvent = unlockSequence.active
	local unlockPose = UnlockPresentation.sample(unlockEvent)
	drawHeader(l, pose, unlockEvent and unlockPose)
	drawMapList(l, pose, unlockEvent and unlockPose)
	panel(l.center.x, l.center.y, l.center.w, l.center.h)
	local map = Maps[State.mapIndex]
	local entry = MapPreviewCache.get(map.id)
	if entry then drawCenter(l, map, State.mapIndex, entry) end
	drawRight(l, map)
	drawUnlockRewards(l, unlockEvent, unlockPose)

	buttons.back.x, buttons.back.y = l.left.x + 14, l.left.y + l.left.h - 56
	buttons.back.w = l.left.w - 28
	Fonts.set("ui")
	Button.draw(buttons.back)
end

function Screen.keypressed(key)
	if key == "left" then navigate(-1)
	elseif key == "right" then navigate(1)
	elseif key == "up" or key == "down" then
		local direction = key == "up" and -1 or 1
		local i = difficultyIndex(Save.data.settings.difficulty or "normal")
		selectDifficulty(DIFFICULTIES[((i - 1 + direction) % #DIFFICULTIES) + 1])
	elseif key == "return" or key == "kpenter" or key == "space" then playMap()
	elseif key == "escape" then goBack() end
end

function Screen.gamepadpressed(_, button)
	local key = ({dpup = "up", dpdown = "down", dpleft = "left", dpright = "right", a = "return", b = "escape"})[button]
	if key then Screen.keypressed(key); return true end
end

function Screen.mousepressed(x, y, button)
	if button ~= 1 then return end
	local l = layout()
	local trackX, trackY, trackW, trackH, thumbY, thumbH = scrollbarGeometry(l)
	if trackX and x >= trackX - 4 and x <= trackX + trackW + 4
		and y >= trackY and y <= trackY + trackH then
		if y >= thumbY and y <= thumbY + thumbH then
			scrollbarGrabY = y - thumbY
		else
			scrollbarGrabY = thumbH * 0.5
			scrollToThumb(l, y - scrollbarGrabY)
		end
		scrollbarDragging = true
		return true
	end
	local rowH, count = visibleRows(l)
	if x >= l.left.x + 10 and x <= l.left.x + l.left.w - 21 and y >= l.left.y + 10 then
		local row = floor((y - l.left.y - 10) / rowH) + 1
		if row >= 1 and row <= count then
			local index = listOffset + row
			if Maps[index] and not isMapLocked(index) then selectMap(index); Sound.play("uiMove"); return true end
		end
	end
	local dx, dy, dw = l.right.x + 20, l.right.y + 79, l.right.w - 40
	for i, key in ipairs(DIFFICULTIES) do
		local cy = dy + (i - 1) * 67
		if x >= dx and x <= dx + dw and y >= cy and y <= cy + 57 then selectDifficulty(key); return true end
	end
	for _, item in pairs(buttons) do if Button.mousepressed(item, x, y, button) then return true end end
end

function Screen.mousereleased(x, y, button)
	if button == 1 and scrollbarDragging then
		scrollbarDragging = false
		return true
	end
	for _, item in pairs(buttons) do if Button.mousereleased(item, x, y, button) then return true end end
end

function Screen.wheelmoved(_, y)
	local l = layout()
	local mx = love.mouse.getPosition()
	if mx >= l.left.x and mx <= l.left.x + l.left.w then
		local _, count = visibleRows(l)
		listOffset = max(0, min(listOffset - y, max(0, #Maps - count)))
		return true
	end
end

function Screen.resize()
	Tooltip.hide()
	MapPreviewCache.buildAll(520, 312)
	Backdrop.start()
	keepSelectedVisible(layout())
end

function Screen.enter()
	local captured = UnlockPresentation.capture(unlockSequence, State, #Maps, reducedMotion())
	if captured then
		-- Keep the cleared map selected so earned reward icons settle into that
		-- map's authored reward detail while the route itself reveals the next map.
		State.mapIndex = State.resolveMapIndex(captured.sourceIndex)
	end
	selection.fromIndex, selection.toIndex = State.mapIndex, State.mapIndex
	selection.elapsed = SelectionTransition.DURATION
	keepSelectedVisible(layout())
end
function Screen.leave() Tooltip.hide() end

return Screen
