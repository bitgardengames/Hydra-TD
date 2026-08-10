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
local DrawEntities = require("render.draw_entities")
local RunRecap = require("ui.run_recap")
local ScrollView = require("ui.scroll_view")
local AbilityIcons = require("ui.ability_icons")

local Overlay = require("ui.overlay")
local DemoComplete = require("ui.overlays.demo_complete")
local ReviewPrompt = require("ui.overlays.review_prompt")

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
local stats = {}
local confetti = {}
local t = 0
local panelT = 0
local recapScroll = ScrollView.new()
local layout = nil
local rewardCardT = 0
local rewardCards = {}
local rewardClosePressed = false

-- Colors
local colorGood = Theme.ui.good
local colorText = Theme.ui.text
local colorBackdrop = Theme.ui.backdrop
local colorDim = Theme.ui.screenDim
local colorOutline = Theme.outline.color
local colorButton = Theme.ui.button

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
local rewardCardH = 176
local rewardInputDelay = 1.25
local rewardCloseSize = 32

local statsGap = 12
local statH = 44
local difficultyOffset = 22

-- Medal visuals
local medalR = 16
local medalGap = 14
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

local function buildRewardCards()
	rewardCards = {}

	for _, kind in ipairs(State.unlockedTowersThisVictory or {}) do
		local def = TowerDefs[kind]
		rewardCards[#rewardCards + 1] = {
			type = "tower",
			id = kind,
			name = L((def and def.nameKey) or ("tower." .. kind)),
			description = L((def and def.descKey) or ("towerDesc." .. kind)),
			color = (def and def.color) or Theme.ui.good,
		}
	end

	for _, abilityId in ipairs(State.unlockedAbilitiesThisVictory or {}) do
		local def = AbilityDefs[abilityId]
		rewardCards[#rewardCards + 1] = {
			type = "ability",
			id = abilityId,
			name = L((def and def.nameKey) or ("ability." .. abilityId .. ".name")),
			description = L((def and def.descKey) or ("ability." .. abilityId .. ".desc")),
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
	rewardCards = {}
	rewardClosePressed = false
	Sound.play("uiBack")
end

local function drawRewardUnlockCard(g)
	if #rewardCards <= 0 then return end

	local index = min(#rewardCards, math.floor(rewardCardT / 2.8) + 1)
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

	local iconX, iconY = x + 74, y + 96
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
	Text.printfShadow(card.name, x + 132, y + 58, w - 154, "left")
	Fonts.set("ui")
	lg.setColor(colorText[1], colorText[2], colorText[3], 0.82 * alpha)
	Text.printfShadow(card.description, x + 132, y + 94, w - 154, "left")

	if #rewardCards > 1 then
		lg.setColor(colorText[1], colorText[2], colorText[3], 0.55 * alpha)
		Text.printfShadow(('%d / %d'):format(index, #rewardCards), x + 18, y + h - 28, w - 36, "right")
	end

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
	local cardW = boxW - padX * 2
	local valueFont = compact and Fonts.ui or Fonts.menu
	local labelFont = Fonts.ui
	local rowGap = compact and 6 or statsGap
	local rows = {}
	local contentY = 0

	for i, item in ipairs(stats) do
		local _, wrapped = valueFont:getWrap(item.value, max(1, cardW - 24))
		local valueLines = max(1, #wrapped)
		local rowH = max(statH, 8 + labelFont:getHeight() + 4 + valueLines * valueFont:getHeight() + 8)
		if compact then rowH = max(40, rowH - 4) end
		rows[i] = { y = contentY, h = rowH, lines = valueLines }
		contentY = contentY + rowH + (i < #stats and rowGap or 0)
	end

	local difficultyY = contentY + (compact and 12 or difficultyOffset)
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
		padX = padX, padY = padY, cardW = cardW,
		titleY = boxY + padY, recapY = recapY, recapH = viewportH,
		rows = rows, difficultyY = difficultyY, medalY = medalY,
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

local function buildStats()
	local rewardNames = {}
	for _, kind in ipairs(State.unlockedTowersThisVictory or {}) do
		rewardNames[#rewardNames + 1] = L("tower." .. kind)
	end

	stats = {}

	if #rewardNames > 0 then
		stats[#stats + 1] = { label = L("victory.newTowerReward"), value = table.concat(rewardNames, "  •  ") }
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
	buttons = {
		{
			id = "next",
			label = L("menu.nextMap"),
			w = btnW,
			h = btnH,
			onClick = function()
				Sound.play("uiConfirm")
				State.worldMapIndex = min(State.worldMapIndex + 1, #Maps)
				State.mapIndex = State.resolveMapIndex(State.worldMapIndex)
				State.gameOver = false
				State.victory = false
				State.mode = "game"
				resetGame()
			end,
			enabled = not Constants.IS_DEMO,
		},

		{
			id = "endless",
			label = L("menu.endless"),
			w = btnW,
			h = btnH,
			onClick = function()
				Sound.play("uiConfirm")
				State.speed = 1
				State.endless = true
				State.gameOver = false
				State.victory = false
				State.mode = "game"
			end,
			enabled = not Constants.IS_DEMO and CampaignUnlocks.isEndlessUnlocked(),
		},

		{
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
		},
	}

	buildStats()
	layoutButtons()
end

function Screen.enter()
	t = 0
	panelT = 0
	rewardCardT = 0
	rewardClosePressed = false
	recapScroll:reset()
	buildStats()
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
	else
		local lastMap = (#Maps == State.worldMapIndex)

		if lastMap and not Save.data.reviewPromptShown then
			Overlay.show(ReviewPrompt)
			Save.data.reviewPromptShown = true
			Save.flush()
		end
	end
end

function Screen.update(dt)
	t = t + dt
	local speed = 4.8
	local pt = min(1, t * speed)
	panelT = pt * pt * (3 - 2 * pt)

	buildStats()
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
	Text.printfShadow(L("game.victory"), boxX + g.padX, titleY, boxW - g.padX * 2, "center")

	-- The recap may scroll, but the heading and action buttons remain outside its clip.
	lg.setScissor(g.boxX, g.recapY, g.boxW, g.recapH)
	local statsY = g.recapY - recapScroll.offset
	local cardW = g.cardW
	for i, item in ipairs(stats) do
		local row = g.rows[i]
		local x = boxX + g.padX
		local y = statsY + row.y

		lg.setColor(colorDim[1], colorDim[2], colorDim[3], 0.6 * alpha)
		lg.rectangle("fill", x, y, cardW, row.h, 10, 10)

		Fonts.set("ui")
		lg.setColor(colorText[1], colorText[2], colorText[3], 0.74 * alpha)
		Text.printfShadow(item.label, x + 12, y + 8, cardW - 24, "left")

		Fonts.set(g.compact and "ui" or "menu")
		lg.setColor(colorButton[1], colorButton[2], colorButton[3], alpha)
		Text.printfShadow(item.value, x + 12, y + 8 + Fonts.ui:getHeight() + 4, cardW - 24, "left")
	end

	-- Difficulty
	local difficultyLabel = RunRecap.getDifficultyLabel()
	local difficultyY = statsY + g.difficultyY

	if difficultyLabel then
		Fonts.set("ui")
		lg.setColor(colorText[1], colorText[2], colorText[3], 0.78 * alpha)
		Text.printfShadow(format("%s: %s  •  %s: %s", L("gameOver.map"), RunRecap.getMapName(), L("settings.difficulty"), difficultyLabel), boxX + g.padX, difficultyY, boxW - g.padX * 2, "center")
	end

	-- Medals
	local clusterW, clusterH = Medals.getClusterSize(medalR, medalGap)
	local medalX = cx - clusterW * 0.5
	local medalY = statsY + g.medalY

	lg.setColor(colorDim[1], colorDim[2], colorDim[3], 0.75 * alpha)
	lg.rectangle("fill", medalX - 16, medalY - 12, clusterW + 32, clusterH + 24, 14, 14)

	Medals.drawReveal(medalX, medalY, medalR, medalGap)

	Fonts.set("ui")
	lg.setColor(colorText[1], colorText[2], colorText[3], 0.75 * alpha)
	Text.printfShadow(L("victory.medalProgress"), 0, medalY - 20, sw, "center")
	lg.setScissor()

	-- Buttons
	Button.drawList(buttons)

	lg.pop()

	drawRewardUnlockCard(g)
end

function Screen.wheelmoved(_, y)
	if not layout then return end
	recapScroll:move(-y * 36)
end

function Screen.mousepressed(x, y, button)
	if rewardCardBlockingInput() then return true end
	if button == 1 and pointInRewardClose(x, y) then
		rewardClosePressed = true
		return true
	end

	return Button.mousepressedList(buttons, x, y, button)
end

function Screen.mousereleased(x, y, button)
	if rewardCardBlockingInput() then return true end
	if button == 1 and rewardClosePressed then
		local shouldClose = pointInRewardClose(x, y)
		rewardClosePressed = false
		if shouldClose then closeRewardCard() end
		return true
	end

	return Button.mousereleasedList(buttons, x, y, button)
end

function Screen.keypressed(key)
	if rewardCardBlockingInput() then return true end

	if key == "escape" then
		for _, btn in ipairs(buttons) do
			if btn.id == "menu" and btn.onClick then
				Sound.play("uiBack")
				btn.onClick()
				return true
			end
		end
	elseif key == "return" or key == "kpenter" then
		for _, btn in ipairs(buttons) do
			if btn.enabled ~= false and btn.onClick then
				btn.onClick()
				return true
			end
		end
	end
end

return Screen
