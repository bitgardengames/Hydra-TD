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
local RunRecap = require("ui.run_recap")
local ScrollView = require("ui.scroll_view")
local AnimatedRunStats = require("ui.animated_run_stats")

local Overlay = require("ui.overlay")
local DemoComplete = require("ui.overlays.demo_complete")

local lg = love.graphics
local min = math.min
local floor = math.floor
local max = math.max
local format = string.format
local sin = math.sin
local cos = math.cos
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
local isFinalCampaignMap = false
local runStats = AnimatedRunStats.new(Theme.ui.good)
local damageRows = {}
local damageTotal = 1

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

local btnW = 310
local btnH = 42
-- Keep both recap columns 40px narrower than the previous 900px layout; the
-- enclosing backdrop derives from this width so it stays aligned with them.
local panelW = 820

-- Medal visuals
local medalR = 32
local medalGap = 18
local confettiColors = {
	Theme.ui.good,
	Theme.ui.wave,
	Theme.ui.money,
	Theme.medal.gold,
	Theme.medal.silver,
	Theme.ui.selected,
}

local confettiShapes = {"paper", "diamond", "dot"}
-- Keep the celebration finite: after the fade completes, releasing the particle
-- table also removes its update and draw cost if the player leaves this screen open.
local confettiDuration = 12
local confettiFadeDuration = 2

