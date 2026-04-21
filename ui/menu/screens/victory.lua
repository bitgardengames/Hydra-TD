local Theme = require("core.theme")
local Constants = require("core.constants")
local Button = require("ui.button")
local Cursor = require("core.cursor")
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
local gap = 62
local panelW = 560

local headerHeight = 36
local subheadSpacing = 30
local statsOffset = 24
local statsGapX = 14
local statsGapY = 12
local statH = 56
local difficultyOffset = 24
local medalSpacing = 56
local hintOffset = 26
local buttonsOffset = 34

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

local function layoutButtons()
	local sw, sh = lg.getDimensions()
	local cx = floor(sw * 0.5)
	local contentStartY = floor(sh * 0.5 - 220)
	local statRows = math.ceil(#stats / 2)
	local statsHeight = statRows * statH + (statRows - 1) * statsGapY

	local buttonsStartY = contentStartY
		+ headerHeight
		+ subheadSpacing
		+ statsOffset
		+ statsHeight
		+ difficultyOffset
		+ medalSpacing
		+ hintOffset
		+ buttonsOffset

	for i, btn in ipairs(buttons) do
		btn.x = cx - btn.w * 0.5
		btn.y = buttonsStartY + (i - 1) * gap
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
	stats = {
		{ label = L("gameOver.map"), value = getMapName() },
		{ label = L("gameOver.waveReached"), value = tostring(reachedWave) },
		{ label = L("gameOver.score"), value = tostring(State.score or 0) },
		{ label = L("gameOver.leaks"), value = tostring(State.totalLeaks or 0) },
		{ label = L("gameOver.livesRemaining"), value = tostring(max(0, State.lives or 0)) },
		{ label = L("gameOver.difficultyLabel"), value = getDifficultyLabel() or "--" },
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
	buildStats()
	resetConfetti()
	Medals.resetAnimations()

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

	layoutButtons()
	buildStats()

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
		Button.update(btn, Cursor.x, Cursor.y, dt)
	end
end

function Screen.draw()
	local sw, sh = lg.getDimensions()
	local cx = floor(sw * 0.5)

	local boxWidth = min(panelW, sw - 56)
	local contentStartY = floor(sh * 0.5 - 220)
	local statRows = math.ceil(#stats / 2)
	local statsHeight = statRows * statH + (statRows - 1) * statsGapY

	local count = #buttons
	local buttonsHeight = (count - 1) * gap + btnH

	local contentHeight =
		headerHeight
		+ subheadSpacing
		+ statsOffset
		+ statsHeight
		+ difficultyOffset
		+ medalSpacing
		+ hintOffset
		+ buttonsOffset
		+ buttonsHeight

	local boxW = boxWidth
	local boxH = contentHeight + paddingY * 2
	local boxX = cx - boxW * 0.5
	local boxY = contentStartY - paddingY

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
	local titleY = boxY + paddingY

	Fonts.set("title")
	lg.setColor(colorGood[1], colorGood[2], colorGood[3], alpha)
	Text.printfShadow(L("game.victory"), 0, titleY, sw, "center")


	local statsY = titleY + headerHeight + subheadSpacing
	local cardW = (boxW - paddingX * 2 - statsGapX) * 0.5
	for i, item in ipairs(stats) do
		local row = floor((i - 1) / 2)
		local col = (i - 1) % 2
		local x = boxX + paddingX + col * (cardW + statsGapX)
		local y = statsY + row * (statH + statsGapY)

		lg.setColor(colorDim[1], colorDim[2], colorDim[3], 0.6 * alpha)
		lg.rectangle("fill", x, y, cardW, statH, 10, 10)

		Fonts.set("ui")
		lg.setColor(colorText[1], colorText[2], colorText[3], 0.74 * alpha)
		Text.printfShadow(item.label, x + 12, y + 8, cardW - 24, "left")

		Fonts.set("menu")
		lg.setColor(colorButton[1], colorButton[2], colorButton[3], alpha)
		Text.printfShadow(item.value, x + 12, y + 28, cardW - 24, "left")
	end

	-- Difficulty
	local difficultyLabel = getDifficultyLabel()
	local difficultyY = statsY + statsHeight + difficultyOffset

	if difficultyLabel then
		Fonts.set("ui")
		lg.setColor(colorText[1], colorText[2], colorText[3], 0.78 * alpha)
		Text.printfShadow(format("%s: %s", L("settings.difficulty"), difficultyLabel), 0, difficultyY, sw, "center")
	end

	-- Medals
	local clusterW, clusterH = Medals.getClusterSize(medalR, medalGap)
	local medalX = cx - clusterW * 0.5

	local medalTop = difficultyY + 20
	local buttonsStartY = contentStartY
		+ headerHeight
		+ subheadSpacing
		+ statsOffset
		+ statsHeight
		+ difficultyOffset
		+ medalSpacing
		+ hintOffset
		+ buttonsOffset

	local medalBottom = buttonsStartY - hintOffset - buttonsOffset
	local medalY = medalTop + (medalBottom - medalTop - clusterH) * 0.5

	lg.setColor(colorDim[1], colorDim[2], colorDim[3], 0.75 * alpha)
	lg.rectangle("fill", medalX - 16, medalY - 12, clusterW + 32, clusterH + 24, 14, 14)

	Medals.drawReveal(medalX, medalY, medalR, medalGap)

	Fonts.set("ui")
	lg.setColor(colorText[1], colorText[2], colorText[3], 0.75 * alpha)
	Text.printfShadow(L("victory.medalProgress"), 0, medalY - 20, sw, "center")

	local hintY = medalY + clusterH + hintOffset - 4
	lg.setColor(colorText[1], colorText[2], colorText[3], 0.72 * alpha)
	Text.printfShadow(L("victory.hint"), boxX + paddingX, hintY, boxW - paddingX * 2, "center")

	lg.setColor(colorText[1], colorText[2], colorText[3], 0.56 * alpha)
	Text.printfShadow(L("victory.shortcuts"), boxX + paddingX, hintY + 16, boxW - paddingX * 2, "center")

	-- Buttons
	for _, btn in ipairs(buttons) do
		Button.draw(btn)
	end

	lg.pop()
end

function Screen.mousepressed(x, y, button)
	for _, btn in ipairs(buttons) do
		if Button.mousepressed(btn, Cursor.x, Cursor.y, button) then
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

return Screen
