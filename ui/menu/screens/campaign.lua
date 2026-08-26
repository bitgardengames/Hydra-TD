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
local RunModes = require("systems.run_modes")
local DrawEntities = require("render.draw_entities")
local AbilityIcons = require("ui.ability_icons")
local AbilityTooltip = require("ui.ability_tooltip")
local AbilityDefs = require("systems.ability_defs")
local Hotkeys = require("core.hotkeys")
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
local buttons = {}
local pulseTime = 0
local hoveredMedal
local hoveredAbilitySlot
local hoveredAbilityChoice
local selectedAbilitySlot
local abilitySlotTooltips = {}
local listOffset = 0
local scrollbarDragging = false
local scrollbarGrabY = 0
local selection = {fromIndex = State.mapIndex, toIndex = State.mapIndex, elapsed = SelectionTransition.DURATION}
local unlockSequence = UnlockPresentation.new()

-- Campaign layout uses a small set of shared spacing tokens. Keeping the list,
-- preview, difficulty cards, and actions on the same rhythm is especially
-- important here because both columns read as one surface.
local SPACE = 12
local PANEL_PAD = 28
local SECTION_INSET = 28
local LIST_ROW_H = 80
local LIST_ROW_STEP = LIST_ROW_H + SPACE
local LIST_HEADER_H = 49
local LIST_PREVIEW_W = 118
local LIST_PREVIEW_H = 68
local MAIN_PREVIEW_HEIGHT_RATIO = 0.82
local DIFFICULTY_CARD_H = 52
local ABILITY_SLOT_COUNT = 2
local ABILITY_CARD_GAP = 18
local ABILITY_CARD_SIZE = 140
local ABILITY_PICKER_W = 520
local ABILITY_PICKER_PAD = 20
local ABILITY_PICKER_ITEM_H = 72
local ABILITY_PICKER_GAP = 10
local CAMPAIGN_CARD_MAX_W = 1168
local CAMPAIGN_CARD_MAX_H = 734
local BUTTON_BOTTOM_GAP = 30
local BACK_BUTTON_H = 68
local PLAY_BUTTON_H = 108
local DIFFICULTY_PLAY_GAP = 26

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