local function buildDamageRows(combatStats)
	damageRows = {}
	combatStats = combatStats or {}
	damageTotal = max(1, combatStats.totalDamage or 0)
	local damageByTower = combatStats.damageByTower or {}

	for _, kind in ipairs(Constants.TOWER_LIST) do
		local damage = damageByTower[kind] or 0
		if damage > 0 then
			damageRows[#damageRows + 1] = {
				kind = kind,
				damage = damage,
				fraction = damage / damageTotal,
				percentage = floor(damage / damageTotal * 100 + 0.5),
			}
		end
	end

	table.sort(damageRows, function(a, b) return a.damage > b.damage end)
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
	-- Size the panel around the two-column recap instead of stretching it to the
	-- old, mostly empty 680px container.
	local desiredContentH = 444
	local desiredBoxH = padY + titleHeight + desiredContentH + sectionGap
		+ buttonsHeight + buttonBottomPadding
	local boxH = min(desiredBoxH, sh - edge * 2)
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
		local availableW = layout.boxW - layout.padX * 2
		btn.w = min(btnW, (availableW - max(0, #buttons - 1) * layout.buttonGap) / #buttons)
		local totalW = #buttons * btn.w + max(0, #buttons - 1) * layout.buttonGap
		btn.x = layout.cx - totalW * 0.5 + (i - 1) * (btn.w + layout.buttonGap)
		btn.y = layout.buttonsStartY
	end
end

local function resetConfetti()
	local sw, sh = lg.getDimensions()
	local reducedMotion = Save.data.settings.cameraMotion == false
	local count = reducedMotion and 36 or 84
	confetti = {}

	for i = 1, count do
		-- Most pieces drift down from above, while an opening volley fires in
		-- from both bottom corners. The latter makes the celebration feel tied to
		-- the moment of victory instead of looking like a looping screensaver.
		local burst = not reducedMotion and i <= 36
		local fromLeft = i % 2 == 0
		local size = random(4, 10)
		confetti[i] = {
			x = burst and (fromLeft and -12 or sw + 12) or random(0, sw),
			y = burst and (sh - random(20, 90)) or random(-sh * 0.75, -20),
			vx = burst and (fromLeft and random(360, 640) or random(-640, -360)) or random(-22, 22),
			vy = burst and random(-960, -560) or random(42, 112),
			gravity = burst and random(115, 175) or random(6, 20),
			drag = burst and random(55, 90) * 0.01 or random(4, 10) * 0.01,
			size = size,
			spin = random() * 6.28,
			spinRate = reducedMotion and random(-1, 1) or random(-6, 6),
			flutter = random() * 6.28,
			flutterRate = random(20, 45) * 0.1,
			shape = confettiShapes[random(1, #confettiShapes)],
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
			require("ui.menu.screens.campaign").invalidateCampaignProgress()
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
	buildDamageRows(State.combatStats)
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
	end
	local sw, sh = lg.getDimensions()

	for _, p in ipairs(confetti) do
		p.flutter = p.flutter + p.flutterRate * dt
		local drag = 1 / (1 + p.drag * dt)
		p.vx = p.vx * drag
		p.vy = p.vy * drag
		p.vy = p.vy + p.gravity * dt
		p.x = p.x + (p.vx + sin(p.flutter) * 18) * dt
		p.y = p.y + p.vy * dt
		p.spin = p.spin + p.spinRate * dt

		if p.y > sh + 16 then
			p.y = random(-sh * 0.45, -24)
			p.x = random(0, sw)
			p.vx = random(-22, 22)
			p.vy = random(44, 120)
			p.gravity = random(6, 20)
			p.drag = random(4, 10) * 0.01
		end
		if p.x < -20 then
			p.x = sw + 20
		elseif p.x > sw + 20 then
			p.x = -20
		end
	end

	if t >= confettiDuration and #confetti > 0 then
		confetti = {}
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
	local rowY, barW, barH = y + 48, w - 190, 9
	for i = 1, min(6, #damageRows) do
		local row = damageRows[i]
		local c = Theme.tower[row.kind] or colorGood
		lg.setColor(c[1], c[2], c[3], alpha)
		Text.printShadow(L("tower." .. row.kind), x + 16, rowY)
		lg.setColor(1, 1, 1, 0.07 * alpha)
		lg.rectangle("fill", x + 86, rowY + 6, barW, barH, 3, 3)
		lg.setColor(c[1], c[2], c[3], 0.9 * alpha)
		lg.rectangle("fill", x + 86, rowY + 6, barW * row.fraction, barH, 3, 3)
		lg.setColor(colorText[1], colorText[2], colorText[3], alpha)
		Text.printfShadow(format("%s (%d%%)", formatNumber(row.damage), row.percentage), x + 12, rowY, w - 28, "right")
		rowY = rowY + 38
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

	local confettiFade = min(1, max(0, (confettiDuration - t) / confettiFadeDuration))
	for _, p in ipairs(confetti) do
		local wobble = sin(t * 3 + p.flutter) * 0.35
		local flip = 0.3 + 0.7 * math.abs(cos(p.spin))
		lg.setColor(p.color[1], p.color[2], p.color[3], p.alpha * panelT * confettiFade)
		lg.push()
		lg.translate(p.x, p.y)
		lg.rotate(p.spin + wobble)
		if p.shape == "dot" then
			lg.circle("fill", 0, 0, p.size * 0.42)
		elseif p.shape == "diamond" then
			lg.rotate(0.785)
			lg.rectangle("fill", -p.size * 0.4 * flip, -p.size * 0.4, p.size * 0.8 * flip, p.size * 0.8, 1, 1)
		else
			lg.rectangle("fill", -p.size * 0.5 * flip, -p.size * 0.35, p.size * flip, p.size * 0.7, 2, 2)
		end
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
	local contentX, contentY = boxX + g.padX, g.recapY
	local contentW, contentH = boxW - g.padX * 2, g.recapH
	local gap = 20
	local leftW = floor((contentW - gap) * 0.5)
	local rightW = contentW - leftW - gap
	local rightX = contentX + leftW + gap
	local result = State.runResult or {}

	-- Map details and the full run summary share one card. This keeps the result
	-- hierarchy readable at a glance and mirrors the two-column victory layout.
	drawCard(contentX, contentY, leftW, contentH, alpha)
	Fonts.set("menu")
	lg.setColor(colorText[1], colorText[2], colorText[3], alpha)
	Text.printShadow(RunRecap.getMapName(), contentX + 22, contentY + 18)
	Fonts.set("ui")
	lg.setColor(colorText[1], colorText[2], colorText[3], 0.7 * alpha)
	local metadataX = contentX + 22
	local mapNumber = format(L("victory.mapNumber"), State.worldMapIndex, #Maps)
	Text.printShadow(mapNumber, metadataX, contentY + 54)
	local difficultyLabel = "  •  " .. L("settings.difficulty") .. ": "
	local difficultyX = metadataX + Fonts.get("ui"):getWidth(mapNumber)
	Text.printShadow(difficultyLabel, difficultyX, contentY + 54)
	lg.setColor(colorGood[1], colorGood[2], colorGood[3], alpha)
	Text.printShadow(RunRecap.getDifficultyLabel(), difficultyX + Fonts.get("ui"):getWidth(difficultyLabel), contentY + 54)

	lg.setColor(1, 1, 1, 0.12 * alpha)
	lg.rectangle("fill", contentX + 22, contentY + 92, leftW - 44, 2)
	local statsX, statsW = contentX + 22, leftW - 44
	local statsY, statsGap = contentY + 116, 51
	drawStatRow(L("runRecap.score"), formatNumber(State.score), statsX, statsY, statsW, alpha, colorGood)
	drawStatRow(L("runRecap.enemiesDefeated"), formatNumber(State.totalKills), statsX, statsY + statsGap, statsW, alpha)
	drawStatRow(L("runRecap.livesRemaining"), formatNumber(State.lives), statsX, statsY + statsGap * 2, statsW, alpha, State.totalLeaks == 0 and colorGood or colorText)
	drawStatRow(L("victory.towersPlaced"), formatNumber(result.towersPlaced), statsX, statsY + statsGap * 3, statsW, alpha)
	drawStatRow(L("victory.gameTime"), format("%d:%02d", floor((result.duration or 0) / 60), floor((result.duration or 0) % 60)), statsX, statsY + statsGap * 4, statsW, alpha)

	-- Damage and medals form the second column.
	local visibleDamageRows = min(6, #damageRows)
	local damageH = min(contentH - 116, visibleDamageRows > 0 and (54 + visibleDamageRows * 38) or 82)
	drawDamagePanel(rightX, contentY, rightW, damageH, alpha)
	local medalsY = contentY + damageH + 12
	local medalsH = contentH - damageH - 12
	drawCard(rightX, medalsY, rightW, medalsH, alpha)
	Fonts.set("ui")
	lg.setColor(colorText[1], colorText[2], colorText[3], 0.75 * alpha)
	Text.printShadow(L("victory.medalProgress"), rightX + 22, medalsY + 16)
	local clusterW, clusterH = Medals.getClusterSize(medalR, medalGap)
	Medals.drawReveal(
		rightX + (rightW - clusterW) * 0.5,
		medalsY + (medalsH - clusterH) * 0.5,
		medalR,
		medalGap,
		t
	)

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
	return runStats:isComplete() and Medals.isRevealComplete()
end

function Screen.finishAnimations()
	runStats:finish()
	Medals.finishReveal()
end

return Screen
