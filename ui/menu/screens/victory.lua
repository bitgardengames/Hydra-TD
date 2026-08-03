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
local Modules = require("systems.modules")
local RunStats = require("systems.run_stats")

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
local selectedHeadline = nil
local selectedSubheadline = nil

local buttons = nil
local previousMedalCount = 0
local currentMedalCount = 0
local stats = {}
local confetti = {}
local t = 0
local panelT = 0
local recapScroll = 0
local layout = nil

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

local function getDifficultyLabel()
	local key = Difficulty.key()
	return L("difficulty." .. key)
end

local function getCompletionTier()
	local completed = Save.data
		and Save.data.mapStats
		and Save.data.mapStats[Maps[State.worldMapIndex] and Maps[State.worldMapIndex].id or ""]
		and Save.data.mapStats[Maps[State.worldMapIndex].id].completedDifficulty
	return completed or "none"
end

local function selectVictoryMessage()
	local score = State.score or 0
	local leaks = State.totalLeaks or 0
	local lives = State.lives or 0
	local map = Maps[State.worldMapIndex]
	local mapId = map and map.id or nil
	local completionTier = getCompletionTier()
	local diff = Difficulty.key()
	local scoreBand = score >= 25000 and "high" or (score >= 10000 and "mid" or "low")

	local firstClear = mapId and not (Save.data.meta.clearedMaps and Save.data.meta.clearedMaps[mapId]) or false
	State.wasFirstClear = firstClear

	if mapId and firstClear then
		Save.data.meta.clearedMaps[mapId] = true
		Save.flush()
	end

	if scoreBand == "high" and leaks == 0 and lives >= 15 then
		return L("victory.headline.highPerformance"), L("victory.subheadline.highPerformance")
	end

	if firstClear then
		return L("victory.headline.firstClear"), L("victory.subheadline.firstClear")
	end

	if completionTier ~= "none" or diff == "hard" then
		return L("victory.headline.repeatClear"), L("victory.subheadline.repeatClear")
	end

	return L("game.victory"), L("victory.subtitle")
end

local function calculateLayout()
	local sw, sh = lg.getDimensions()
	local cx = floor(sw * 0.5)
	local compact = sh < 720
	local edge = compact and 10 or 24
	local boxW = min(panelW, sw - edge * 2)
	local boxX = cx - boxW * 0.5
	local boxY = edge
	local boxH = sh - edge * 2
	local padX = min(paddingX, max(12, boxW * 0.05))
	local padY = compact and 12 or paddingY
	local buttonGap = compact and 8 or 14
	local buttonHeight = compact and 36 or btnH
	local buttonsHeight = #buttons * buttonHeight + max(0, #buttons - 1) * buttonGap
	local buttonsStartY = boxY + boxH - padY - buttonsHeight
	local titleHeight = compact and 54 or 76
	local recapY = boxY + padY + titleHeight
	local recapBottom = buttonsStartY - (compact and 8 or 18)
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
	local viewportH = max(0, recapBottom - recapY)
	recapScroll = min(max(0, recapScroll), max(0, recapContentH - viewportH))

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

local function getMapName()
	local map = Maps[State.worldMapIndex]
	if not map then
		return "--"
	end

	return L(map.nameKey)
end

local function buildStats()
	local reachedWave = State.inPrep and max(1, State.wave - 1) or State.wave
	RunStats.captureLoadout(Modules.active, State.selectedContracts or State.contracts)
	local summary = RunStats.summarize(State.money, State.score)
	State.runSummary = summary
	stats = {
		{ label = L("gameOver.waveReached"), value = tostring(reachedWave) },
		{ label = "Run leaders", value = string.format("MVP %s  •  Leak %s (%d)  •  Damage %s", summary.mvp, summary.leak, summary.leakCount, summary.damageType) },
		{ label = "Final build", value = (summary.build ~= "" and summary.build or "none") .. (summary.paths ~= "" and "  •  " .. summary.paths or "") },
		{ label = "Modules / contracts", value = (summary.modules ~= "" and summary.modules or "none") .. "  /  " .. (summary.contracts ~= "" and summary.contracts or "none") },
		{ label = "Coach / share", value = summary.observation .. "  •  [C] Copy build code" },
	}
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
			enabled = not Constants.IS_DEMO,
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
	recapScroll = 0
	buildStats()
	resetConfetti()
	Medals.resetAnimations()
	selectedHeadline, selectedSubheadline = selectVictoryMessage()

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

	Medals.update(dt)
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

	for _, btn in ipairs(buttons) do
		local mx, my = love.mouse.getPosition()
		Button.update(btn, mx, my, dt)
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
	Text.printfShadow(selectedHeadline or L("game.victory"), boxX + g.padX, titleY, boxW - g.padX * 2, "center")

	Fonts.set(g.compact and "ui" or "menu")
	lg.setColor(colorText[1], colorText[2], colorText[3], 0.85 * alpha)
	Text.printfShadow(selectedSubheadline or L("victory.subtitle"), boxX + g.padX, titleY + (g.compact and 25 or 36), boxW - g.padX * 2, "center")

	-- The recap may scroll, but the heading and action buttons remain outside its clip.
	lg.setScissor(g.boxX, g.recapY, g.boxW, g.recapH)
	local statsY = g.recapY - recapScroll
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
	local difficultyLabel = getDifficultyLabel()
	local difficultyY = statsY + g.difficultyY

	if difficultyLabel then
		Fonts.set("ui")
		lg.setColor(colorText[1], colorText[2], colorText[3], 0.78 * alpha)
		Text.printfShadow(format("%s: %s  •  %s: %s", L("gameOver.map"), getMapName(), L("settings.difficulty"), difficultyLabel), boxX + g.padX, difficultyY, boxW - g.padX * 2, "center")
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
	for _, btn in ipairs(buttons) do
		Button.draw(btn)
	end

	lg.pop()
end

function Screen.wheelmoved(_, y)
	if not layout or layout.recapContentH <= layout.recapH then return end
	recapScroll = min(max(0, recapScroll - y * 36), layout.recapContentH - layout.recapH)
end

function Screen.mousepressed(x, y, button)
	for _, btn in ipairs(buttons) do
		if Button.mousepressed(btn, x, y, button) then
			return true
		end
	end
end

function Screen.mousereleased(x, y, button)
	for _, btn in ipairs(buttons) do
		if Button.mousereleased(btn, x, y, button) then
			return true
		end
	end
end

function Screen.keypressed(key)
	if key == "c" and State.runSummary then
		love.system.setClipboardText(State.runSummary.code)
		return true
	elseif key == "escape" then
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
