local Theme = require("core.theme")
local Constants = require("core.constants")
local Button = require("ui.button")
local State = require("core.state")
local Sound = require("systems.sound")
local Difficulty = require("systems.difficulty")
local Text = require("ui.text")
local Fonts = require("core.fonts")
local Maps = require("world.map_defs")
local Medals = require("ui.medals")
local Backdrop = require("scenes.backdrop")
local Steam = require("core.steam")
local Save = require("core.save")
local L = require("core.localization")
local TowerDefs = require("world.tower_defs")
local AbilityDefs = require("systems.ability_defs")
local CampaignUnlocks = require("systems.campaign_unlocks")
local GameplayOutcome = require("systems.gameplay_outcome")
local DrawEntities = require("render.draw_entities")
local RunRecap = require("ui.run_recap")
local ScrollView = require("ui.scroll_view")
local AbilityIcons = require("ui.ability_icons")
local Tooltip = require("ui.tooltip")

local Overlay = require("ui.overlay")
local DemoComplete = require("ui.overlays.demo_complete")

local lg = love.graphics
local min = math.min
local floor = math.floor
local max = math.max
local format = string.format
local sin = math.sin
local random = love.math.random

local Screen = {}

local buttons = nil
local previousMedalCount = 0
local currentMedalCount = 0
local confetti = {}
local t = 0
local panelT = 0
local recapScroll = ScrollView.new()
local layout = nil
local rewardCardT = 0
local rewardCards = {}
local rewardCardIndex = 1
local rewardClosePressed = false
local rewardActionPressed = nil
local hoveredMedalTier = nil
local medalHoverScales = {1, 1, 1}
local isFinalCampaignMap = false
local unlockedFinalChallenge = false

-- Colors
local colorGood = Theme.ui.good
local colorText = Theme.ui.text
local colorBackdrop = Theme.ui.backdrop
local colorDim = Theme.ui.screenDim
local colorOutline = Theme.outline.color

-- Layout
local outlineW = Theme.outline.width
local baseRadius = 6 * 3
local outerRadius = baseRadius + outlineW * 0.5
local innerRadius = baseRadius - outlineW * 0.25

local paddingX = 28
local paddingY = 30

local btnW = 240
local btnH = 42
local panelW = 560
local rewardCardW = 420
local rewardCardH = 220
local rewardInputDelay = 0.3
local rewardCloseSize = 32
local rewardActionH = 34

local difficultyOffset = 22

-- Medal visuals
local medalR = 16
local medalGap = 14
local medalHoverScale = 1.08
local medalHoverSpeed = 14
local DIFFICULTY_ORDER = {"easy", "normal", "hard"}
local MEDAL_NAMES = {"bronze", "silver", "gold"}
local confettiColors = {
	Theme.ui.good,
	Theme.ui.wave,
	Theme.ui.money,
	Theme.medal.gold,
	Theme.medal.silver,
}


local function easeOutBack(x)
	local c1 = 1.70158
	local c3 = c1 + 1
	return 1 + c3 * ((x - 1) ^ 3) + c1 * ((x - 1) ^ 2)
end

local function hideMedalTooltip()
	hoveredMedalTier = nil
	Tooltip.hide()
end

