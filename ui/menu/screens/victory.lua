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
local DrawEntities = require("render.draw_entities")
local RunRecap = require("ui.run_recap")
local ScrollView = require("ui.scroll_view")
local AbilityIcons = require("ui.ability_icons")
local AnimatedRunStats = require("ui.animated_run_stats")
local MapPreviewCache = require("world.map_preview_cache")
local CampaignUnlocks = require("systems.campaign_unlocks")
local RewardReveal = require("ui.reward_reveal")

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
local mapRewardCards = {}
local rewardRevealElapsed = 0
local rewardRevealStarted = false
local isFinalCampaignMap = false
local runStats = AnimatedRunStats.new(Theme.ui.good)

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

local btnW = 260
local btnH = 42
local panelW = 1120
local difficultyOffset = 22

-- Medal visuals
local medalR = 32
local medalGap = 14
local confettiColors = {
	Theme.ui.good,
	Theme.ui.wave,
	Theme.ui.money,
	Theme.medal.gold,
	Theme.medal.silver,
}


local function buildRewardCards()
	mapRewardCards = {}
	local function rewardWasEarned(reward)
		for _, earned in ipairs(State.unlockedRewardsThisVictory or {}) do
			if earned.type == reward.type and earned.id == reward.id then return true end
		end
		return false
	end
	local function makeCard(reward, isNew)
		local def = reward.type == "tower" and TowerDefs[reward.id]
			or reward.type == "ability" and AbilityDefs[reward.id]
		local fallbackKey = reward.type == "tower" and ("tower." .. reward.id)
			or ("ability." .. reward.id .. ".name")
		return {
			type = reward.type,
			id = reward.id,
			name = reward.labelKey and L(reward.labelKey) or reward.label
				or (def and L(def.nameKey)) or L(fallbackKey),
			description = L(reward.descriptionKey or ("victory.rewardDescriptions." .. reward.type)),
			color = (def and def.color) or (reward.type == "ability" and Theme.ui.selected) or Theme.ui.good,
			isNew = isNew,
			revealDelay = 0,
			revealProgress = isNew and 0 or 1,
		}
	end

	-- The summary always describes the completed map's authored reward. Its
	-- state distinguishes a first-clear unlock from a reward earned previously.
	local map = Maps[State.worldMapIndex]
	for _, reward in ipairs(CampaignUnlocks.getRewardsForMap(map)) do
		mapRewardCards[#mapRewardCards + 1] = makeCard(reward, rewardWasEarned(reward))
	end
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
	local compact = sw < 980 or sh < 680
	local edge = compact and 10 or 20
	local boxW = min(panelW, sw - edge * 2)
	local boxX = cx - boxW * 0.5
	local padX = compact and 16 or 22
	local padY = compact and 12 or 20
	local buttonBottomPadding = compact and 18 or 28
	local buttonGap = compact and 8 or 16
	local buttonHeight = compact and 36 or btnH
	local buttonsHeight = buttonHeight
	local titleHeight = compact and 48 or 66
	local sectionGap = 14
	local boxH = min(compact and 620 or 680, sh - edge * 2)
	local boxY = floor((sh - boxH) * 0.5)
	local buttonsStartY = boxY + boxH - buttonBottomPadding - buttonsHeight
	local recapY = boxY + padY + titleHeight
	local recapBottom = buttonsStartY - sectionGap
	local viewportH = max(0, recapBottom - recapY)
	recapScroll:update(viewportH, viewportH)

	return {
		sw = sw, sh = sh, cx = cx, compact = compact,
		boxX = boxX, boxY = boxY, boxW = boxW, boxH = boxH,
		padX = padX, padY = padY,
		titleY = boxY + padY, recapY = recapY, recapH = viewportH,
		recapContentH = viewportH, buttonsStartY = buttonsStartY,
		buttonGap = buttonGap, buttonHeight = buttonHeight,
	}
end

local function layoutButtons()
	layout = calculateLayout()

	for i, btn in ipairs(buttons) do
		btn.h = layout.buttonHeight
		local totalW = #buttons * btn.w + max(0, #buttons - 1) * layout.buttonGap
		btn.x = layout.cx - totalW * 0.5 + (i - 1) * (btn.w + layout.buttonGap)
		btn.y = layout.buttonsStartY
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
	buttons = {}

	if hasNextMap then
		buttons[#buttons + 1] = {
			id = "next",
			label = L("menu.nextMap"),
			textColor = colorGood,
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
		id = "map_select",
		label = L("menu.mapSelect"),
		w = btnW,
		h = btnH,
		onClick = function()
			Sound.play("uiConfirm")
			Backdrop.start()
			Steam.setRichPresence(L("presence.menu"))
			Save.flush()
			require("ui.menu.menu").set("campaign")
		end
	}

	layoutButtons()
end

function Screen.enter()
	-- Victory-specific actions and campaign-completion copy depend on the map and
	-- rewards from the run that just ended, not the state present at app startup.
	Screen.load()
	t = 0
	panelT = 0
	recapScroll:reset()
	buildRewardCards()
	rewardRevealElapsed = 0
	rewardRevealStarted = false
	local revealIndex = 0
	for _, reward in ipairs(mapRewardCards) do
		if reward.isNew then
			revealIndex = revealIndex + 1
			reward.revealDelay = RewardReveal.delayFor(revealIndex)
		end
	end
	local map = Maps[State.worldMapIndex]
	runStats:setRows({})
	resetConfetti()
	Medals.resetAnimations()
	recordFirstClear()

	previousMedalCount = Medals.getCount(State.previousCompletionDifficulty)
	currentMedalCount = max(previousMedalCount, Medals.getCount(Difficulty.key()))

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

	runStats:update(dt)
	if runStats:isComplete() then
		Medals.update(dt)
		if Medals.isRevealComplete() then
			rewardRevealStarted = true
			rewardRevealElapsed = rewardRevealElapsed + dt
			for _, reward in ipairs(mapRewardCards) do
				if reward.isNew then
					reward.revealProgress = RewardReveal.sample(rewardRevealElapsed,
						reward.revealDelay, Save.data.settings.cameraMotion == false).progress
				end
			end
		end
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

local function formatNumber(value)
	local text = tostring(floor((value or 0) + 0.5))
	local changed = 1
	while changed > 0 do
		text, changed = text:gsub("^(%-?%d+)(%d%d%d)", "%1,%2")
	end
	return text
end

local function drawCard(x, y, w, h, alpha)
	lg.setColor(colorOutline[1], colorOutline[2], colorOutline[3], 0.85 * alpha)
	lg.rectangle("fill", x, y, w, h, 10, 10)
	lg.setColor(Theme.ui.panel2[1], Theme.ui.panel2[2], Theme.ui.panel2[3], 0.96 * alpha)
	lg.rectangle("fill", x + 2, y + 2, w - 4, h - 4, 8, 8)
end

local function drawStatRow(label, value, x, y, w, alpha, color)
	Fonts.set("ui")
	color = color or colorText
	lg.setColor(colorText[1], colorText[2], colorText[3], 0.7 * alpha)
	Text.printfShadow(label, x, y, w * 0.7, "left")
	lg.setColor(color[1], color[2], color[3], alpha)
	Text.printfShadow(value, x, y, w, "right")
	lg.setColor(1, 1, 1, 0.06 * alpha)
	lg.rectangle("fill", x, y + 25, w, 1)
end

local function drawDamagePanel(x, y, w, h, alpha)
	drawCard(x, y, w, h, alpha)
	Fonts.set("ui")
	lg.setColor(colorText[1], colorText[2], colorText[3], alpha)
	Text.printShadow(L("victory.damageDealt"), x + 16, y + 14)
	local stats = State.combatStats or {}
	local total = max(1, stats.totalDamage or 0)
	local rows = {}
	for _, kind in ipairs(Constants.TOWER_LIST) do
		local damage = (stats.damageByTower or {})[kind] or 0
		if damage > 0 then rows[#rows + 1] = {kind = kind, damage = damage} end
	end
	table.sort(rows, function(a, b) return a.damage > b.damage end)
	local rowY, barW, barH = y + 48, w - 198, 9
	for i = 1, min(6, #rows) do
		local row = rows[i]
		local c = Theme.tower[row.kind] or colorGood
		lg.setColor(c[1], c[2], c[3], alpha)
		Text.printShadow(L("tower." .. row.kind), x + 16, rowY)
		lg.setColor(1, 1, 1, 0.07 * alpha)
		lg.rectangle("fill", x + 86, rowY + 6, barW, barH, 3, 3)
		lg.setColor(c[1], c[2], c[3], 0.9 * alpha)
		lg.rectangle("fill", x + 86, rowY + 6, barW * row.damage / total, barH, 3, 3)
		lg.setColor(colorText[1], colorText[2], colorText[3], alpha)
		Text.printfShadow(format("%s (%d%%)", formatNumber(row.damage), floor(row.damage / total * 100 + 0.5)), x + 12, rowY, w - 28, "right")
		rowY = rowY + 34
	end
end

local function drawRewardsPanel(x, y, w, h, alpha)
	drawCard(x, y, w, h, alpha)
	Fonts.set("ui")
	lg.setColor(colorText[1], colorText[2], colorText[3], alpha)
	Text.printShadow(L("victory.rewards"), x + 16, y + 14)

	if #mapRewardCards == 0 then
		lg.setColor(colorText[1], colorText[2], colorText[3], 0.7 * alpha)
		Text.printfShadow(L("victory.noMapReward"), x + 16, y + 58, w - 32, "center")
		return
	end

	local rowY = y + 48
	for index, reward in ipairs(mapRewardCards) do
		if rowY + 54 > y + h then break end
		local reveal = reward.isNew and RewardReveal.sample(
			rewardRevealElapsed, reward.revealDelay, Save.data.settings.cameraMotion == false)
			or {alpha = 1, lift = 0, scale = 1, glint = 1, complete = true}
		local rowAlpha = alpha * reveal.alpha
		local drawnRowY = rowY - reveal.lift
		local iconX, iconY = x + 42, drawnRowY + 25
		lg.push("all")
		lg.translate(iconX, iconY)
		lg.scale(reveal.scale, reveal.scale)
		lg.translate(-iconX, -iconY)
		if reward.type == "tower" then
			lg.push("all")
			lg.translate(iconX, iconY)
			lg.scale(0.82, 0.82)
			DrawEntities.drawTowerBase(reward.id, 0, 5, rowAlpha)
			DrawEntities.drawTowerCore(reward.id, 0, 5, -math.pi * 0.5, 0, rowAlpha)
			lg.pop()
		elseif reward.type == "ability" then
			AbilityIcons.draw(reward.id, iconX, iconY, 0.9, rowAlpha,
				reward.isNew and "newly-unlocked" or nil)
		else
			lg.setColor(reward.color[1], reward.color[2], reward.color[3], rowAlpha)
			lg.circle("fill", iconX, iconY, 8)
		end
		lg.pop()

		if reward.isNew and reveal.glint < 1 then
			local sweep = reveal.glint * math.pi * 2
			lg.setLineWidth(2)
			lg.setColor(reward.color[1], reward.color[2], reward.color[3],
				math.sin(reveal.glint * math.pi) * 0.9 * alpha)
			lg.arc("line", "open", iconX, iconY, 27, -math.pi * 0.5, -math.pi * 0.5 + sweep)
		end

		lg.setColor(colorText[1], colorText[2], colorText[3], rowAlpha)
		Text.printfShadow(reward.name, x + 74, drawnRowY + 4, w - 90, "left")
		local stateColor = reward.isNew and Theme.ui.good or colorText
		lg.setColor(stateColor[1], stateColor[2], stateColor[3], (reward.isNew and 1 or 0.65) * rowAlpha)
		Text.printfShadow(L(reward.isNew and "victory.rewardNew" or "victory.rewardAlreadyUnlocked"),
			x + 74, drawnRowY + 29, w - 90, "left")
		rowY = rowY + 62
		if index < #mapRewardCards then
			lg.setColor(1, 1, 1, 0.06 * alpha)
			lg.rectangle("fill", x + 16, rowY - 8, w - 32, 1)
		end
	end
end

function Screen.draw()
	-- Reuse one geometry calculation for rendering and the interactive buttons.
	layoutButtons()
	local g = layout
	local sw, sh = g.sw, g.sh
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

	-- Victory heading.
	local titleY = g.titleY
	Fonts.set(g.compact and "menu" or "title")
	lg.setColor(colorGood[1], colorGood[2], colorGood[3], alpha)
	local titleKey = isFinalCampaignMap and "victory.finalCampaign.title" or "game.victory"
	Text.printfShadow(L(titleKey), boxX + g.padX, titleY, boxW - g.padX * 2, "center")
	local clusterW = Medals.getClusterSize(medalR, medalGap)

	local contentX, contentY = boxX + g.padX, g.recapY
	local contentW, contentH = boxW - g.padX * 2, g.recapH
	local gap = 14
	local leftW = floor(contentW * 0.29)
	local rightW = floor(contentW * 0.31)
	local centerW = contentW - leftW - rightW - gap * 2
	local centerX, rightX = contentX + leftW + gap, contentX + leftW + centerW + gap * 2
	local map = Maps[State.worldMapIndex]
	local result = State.runResult or {}

	-- Map card.
	drawCard(contentX, contentY, leftW, contentH, alpha)
	Fonts.set("menu")
	lg.setColor(colorText[1], colorText[2], colorText[3], alpha)
	Text.printShadow(RunRecap.getMapName(), contentX + 14, contentY + 12)
	Fonts.set("ui")
	lg.setColor(colorText[1], colorText[2], colorText[3], 0.7 * alpha)
	Text.printShadow(format(L("victory.mapNumber"), State.worldMapIndex, #Maps), contentX + 14, contentY + 40)
	local previewBoundsY = floor(contentY + 68 + 0.5)
	local previewBoundsH = floor(min(188, contentH * 0.42) + 0.5)
	local previewBoundsW = floor(leftW - 24 + 0.5)
	local preview, previewW, previewH
	if map then
		preview, previewW, previewH = MapPreviewCache.getFitted(map.id, previewBoundsW, previewBoundsH)
	end
	local previewX = floor(contentX + 12 + (previewBoundsW - (previewW or 0)) * 0.5 + 0.5)
	local previewY = floor(previewBoundsY + (previewBoundsH - (previewH or 0)) * 0.5 + 0.5)
	if preview and preview.canvas then
		lg.setColor(1, 1, 1, alpha)
		lg.draw(preview.canvas, previewX, previewY)
	end
	local previewBottom = previewY + (previewH or 0)
	drawStatRow(L("settings.difficulty"), RunRecap.getDifficultyLabel(), contentX + 14, previewBottom + 18, leftW - 28, alpha, colorGood)
	drawStatRow(L("victory.gameTime"), format("%d:%02d", floor((result.duration or 0) / 60), floor((result.duration or 0) % 60)), contentX + 14, previewBottom + 52, leftW - 28, alpha)

	-- Run summary.
	drawCard(centerX, contentY, centerW, contentH * 0.64, alpha)
	drawStatRow(L("runRecap.score"), formatNumber(State.score), centerX + 14, contentY + 14, centerW - 28, alpha, colorGood)
	drawStatRow(L("runRecap.enemiesDefeated"), formatNumber(State.totalKills), centerX + 14, contentY + 52, centerW - 28, alpha)
	drawStatRow(L("runRecap.livesRemaining"), formatNumber(State.lives), centerX + 14, contentY + 90, centerW - 28, alpha, State.totalLeaks == 0 and colorGood or colorText)
	drawStatRow(L("victory.moneyRemaining"), "$" .. formatNumber(State.money), centerX + 14, contentY + 128, centerW - 28, alpha, Theme.ui.money)
	drawStatRow(L("victory.towersPlaced"), formatNumber(result.towersPlaced), centerX + 14, contentY + 166, centerW - 28, alpha)
	drawStatRow(L("victory.abilitiesUsed"), formatNumber(result.abilitiesUsed), centerX + 14, contentY + 204, centerW - 28, alpha)
	local medalsY = contentY + contentH * 0.64 + gap
	local medalsH = contentH - contentH * 0.64 - gap
	drawCard(centerX, medalsY, centerW, medalsH, alpha)
	Fonts.set("ui")
	lg.setColor(colorText[1], colorText[2], colorText[3], 0.75 * alpha)
	Text.printfShadow(L("victory.medalProgress"), centerX, medalsY + 14, centerW, "center")
	local _, clusterH = Medals.getClusterSize(medalR, medalGap)
	Medals.drawReveal(
		centerX + (centerW - clusterW) * 0.5,
		medalsY + (medalsH - clusterH) * 0.5,
		medalR,
		medalGap,
		t
	)

	-- Damage and rewards.
	drawDamagePanel(rightX, contentY, rightW, contentH * 0.66, alpha)
	local rewardsY = contentY + contentH * 0.66 + gap
	drawRewardsPanel(rightX, rewardsY, rightW, contentH - contentH * 0.66 - gap, alpha)

	-- Buttons
	Button.drawList(buttons)

	lg.pop()

end

function Screen.wheelmoved(_, y)
	if not layout then return end
	recapScroll:move(-y * 36)
end

function Screen.mousepressed(x, y, button)
	if button == 1 and not Screen.animationsComplete() then
		Screen.finishAnimations()
		return true
	end

	return Button.mousepressedList(buttons, x, y, button)
end

function Screen.mousereleased(x, y, button)
	return Button.mousereleasedList(buttons, x, y, button)
end

function Screen.keypressed(key)
	if (key == "return" or key == "kpenter" or key == "space") and not Screen.animationsComplete() then
		Screen.finishAnimations()
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

function Screen.animationsComplete()
	if not runStats:isComplete() or not Medals.isRevealComplete() then return false end
	for _, reward in ipairs(mapRewardCards) do
		if reward.isNew and not RewardReveal.sample(rewardRevealElapsed,
			reward.revealDelay, Save.data.settings.cameraMotion == false).complete then return false end
	end
	return true
end

function Screen.finishAnimations()
	runStats:finish()
	Medals.finishReveal()
	rewardRevealStarted = true
	for _, reward in ipairs(mapRewardCards) do
		if reward.isNew then
			rewardRevealElapsed = max(rewardRevealElapsed,
				reward.revealDelay + RewardReveal.GLINT_DURATION)
			reward.revealProgress = 1
		end
	end
end

return Screen