local function hoveredMapReward(l, map, entry, mx, my)
	if not entry then return nil end

	local pad = 20
	local x, y, w = l.center.x + pad, l.center.y + 38, l.center.w - pad * 2
	local previewY = y + 88
	local maxPreviewH = max(120, floor(l.center.h * MAIN_PREVIEW_HEIGHT_RATIO))
	local scale = min(w / entry.canvas:getWidth(), maxPreviewH / entry.canvas:getHeight())
	local previewH = entry.canvas:getHeight() * scale
	local statY = previewY + previewH + 18
	local rewardsY = statY + 67
	if rewardsY + 62 >= l.center.y + l.center.h then return nil end

	local rewards = CampaignUnlocks.getRewardsForMap(map)
	-- The heading describes the section; only the reward cells themselves expose
	-- item-specific details.
	if #rewards == 0 or mx < x or mx > x + w or my < rewardsY + 25 or my > rewardsY + 62 then
		return nil
	end
	local index = min(#rewards, floor((mx - x) / (w / #rewards)) + 1)
	return rewards[index]
end

local function layout()
	local sw, sh = lg.getDimensions()
	local margin = max(18, floor(sw * 0.024))
	local headerH = max(96, floor(sh * 0.115))
	local footerH = max(46, floor(sh * 0.06))
	local gap = 0
	local contentY = headerH
	-- Cap the campaign card so its controls stay grouped instead of leaving an
	-- empty strip beneath the map selection content on taller windows.
	local contentH = min(CAMPAIGN_CARD_MAX_H, sh - headerH - footerH)
	local contentW = min(CAMPAIGN_CARD_MAX_W, sw - margin * 2)
	local contentX = floor((sw - contentW) * 0.5)
	local leftW = floor(contentW * 0.347)
	local centerW = contentW - gap - leftW
	return {
		sw = sw, sh = sh, margin = margin, headerH = headerH, footerH = footerH,
		gap = gap, contentY = contentY, contentH = contentH,
		left = {x = contentX, y = contentY, w = leftW, h = contentH},
		center = {x = contentX + leftW + gap, y = contentY, w = centerW, h = contentH},
	}
end

local function visibleRows(l)
	local listH = l.left.h - SECTION_INSET - LIST_HEADER_H - BUTTON_BOTTOM_GAP - BACK_BUTTON_H - SPACE
	return LIST_ROW_STEP, max(1, floor((listH + SPACE) / LIST_ROW_STEP))
end

local function scrollbarGeometry(l)
	local _, count = visibleRows(l)
	if #Maps <= count then return nil end
	local trackX = l.left.x + l.left.w - 13
	local trackY = l.left.y + SECTION_INSET + LIST_HEADER_H
	local trackH = l.left.h - SECTION_INSET - LIST_HEADER_H - BUTTON_BOTTOM_GAP - BACK_BUTTON_H - SPACE
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

	-- Let the route read as a page-level campaign progress bar. Starting it
	-- above the map list (rather than above the detail column) matches the wide
	-- visual rhythm of the campaign header while leaving the title unobstructed.
	local startX = max(l.margin + 390, l.left.x + 284)
	local endX = min(l.sw - l.margin - 190, l.center.x + l.center.w - 210)
	local available = endX - startX
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
		Text.printfShadow(locked and "•" or tostring(i), x - 12, y - 9, 24, "center")
	end
	if unlockPose and unlockPose.stamp > 0 then
		local x = startX + (unlockPose.targetIndex - 1) * step
		lg.setColor(Theme.ui.good[1], Theme.ui.good[2], Theme.ui.good[3], 0.8 * unlockPose.stamp)
		lg.setLineWidth(3)
		lg.circle("line", x, y, 18 + 13 * unlockPose.stamp)
	end
	local markerX = startX + (pose.markerIndex - 1) * step
	lg.setColor(Theme.ui.buttonHover)
	lg.circle("fill", markerX, y, 19)
	lg.setColor(Theme.outline.color)
	lg.circle("line", markerX, y, 19)
	Fonts.set("ui")
	lg.setColor(Theme.outline.color)
	Text.printfShadow(tostring(State.mapIndex), markerX - 12, y - 9, 24, "center")
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
	Text.printfShadow(format("%d/%d", total, #Maps * 3), l.sw - l.margin - 68, 26, 62, "center")
end

local function drawMapList(l, unlockPose)
	local rowH, count = visibleRows(l)
	local rowX = l.left.x + PANEL_PAD
	local rowW = l.left.w - PANEL_PAD * 2
	Fonts.set("menu")
	lg.setColor(Theme.ui.text)
	Text.printShadow(L("campaign.maps"), rowX, l.left.y + SECTION_INSET - 4)
	for visible = 1, count do
		local index = listOffset + visible
		local map = Maps[index]
		if not map then break end
		local y = l.left.y + SECTION_INSET + LIST_HEADER_H + (visible - 1) * rowH
		local selected = index == State.mapIndex
		local locked = isMapLocked(index)
		lg.setColor(selected and Theme.ui.buttonHover or Theme.ui.panel)
		lg.rectangle("fill", rowX, y, rowW, LIST_ROW_H, 7)
		if unlockPose and index == unlockPose.targetIndex and unlockPose.row > 0 then
			lg.setColor(Theme.ui.good[1], Theme.ui.good[2], Theme.ui.good[3], 0.32 * unlockPose.row)
			lg.rectangle("fill", rowX, y, rowW, LIST_ROW_H, 7)
		end
		local entry = MapPreviewCache.get(map.id)
		if entry then
			local scaleX = LIST_PREVIEW_W / entry.canvas:getWidth()
			local scaleY = LIST_PREVIEW_H / entry.canvas:getHeight()
			lg.setColor(1, 1, 1, locked and 0.28 or 0.9)
			lg.draw(entry.canvas, rowX + 4, y + 5, 0, scaleX, scaleY)
		end
		local textX = rowX + LIST_PREVIEW_W + 12
		Fonts.set("ui")
		lg.setColor(Theme.ui.text)
		Text.printShadow(index .. "  " .. L(map.nameKey), textX, y + 4)
		if locked then
			lg.setColor(Theme.ui.text[1], Theme.ui.text[2], Theme.ui.text[3], 0.55)
			Text.printShadow(L("campaign.locked"), textX, y + 27)
		else
			local stats = statsFor(map.id)
			Medals.draw(textX, y + 27, stats and Medals.getCount(stats.completedDifficulty) or 0, 7, 6, pulseTime)
		end
	end
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

local function drawAbilityCard(x, y, w, h, slot, abilityId, unlocked, hovered)
	local alpha = abilityId and (hovered and 0.28 or 0.18) or 0.10
	lg.setColor(Theme.ui.text[1], Theme.ui.text[2], Theme.ui.text[3], alpha)
	lg.rectangle(abilityId and "fill" or "line", x, y, w, h, 9)
	lg.setColor(hovered and Theme.ui.selected or Theme.outline.color)
	lg.setLineWidth(hovered and 3 or 2)
	lg.rectangle("line", x, y, w, h, 9)
	lg.setLineWidth(1)

	if abilityId and AbilityDefs[abilityId] then
		local binding = Hotkeys.getDisplay("abilitySlot" .. slot)
		if binding then
			lg.setColor(Theme.ui.button)
			lg.rectangle("fill", x + 12, y + 10, 34, 34, 5)
			Fonts.set("ui")
			lg.setColor(Theme.ui.text)
			Text.printfShadow(binding, x + 12, y + 17, 34, "center")
		end
		AbilityIcons.draw(abilityId, x + w * 0.5, y + 63, hovered and 1.34 or 1.25, 1)
		Fonts.set("ui")
		lg.setColor(Theme.ui.text)
		Text.printfShadow(L(AbilityDefs[abilityId].nameKey), x + 8, y + h - 34, w - 16, "center")
	else
		Fonts.set("title")
		lg.setColor(Theme.ui.text[1], Theme.ui.text[2], Theme.ui.text[3], 0.62)
		Text.printfShadow(unlocked and "+" or "-", x, y + 30, w, "center")
		Fonts.set("ui")
		Text.printfShadow(L(unlocked and "campaign.selectAbility" or "campaign.locked"),
			x + 8, y + h - 39, w - 16, "center")
	end
end

local function showAbilitySlotTooltip(slot, abilityId)
	if abilityId then
		AbilityTooltip.show(abilityId)
		return
	end

	local unlocked = CampaignUnlocks.isAbilitySlotUnlocked(slot)
	local title = L(unlocked and "campaign.selectAbility" or "abilityUnlock.slotLocked")
	local tooltip = abilitySlotTooltips[slot]
	if not tooltip or tooltip.title ~= title then
		tooltip = {title = title, rows = {}}
		abilitySlotTooltips[slot] = tooltip
	end
	Tooltip.show(tooltip)
end

local function abilityCardGeometry(l, entry, slot)
	if not entry then return nil end
	local pad = 20
	local x, y, w = l.center.x + pad, l.center.y + SECTION_INSET, l.center.w - pad * 2
	local previewY = y + 77
	local maxPreviewH = max(120, floor(l.center.h * MAIN_PREVIEW_HEIGHT_RATIO))
	local scale = min(w / entry.canvas:getWidth(), maxPreviewH / entry.canvas:getHeight())
	local abilitiesY = previewY + entry.canvas:getHeight() * scale + 21
	local cardY = abilitiesY + 36
	local cardsW = ABILITY_CARD_SIZE * ABILITY_SLOT_COUNT + ABILITY_CARD_GAP * (ABILITY_SLOT_COUNT - 1)
	local cardsX = x + (w - cardsW) * 0.5
	return cardsX + (slot - 1) * (ABILITY_CARD_SIZE + ABILITY_CARD_GAP), cardY,
		ABILITY_CARD_SIZE, ABILITY_CARD_SIZE
end

local function availableAbilities()
	local abilities = {}
	for _, abilityId in ipairs(AbilityDefs.order) do
		if CampaignUnlocks.isAbilityUnlocked(abilityId) then abilities[#abilities + 1] = abilityId end
	end
	return abilities
end

local function abilityPickerGeometry(l)
	local abilities = availableAbilities()
	local rows = math.max(1, math.ceil(#abilities / 2))
	local h = 58 + rows * ABILITY_PICKER_ITEM_H + math.max(0, rows - 1) * ABILITY_PICKER_GAP + ABILITY_PICKER_PAD
	return floor(l.center.x + (l.center.w - ABILITY_PICKER_W) * 0.5),
		floor(l.center.y + (l.center.h - h) * 0.5), ABILITY_PICKER_W, h, abilities
end

local function abilityChoiceGeometry(l, index)
	local x, y, w = abilityPickerGeometry(l)
	local itemW = (w - ABILITY_PICKER_PAD * 2 - ABILITY_PICKER_GAP) * 0.5
	local column = (index - 1) % 2
	local row = floor((index - 1) / 2)
	return x + ABILITY_PICKER_PAD + column * (itemW + ABILITY_PICKER_GAP),
		y + 58 + row * (ABILITY_PICKER_ITEM_H + ABILITY_PICKER_GAP), itemW, ABILITY_PICKER_ITEM_H
end

local function equipAbility(abilityId)
	if not selectedAbilitySlot or not CampaignUnlocks.isAbilityUnlocked(abilityId) then return end
	local equipped = CampaignUnlocks.getEquippedAbilities()
	for slot, equippedId in ipairs(equipped) do
		if equippedId == abilityId and slot ~= selectedAbilitySlot then
			Sound.play("uiError")
			return
		end
	end
	equipped[selectedAbilitySlot] = abilityId
	Save.setEquippedAbilities(equipped)
	selectedAbilitySlot = nil
	hoveredAbilityChoice = nil
	Sound.play("uiConfirm")
end

local function drawAbilityPicker(l)
	if not selectedAbilitySlot then return end
	local x, y, w, h, abilities = abilityPickerGeometry(l)
	lg.setColor(Theme.ui.screenDim)
	lg.rectangle("fill", l.center.x + 2, l.center.y + 2, l.center.w - 4, l.center.h - 4)
	panel(x, y, w, h, true)
	Fonts.set("menu")
	lg.setColor(Theme.ui.text)
	Text.printShadow(L("campaign.selectAbility"), x + ABILITY_PICKER_PAD, y + 17)

	local equipped = CampaignUnlocks.getEquippedAbilities()
	for index, abilityId in ipairs(abilities) do
		local ix, iy, iw, ih = abilityChoiceGeometry(l, index)
		local equippedSlot
		for slot, equippedId in ipairs(equipped) do
			if equippedId == abilityId then equippedSlot = slot; break end
		end
		local unavailable = equippedSlot and equippedSlot ~= selectedAbilitySlot
		local hovered = hoveredAbilityChoice == index
		lg.setColor(unavailable and Theme.ui.buttonDisabled or hovered and Theme.ui.buttonHover or Theme.ui.button)
		lg.rectangle("fill", ix, iy, iw, ih, 8)
		lg.setColor(hovered and Theme.ui.selected or Theme.outline.color)
		lg.setLineWidth(hovered and 3 or 2)
		lg.rectangle("line", ix, iy, iw, ih, 8)
		lg.setLineWidth(1)
		AbilityIcons.draw(abilityId, ix + 37, iy + ih * 0.5, hovered and 1.06 or 1, unavailable and 0.45 or 1)
		Fonts.set("ui")
		lg.setColor(unavailable and Theme.ui.warn or Theme.ui.text)
		Text.printShadow(L(AbilityDefs[abilityId].nameKey), ix + 70, iy + 15)
		if unavailable then
			Fonts.set("version")
			Text.printShadow(L("campaign.abilityEquippedInSlot", equippedSlot), ix + 70, iy + 42)
		end
	end
end

local function drawCenter(l, map, mapIndex, entry)
	local pad = PANEL_PAD
	local x, y, w = l.center.x + pad + 8, l.center.y + SECTION_INSET, l.center.w - pad * 2 - 8
	Fonts.set("title")
	lg.setColor(Theme.ui.text)
	Text.printShadow(L(map.nameKey), x, y)
	Fonts.set("ui")
	lg.setColor(Theme.ui.text[1], Theme.ui.text[2], Theme.ui.text[3], 0.75)
	Text.printShadow(L("campaign.mapOf", mapIndex, #Maps), x, y + 38)

	local stats = statsFor(map.id)
	local earned = stats and Medals.getCount(stats.completedDifficulty) or 0
	local clusterW = Medals.getClusterSize(13, 9)
	Medals.draw(x + w - clusterW, y + 5, earned, 13, 9, pulseTime)
	Fonts.set("ui")
	lg.setColor(Theme.ui.text[1], Theme.ui.text[2], Theme.ui.text[3], 0.65)
	Text.printfShadow(L("campaign.bestMedals"), x + w - clusterW - 82, y + 12, 72, "right")

	local previewY = y + 70
	local maxPreviewH = max(120, l.center.h - (previewY - l.center.y) - 190)
	local scale = min(w / entry.canvas:getWidth(), maxPreviewH / entry.canvas:getHeight())
	local previewW, previewH = entry.canvas:getWidth() * scale, entry.canvas:getHeight() * scale
	local previewX = x + (w - previewW) * 0.5
	lg.setColor(1, 1, 1, isMapLocked(mapIndex) and 0.35 or 1)
	lg.draw(entry.canvas, previewX, previewY, 0, scale, scale)
	lg.setColor(Theme.outline.color)
	lg.setLineWidth(3)
	lg.rectangle("line", previewX, previewY, previewW, previewH, 7)
	lg.setLineWidth(1)

end

local function difficultyGeometry(l)
	local x = l.center.x + PANEL_PAD + 8
	local w = l.center.w - PANEL_PAD * 2 - 8
	local playY = l.center.y + l.center.h - BUTTON_BOTTOM_GAP - PLAY_BUTTON_H
	local cardY = playY - DIFFICULTY_PLAY_GAP - DIFFICULTY_CARD_H
	local labelW = 118
	return x, cardY, w, labelW, playY
end

local function drawRight(l, map)
	local x, cardY, w, labelW, playY = difficultyGeometry(l)
	lg.setColor(Theme.ui.text[1], Theme.ui.text[2], Theme.ui.text[3], 0.12)
	lg.rectangle("fill", x, cardY - 18, w, 2)
	Fonts.set("menu")
	lg.setColor(Theme.ui.text)
	Text.printShadow(L("settings.difficulty"), x, cardY + 10)
	local selected = Save.data.settings.difficulty or "normal"
	local choicesX = x + labelW
	local cardW = (w - labelW - SPACE * 2) / 3
	for i, key in ipairs(DIFFICULTIES) do
		local cx = choicesX + (i - 1) * (cardW + SPACE)
		local active = key == selected
		lg.setColor(active and Theme.ui.buttonHover or Theme.ui.panel)
		lg.rectangle("fill", cx, cardY, cardW, DIFFICULTY_CARD_H, 8)
		Fonts.set("ui")
		lg.setColor(active and Theme.ui.text or DIFFICULTY_COLORS[key])
		Text.printfShadow(L("difficulty." .. key), cx, cardY + 14, cardW, "center")
	end

	local play = buttons.play
	play.x, play.y, play.w, play.h = x, playY, w, PLAY_BUTTON_H
	play.label = L("campaign.playMap") .. "\n" .. L(map.nameKey) .. "  •  " .. L("difficulty." .. selected)
	play.enabled = not isMapLocked(State.mapIndex)
	Fonts.set("ui")
	Button.draw(play)
end

function Screen.load()
	buttons = {
		play = {id = "play", label = L("campaign.playMap"), onClick = playMap},
		back = {id = "back", label = L("menu.back"), w = 140, h = BACK_BUTTON_H, onClick = goBack},
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
	buttons.back.x, buttons.back.y = l.left.x + PANEL_PAD,
		l.left.y + l.left.h - BUTTON_BOTTOM_GAP - BACK_BUTTON_H
	buttons.back.w = l.left.w - PANEL_PAD * 2
	local playX, _cardY, playW, _labelW, playY = difficultyGeometry(l)
	buttons.play.x, buttons.play.y, buttons.play.w = playX, playY, playW
	buttons.play.h = PLAY_BUTTON_H
	buttons.play.enabled = not isMapLocked(State.mapIndex)
	local mx, my = love.mouse.getPosition()
	for _, button in pairs(buttons) do Button.update(button, mx, my, dt) end

	local map = Maps[State.mapIndex]
	local entry = MapPreviewCache.get(map.id)
	local hoveredReward = hoveredMapReward(l, map, entry, mx, my)
	hoveredAbilitySlot = nil
	hoveredAbilityChoice = nil
	selectedAbilitySlot = nil
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
	if hoveredReward and hoveredReward.type == "ability" then
		AbilityTooltip.show(hoveredReward.id)
	elseif hoveredMedal then
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
	-- One continuous campaign surface keeps the list and map detail aligned. A
	-- subtle divider establishes the two-column hierarchy without introducing
	-- competing nested panel outlines.
	panel(l.left.x, l.left.y, l.left.w + l.center.w, l.left.h)
	lg.setColor(Theme.ui.text[1], Theme.ui.text[2], Theme.ui.text[3], 0.10)
	lg.rectangle("fill", l.center.x, l.contentY + SECTION_INSET, 2, l.contentH - SECTION_INSET * 2)
	drawMapList(l, unlockEvent and unlockPose)
	local map = Maps[State.mapIndex]
	local entry = MapPreviewCache.get(map.id)
	if entry then drawCenter(l, map, State.mapIndex, entry) end
	drawRight(l, map)
	drawUnlockRewards(l, unlockEvent, unlockPose)

	buttons.back.x, buttons.back.y = l.left.x + PANEL_PAD,
		l.left.y + l.left.h - BUTTON_BOTTOM_GAP - BACK_BUTTON_H
	buttons.back.w = l.left.w - PANEL_PAD * 2
	Fonts.set("ui")
	Button.draw(buttons.back)
end

function Screen.keypressed(key)
	if selectedAbilitySlot then
		if key == "escape" then
			selectedAbilitySlot = nil
			Sound.play("uiBack")
		end
		return
	end
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
	if selectedAbilitySlot then
		local px, py, pw, ph, abilities = abilityPickerGeometry(l)
		for index, abilityId in ipairs(abilities) do
			local ix, iy, iw, ih = abilityChoiceGeometry(l, index)
			if x >= ix and x <= ix + iw and y >= iy and y <= iy + ih then
				equipAbility(abilityId)
				return true
			end
		end
		if x < px or x > px + pw or y < py or y > py + ph then
			selectedAbilitySlot = nil
			Sound.play("uiBack")
		end
		return true
	end
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
	if x >= l.left.x + PANEL_PAD and x <= l.left.x + l.left.w - PANEL_PAD and y >= l.left.y + SECTION_INSET + LIST_HEADER_H then
		local row = floor((y - l.left.y - SECTION_INSET - LIST_HEADER_H) / rowH) + 1
		if row >= 1 and row <= count then
			local index = listOffset + row
			local rowY = l.left.y + SECTION_INSET + LIST_HEADER_H + (row - 1) * rowH
			if y <= rowY + LIST_ROW_H and Maps[index] and not isMapLocked(index) then
				selectMap(index); Sound.play("uiMove"); return true
			end
		end
	end
	local dx, dy, dw, labelW = difficultyGeometry(l)
	local choicesX = dx + labelW
	local cardW = (dw - labelW - SPACE * 2) / 3
	for i, key in ipairs(DIFFICULTIES) do
		local cx = choicesX + (i - 1) * (cardW + SPACE)
		if x >= cx and x <= cx + cardW and y >= dy and y <= dy + DIFFICULTY_CARD_H then selectDifficulty(key); return true end
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
	MapPreviewCache.buildAll(660, 312)
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
function Screen.leave()
	selectedAbilitySlot = nil
	hoveredAbilityChoice = nil
	Tooltip.hide()
end

return Screen