local function updateMedalTooltip()
	if #rewardCards > 0 or not layout then
		hideMedalTooltip()
		return
	end

	local map = Maps[State.mapIndex]
	local mapStats = map and Save.data.mapStats and Save.data.mapStats[map.id]
	local earnedCount = mapStats and mapStats.completedDifficulty
		and Medals.getCount(mapStats.completedDifficulty) or 0
	local clusterW = Medals.getClusterSize(medalR, medalGap)
	local medalX = layout.cx - clusterW * 0.5
	local medalY = layout.recapY - recapScroll.offset + layout.medalY
	local mx, my = love.mouse.getPosition()
	local step = medalR * 2 + medalGap

	-- Match the campaign medal hit areas, while respecting the recap's clip.
	if my < layout.recapY or my > layout.recapY + layout.recapH then
		hideMedalTooltip()
		return
	end

	for tier = 1, earnedCount do
		local x = medalX + (tier - 1) * step
		if mx >= x and mx <= x + medalR * 2
			and my >= medalY and my <= medalY + medalR * 2 then
			hoveredMedalTier = tier
			local difficultyKey = DIFFICULTY_ORDER[tier]
			local timestamp = mapStats.medalEarnedAt and mapStats.medalEarnedAt[difficultyKey]
			local earnedDate = L("campaign.medalDateUnavailable")
			if type(timestamp) == "number" then
				earnedDate = os.date(L("campaign.medalDateFormat"), timestamp)
			end

			Tooltip.show({
				title = L("campaign.medalTooltipTitle", L("campaign.medals." .. MEDAL_NAMES[tier]), L("difficulty." .. difficultyKey)),
				rows = {{label = L("campaign.medalEarnedOn"), value = earnedDate}},
			})
			return
		end
	end

	hideMedalTooltip()
end

local function buildRewardCards()
	rewardCards = {}

	for _, kind in ipairs(State.unlockedTowersThisVictory or {}) do
		local def = TowerDefs[kind]
		rewardCards[#rewardCards + 1] = {
			type = "tower",
			id = kind,
			name = L((def and def.nameKey) or ("tower." .. kind)),
			description = L("victory.rewardDescriptions.tower"),
			color = (def and def.color) or Theme.ui.good,
		}
	end

	for _, abilityId in ipairs(State.unlockedAbilitiesThisVictory or {}) do
		local def = AbilityDefs[abilityId]
		rewardCards[#rewardCards + 1] = {
			type = "ability",
			id = abilityId,
			name = L((def and def.nameKey) or ("ability." .. abilityId .. ".name")),
			description = L("victory.rewardDescriptions.ability"),
			color = Theme.ui.selected,
		}
	end

	for _, reward in ipairs(State.unlockedRewardsThisVictory or {}) do
		if reward.type ~= "tower" and reward.type ~= "ability" then
			rewardCards[#rewardCards + 1] = {
				type = reward.type,
				id = reward.id,
				name = reward.labelKey and L(reward.labelKey) or reward.label or reward.id,
				description = L("victory.rewardDescriptions." .. reward.type),
				color = Theme.ui.good,
			}
		end
	end
	rewardCardIndex = 1
end

local function hasNewFinalChallengeReward()
	for _, reward in ipairs(State.unlockedRewardsThisVictory or {}) do
		if reward.type == "campaign_complete" and reward.id == "challenge_endless" then
			return true
		end
	end
	return false
end

local function rewardCardBlockingInput()
	return #rewardCards > 0 and rewardCardT < rewardInputDelay
end

local function getRewardCardBounds(g)
	local w = min(rewardCardW, g.sw - 36)
	local h = rewardCardH
	local x = (g.sw - w) * 0.5
	local y = max(18, g.boxY + 24)
	return x, y, w, h
end

local function pointInRewardClose(x, y)
	if #rewardCards <= 0 or not layout then return false end
	local cardX, cardY, cardW = getRewardCardBounds(layout)
	local closeX = cardX + cardW - rewardCloseSize - 10
	local closeY = cardY + 10
	return x >= closeX and x <= closeX + rewardCloseSize
		and y >= closeY and y <= closeY + rewardCloseSize
end

local function closeRewardCard()
	table.remove(rewardCards, rewardCardIndex)
	rewardCardIndex = min(rewardCardIndex, max(1, #rewardCards))
	rewardCardT = 0
	rewardClosePressed = false
	rewardActionPressed = nil
	Sound.play("uiBack")
end

local function finishRewardCards()
	rewardCards = {}
	rewardCardIndex = 1
	rewardCardT = 0
	rewardClosePressed = false
	rewardActionPressed = nil
	Sound.play("uiConfirm")
end

local function getRewardActionBounds(g, action)
	local x, y, w, h = getRewardCardBounds(g)
	local buttonW = 112
	local buttonY = y + h - rewardActionH - 12
	if action == "previous" then return x + 18, buttonY, buttonW, rewardActionH end
	return x + w - buttonW - 18, buttonY, buttonW, rewardActionH
end

local function pointInRewardAction(x, y)
	if #rewardCards <= 0 or not layout then return nil end
	if rewardCardIndex > 1 then
		local bx, by, bw, bh = getRewardActionBounds(layout, "previous")
		if x >= bx and x <= bx + bw and y >= by and y <= by + bh then return "previous" end
	end
	local bx, by, bw, bh = getRewardActionBounds(layout, "next")
	if x >= bx and x <= bx + bw and y >= by and y <= by + bh then return "next" end
	return nil
end

local function activateRewardAction(action)
	if action == "previous" and rewardCardIndex > 1 then
		rewardCardIndex = rewardCardIndex - 1
	elseif action == "next" then
		if rewardCardIndex < #rewardCards then
			rewardCardIndex = rewardCardIndex + 1
		else
			finishRewardCards()
			return
		end
	else
		return
	end
	rewardCardT = 0
	Sound.play("uiConfirm")
end

local function drawRewardUnlockCard(g)
	if #rewardCards <= 0 then return end

	local index = rewardCardIndex
	local card = rewardCards[index]
	local intro = min(1, rewardCardT * 2.2)
	local scale = 0.78 + 0.22 * easeOutBack(intro)
	local alpha = min(1, rewardCardT * 3)
	local x, targetY, w, h = getRewardCardBounds(g)
	local y = targetY - 40 * (1 - intro)
	local cx, cy = x + w * 0.5, y + h * 0.5

	lg.push()
	lg.translate(cx, cy)
	lg.scale(scale, scale)
	lg.translate(-cx, -cy)

	lg.setColor(0.02, 0.03, 0.05, 0.72 * alpha)
	lg.rectangle("fill", x + 10, y + 14, w, h, 20, 20)
	lg.setColor(colorOutline[1], colorOutline[2], colorOutline[3], alpha)
	lg.rectangle("fill", x - outlineW, y - outlineW, w + outlineW * 2, h + outlineW * 2, 20, 20)
	lg.setColor(colorBackdrop[1], colorBackdrop[2], colorBackdrop[3], alpha)
	lg.rectangle("fill", x, y, w, h, 18, 18)
	lg.setColor(card.color[1], card.color[2], card.color[3], 0.18 * alpha)
	lg.rectangle("fill", x + 8, y + 8, w - 16, h - 16, 14, 14)

	Fonts.set("ui")
	lg.setColor(Theme.ui.good[1], Theme.ui.good[2], Theme.ui.good[3], alpha)
	Text.printfShadow(L("victory.rewardUnlocked"), x + 18, y + 16, w - 36, "center")

	local closeX = x + w - rewardCloseSize - 10
	local closeY = y + 10
	local closeHovered = pointInRewardClose(love.mouse.getPosition())
	local closeColor = closeHovered and Theme.ui.buttonHover or Theme.ui.button
	lg.setColor(colorOutline[1], colorOutline[2], colorOutline[3], alpha)
	lg.rectangle("fill", closeX - 2, closeY - 2, rewardCloseSize + 4, rewardCloseSize + 4, 8, 8)
	lg.setColor(closeColor[1], closeColor[2], closeColor[3], alpha)
	lg.rectangle("fill", closeX, closeY, rewardCloseSize, rewardCloseSize, 6, 6)
	lg.setColor(colorText[1], colorText[2], colorText[3], alpha)
	lg.setLineWidth(3)
	lg.line(closeX + 10, closeY + 10, closeX + 22, closeY + 22)
	lg.line(closeX + 22, closeY + 10, closeX + 10, closeY + 22)

	local iconX, iconY = x + 74, y + 105
	lg.setColor(0.04, 0.05, 0.07, 0.8 * alpha)
	lg.circle("fill", iconX, iconY, 43)
	if card.type == "tower" then
		DrawEntities.drawTowerBase(card.id, iconX, iconY + 10, alpha)
		DrawEntities.drawTowerCore(card.id, iconX, iconY + 10, -0.65, 0, alpha)
	elseif card.type == "ability" then
		AbilityIcons.draw(card.id, iconX, iconY, 1.45, alpha, "newly-unlocked")
	end

	Fonts.set("menu")
	lg.setColor(colorText[1], colorText[2], colorText[3], alpha)
	Text.printfShadow(card.name, x + 132, y + 64, w - 154, "left")
	Fonts.set("ui")
	lg.setColor(colorText[1], colorText[2], colorText[3], 0.82 * alpha)
	Text.printfShadow(card.description, x + 132, y + 100, w - 154, "left")

	if #rewardCards > 1 then
		lg.setColor(colorText[1], colorText[2], colorText[3], 0.55 * alpha)
		Text.printfShadow(('%d / %d'):format(index, #rewardCards), x + 18, y + h - 36, w - 36, "center")
	end

	local function drawAction(action, label)
		local bx, by, bw, bh = getRewardActionBounds(g, action)
		local hovered = pointInRewardAction(love.mouse.getPosition()) == action
		local fill = hovered and Theme.ui.buttonHover or Theme.ui.button
		lg.setColor(colorOutline[1], colorOutline[2], colorOutline[3], alpha)
		lg.rectangle("fill", bx - 2, by - 2, bw + 4, bh + 4, 8, 8)
		lg.setColor(fill[1], fill[2], fill[3], alpha)
		lg.rectangle("fill", bx, by, bw, bh, 6, 6)
		lg.setColor(colorText[1], colorText[2], colorText[3], alpha)
		Text.printfShadow(label, bx, by + 7, bw, "center")
	end
	if index > 1 then drawAction("previous", L("victory.rewardPrevious")) end
	local finalLabel = #rewardCards == 1 and L("victory.rewardClose") or L("victory.rewardContinue")
	drawAction("next", index < #rewardCards and L("victory.rewardNext") or finalLabel)

	lg.pop()
end

local function recordFirstClear()
	local map = Maps[State.worldMapIndex]
	local mapId = map and map.id or nil
	local firstClear = mapId and not (Save.data.meta.clearedMaps and Save.data.meta.clearedMaps[mapId]) or false
	State.wasFirstClear = firstClear

	if mapId and firstClear then
		Save.data.meta.clearedMaps[mapId] = true
		Save.flush()
	end
end

local function calculateLayout()
	local sw, sh = lg.getDimensions()
	local cx = floor(sw * 0.5)
	local compact = sh < 720
	local edge = compact and 10 or 24
	local boxW = min(panelW, sw - edge * 2)
	local boxX = cx - boxW * 0.5
	local padX = min(paddingX, max(12, boxW * 0.05))
	local padY = compact and 12 or paddingY
	local buttonGap = compact and 8 or 14
	local buttonHeight = compact and 36 or btnH
	local buttonsHeight = #buttons * buttonHeight + max(0, #buttons - 1) * buttonGap
	local titleHeight = compact and 34 or 50
	local sectionGap = compact and 8 or 18
	local campaignMessageH = isFinalCampaignMap and (compact and 72 or 86) or 0
	local difficultyY = (compact and 12 or difficultyOffset) + campaignMessageH
	local _, clusterH = Medals.getClusterSize(medalR, medalGap)
	local medalY = difficultyY + (compact and 30 or 38)
	local recapContentH = medalY + clusterH + 14
	local desiredBoxH = padY * 2 + titleHeight + recapContentH + sectionGap + buttonsHeight
	local boxH = min(desiredBoxH, sh - edge * 2)
	local boxY = floor((sh - boxH) * 0.5)
	local buttonsStartY = boxY + boxH - padY - buttonsHeight
	local recapY = boxY + padY + titleHeight
	local recapBottom = buttonsStartY - sectionGap
	local viewportH = max(0, recapBottom - recapY)
	recapScroll:update(recapContentH, viewportH)

	return {
		sw = sw, sh = sh, cx = cx, compact = compact,
		boxX = boxX, boxY = boxY, boxW = boxW, boxH = boxH,
		padX = padX, padY = padY,
		titleY = boxY + padY, recapY = recapY, recapH = viewportH,
		difficultyY = difficultyY, medalY = medalY,
		campaignMessageH = campaignMessageH,
		recapContentH = recapContentH, buttonsStartY = buttonsStartY,
		buttonGap = buttonGap, buttonHeight = buttonHeight,
	}
end

local function layoutButtons()
	layout = calculateLayout()

	for i, btn in ipairs(buttons) do
		btn.h = layout.buttonHeight
		btn.x = layout.cx - btn.w * 0.5
		btn.y = layout.buttonsStartY + (i - 1) * (layout.buttonHeight + layout.buttonGap)
	end
end

local function resetConfetti()
	local sw, sh = lg.getDimensions()
	confetti = {}

	for i = 1, 64 do
		confetti[i] = {
			x = random(0, sw),
			y = random(-sh * 0.6, -20),
			vx = random(-18, 18),
			vy = random(44, 120),
			size = random(4, 9),
			spin = random() * 6.28,
			spinRate = random(-4, 4),
			color = confettiColors[random(1, #confettiColors)],
			alpha = random(50, 95) * 0.01,
		}
	end
end

function Screen.load()
	local hasNextMap = State.worldMapIndex < #Maps
	isFinalCampaignMap = State.worldMapIndex == #Maps
	unlockedFinalChallenge = isFinalCampaignMap and hasNewFinalChallengeReward()
	buttons = {}

	if hasNextMap then
		buttons[#buttons + 1] = {
			id = "next",
			label = L("menu.nextMap"),
			w = btnW,
			h = btnH,
			onClick = function()
				Sound.play("uiConfirm")
				State.worldMapIndex = State.worldMapIndex + 1
				State.mapIndex = State.resolveMapIndex(State.worldMapIndex)
				State.gameOver = false
				State.victory = false
				State.mode = "game"
				resetGame()
			end,
			enabled = not Constants.IS_DEMO,
		}
	end

	buttons[#buttons + 1] = {
		id = "endless",
		label = isFinalCampaignMap and L("victory.finalCampaign.endlessAction") or L("menu.endless"),
		w = btnW,
		h = btnH,
		onClick = function()
			Sound.play("uiConfirm")
			GameplayOutcome.continueIntoEndless()
		end,
		enabled = not Constants.IS_DEMO and CampaignUnlocks.isEndlessUnlocked(),
	}

	buttons[#buttons + 1] = {
		id = "menu",
		label = L("menu.mainMenu"),
		w = btnW,
		h = btnH,
		onClick = function()
			Sound.play("uiConfirm")
			Backdrop.start()
			Steam.setRichPresence(L("presence.menu"))
			Save.flush()
			State.mode = "menu"
		end
	}

	layoutButtons()
end

function Screen.enter()
	-- Victory-specific actions and campaign-completion copy depend on the map and
	-- rewards from the run that just ended, not the state present at app startup.
	Screen.load()
	hideMedalTooltip()
	medalHoverScales = {1, 1, 1}
	t = 0
	panelT = 0
	rewardCardT = 0
	rewardCardIndex = 1
	rewardClosePressed = false
	rewardActionPressed = nil
	recapScroll:reset()
	buildRewardCards()
	resetConfetti()
	Medals.resetAnimations()
	recordFirstClear()

	previousMedalCount = Medals.getCount(State.previousCompletionDifficulty)
	currentMedalCount = Medals.getCount(Difficulty.key())

	if currentMedalCount > previousMedalCount then
		Medals.beginReveal(previousMedalCount, currentMedalCount)
	else
		Medals.beginReveal(currentMedalCount, currentMedalCount)
	end

	if Constants.IS_DEMO then
		Overlay.show(DemoComplete)
	end
end

function Screen.update(dt)
	t = t + dt
	local speed = 4.8
	local pt = min(1, t * speed)
	panelT = pt * pt * (3 - 2 * pt)

	layoutButtons()

	if #rewardCards > 0 then
		rewardCardT = rewardCardT + dt
	end

	-- Let the reward have the player's full attention before revealing the
	-- newly earned medal behind it. The reveal's own delay starts once the
	-- reward card has been dismissed.
	if #rewardCards == 0 then
		Medals.update(dt)
	end
	local sw, sh = lg.getDimensions()

	for _, p in ipairs(confetti) do
		p.x = p.x + p.vx * dt
		p.y = p.y + p.vy * dt
		p.spin = p.spin + p.spinRate * dt

		if p.y > sh + 16 then
			p.y = random(-sh * 0.45, -24)
			p.x = random(0, sw)
			p.vy = random(44, 120)
		end
		if p.x < -20 then
			p.x = sw + 20
		elseif p.x > sw + 20 then
			p.x = -20
		end
	end

	Button.updateList(buttons, dt)
	updateMedalTooltip()

	-- Ease each medal independently so entering and leaving hover both feel
	-- responsive without the abrupt white outline previously used here.
	local blend = 1 - math.exp(-medalHoverSpeed * dt)
	for tier = 1, 3 do
		local target = tier == hoveredMedalTier and medalHoverScale or 1
		medalHoverScales[tier] = medalHoverScales[tier]
			+ (target - medalHoverScales[tier]) * blend
	end
end

function Screen.draw()
	-- Reuse one geometry calculation for rendering and the interactive buttons.
	layoutButtons()
	local g = layout
	local sw, sh, cx = g.sw, g.sh, g.cx
	local boxX, boxY, boxW, boxH = g.boxX, g.boxY, g.boxW, g.boxH

	-- Dim world
	lg.setColor(colorDim)
	lg.rectangle("fill", 0, 0, sw, sh)

	for _, p in ipairs(confetti) do
		local wobble = sin(t * 3 + p.spin) * 0.35
		lg.setColor(p.color[1], p.color[2], p.color[3], p.alpha * panelT)
		lg.push()
		lg.translate(p.x, p.y)
		lg.rotate(p.spin + wobble)
		lg.rectangle("fill", -p.size * 0.5, -p.size * 0.35, p.size, p.size * 0.7, 2, 2)
		lg.pop()
	end

	local panelCX = boxX + boxW * 0.5
	local panelCY = boxY + boxH * 0.5
	local overshoot = 1.035
	local scale = 1 + (overshoot - 1) * (1 - panelT)
	local alpha = panelT

	lg.push()
	lg.translate(panelCX, panelCY)
	lg.scale(scale, scale)
	lg.translate(-panelCX, -panelCY)

	-- Panel
	lg.setColor(colorOutline[1], colorOutline[2], colorOutline[3], alpha)
	lg.rectangle("fill", boxX - outlineW, boxY - outlineW, boxW + outlineW * 2, boxH + outlineW * 2, outerRadius)

	lg.setColor(colorBackdrop[1], colorBackdrop[2], colorBackdrop[3], alpha)
	lg.rectangle("fill", boxX, boxY, boxW, boxH, innerRadius)

	-- Title
	local titleY = g.titleY

	Fonts.set(g.compact and "menu" or "title")
	lg.setColor(colorGood[1], colorGood[2], colorGood[3], alpha)
	local titleKey = isFinalCampaignMap and "victory.finalCampaign.title" or "game.victory"
	Text.printfShadow(L(titleKey), boxX + g.padX, titleY, boxW - g.padX * 2, "center")

	-- The recap may scroll, but the heading and action buttons remain outside its clip.
	lg.setScissor(g.boxX, g.recapY, g.boxW, g.recapH)
	local recapContentY = g.recapY - recapScroll.offset
	if isFinalCampaignMap then
		local difficulty = RunRecap.getDifficultyLabel() or L("difficulty." .. Difficulty.key())
		local messageKey = unlockedFinalChallenge and "firstClear" or "repeatClear"
		Fonts.set("ui")
		lg.setColor(colorText[1], colorText[2], colorText[3], 0.9 * alpha)
		Text.printfShadow(L("victory.finalCampaign." .. messageKey, difficulty), boxX + g.padX,
			recapContentY + 2, boxW - g.padX * 2, "center")
		lg.setColor(colorGood[1], colorGood[2], colorGood[3], 0.9 * alpha)
		Text.printfShadow(L("victory.finalCampaign." .. (unlockedFinalChallenge and "rewardUnlocked" or "challengePrompt")),
			boxX + g.padX, recapContentY + (g.compact and 38 or 44), boxW - g.padX * 2, "center")
	end
	-- Difficulty
	local difficultyLabel = RunRecap.getDifficultyLabel()
	local difficultyY = recapContentY + g.difficultyY

	if difficultyLabel then
		Fonts.set("ui")
		lg.setColor(colorText[1], colorText[2], colorText[3], 0.78 * alpha)
		Text.printfShadow(format("%s: %s  •  %s: %s", L("gameOver.map"), RunRecap.getMapName(), L("settings.difficulty"), difficultyLabel), boxX + g.padX, difficultyY, boxW - g.padX * 2, "center")
	end

	-- Medals
	local clusterW, clusterH = Medals.getClusterSize(medalR, medalGap)
	local medalX = cx - clusterW * 0.5
	local medalY = recapContentY + g.medalY

	lg.setColor(colorDim[1], colorDim[2], colorDim[3], 0.75 * alpha)
	lg.rectangle("fill", medalX - 16, medalY - 12, clusterW + 32, clusterH + 24, 14, 14)

	-- Continue the campaign screen's staggered shine once reveal animations settle.
	Medals.drawReveal(medalX, medalY, medalR, medalGap, t, medalHoverScales)

	Fonts.set("ui")
	lg.setColor(colorText[1], colorText[2], colorText[3], 0.75 * alpha)
	Text.printfShadow(L("victory.medalProgress"), 0, medalY - 20, sw, "center")
	lg.setScissor()

	-- Buttons
	Button.drawList(buttons)

	lg.pop()

	drawRewardUnlockCard(g)
	Tooltip.draw()
end

function Screen.leave()
	hideMedalTooltip()
end

function Screen.wheelmoved(_, y)
	if not layout then return end
	recapScroll:move(-y * 36)
end

function Screen.mousepressed(x, y, button)
	if rewardCardBlockingInput() then return true end
	if #rewardCards > 0 then
		if button == 1 and pointInRewardClose(x, y) then
			rewardClosePressed = true
		else
			rewardActionPressed = button == 1 and pointInRewardAction(x, y) or nil
		end
		return true
	end

	return Button.mousepressedList(buttons, x, y, button)
end

function Screen.mousereleased(x, y, button)
	if rewardCardBlockingInput() then return true end
	if #rewardCards > 0 then
		local closePressed = rewardClosePressed
		local actionPressed = rewardActionPressed
		rewardClosePressed = false
		rewardActionPressed = nil
		if button == 1 and closePressed and pointInRewardClose(x, y) then
			closeRewardCard()
		elseif button == 1 and actionPressed and actionPressed == pointInRewardAction(x, y) then
			activateRewardAction(actionPressed)
		end
		return true
	end

	return Button.mousereleasedList(buttons, x, y, button)
end

function Screen.keypressed(key)
	if rewardCardBlockingInput() then return true end
	if #rewardCards > 0 then
		if key == "left" then
			activateRewardAction("previous")
		elseif key == "right" or key == "return" or key == "kpenter" then
			activateRewardAction("next")
		elseif key == "escape" then
			closeRewardCard()
		end
		return true
	end

	if key == "escape" then
		for _, btn in ipairs(buttons) do
			if btn.id == "menu" and btn.onClick then
				Sound.play("uiBack")
				btn.onClick()
				return true
			end
		end
	end
end

return Screen
