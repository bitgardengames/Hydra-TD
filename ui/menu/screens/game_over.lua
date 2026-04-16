local Theme = require("core.theme")
local Button = require("ui.button")
local Cursor = require("core.cursor")
local State = require("core.state")
local Achievements = require("systems.achievements")
local Sound = require("systems.sound")
local Difficulty = require("systems.difficulty")
local Text = require("ui.text")
local Fonts = require("core.fonts")
local Backdrop = require("scenes.backdrop")
local Steam = require("core.steam")
local Maps = require("world.map_defs")
local L = require("core.localization")

local lg = love.graphics

local floor = math.floor
local max = math.max

local Screen = {}

-- animation
local t = 0
local panelT = 0

local buttons = nil

local colorBad = Theme.ui.bad
local colorText = Theme.ui.text
local colorBackdrop = Theme.ui.backdrop
local colorDim = Theme.ui.screenDim
local colorOutline = Theme.outline.color
local colorButton = Theme.ui.button

local outlineW = Theme.outline.width
local baseRadius = 6 * 3
local outerRadius = baseRadius + outlineW * 0.5
local innerRadius = baseRadius - outlineW * 0.25

local paddingX = 24
local paddingY = 24

local btnW = 260
local btnH = 42
local gap = 62

local headerHeight = 36
local reasonSpacing = 36
local statsOffset = 28
local statsGapX = 14
local statsGapY = 12
local statH = 58
local difficultyOffset = 30
local tipOffset = 28
local buttonsOffset = 42

local contentStartY = 0
local titleY = 0
local reasonY = 0
local statsY = 0
local difficultyY = 0
local tipY = 0
local panelW = 560
local panelX = 0
local stats = {}

local function restartRun()
	Sound.play("uiConfirm")
	State.mode = "game"
	State.gameOver = false
	Sound.playMusic("gameplay")
	resetGame()
end

local function returnToMenu(playSound)
	if playSound ~= false then
		Sound.play("uiConfirm")
	end
	Backdrop.start()
	Steam.setRichPresence(L("presence.menu"))
	State.mode = "menu"
	Sound.playMusic("menu")
end

local function getDifficultyLabel()
	local key = Difficulty.key()
	return L("difficulty." .. key)
end

local function getMapName()
	local map = Maps[State.worldMapIndex]
	if not map then
		return "--"
	end

	return L(map.nameKey)
end

local function getRunTip()
	if State.endReason == L("game.bossBreach") then
		return L("gameOver.tipBossBreach")
	end

	if State.endReason == L("game.outOfLives") then
		return L("gameOver.tipOutOfLives")
	end

	return L("gameOver.tipDefault")
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

function Screen.enter()
	t = 0
	panelT = 0
	buildStats()
end

function Screen.load()
	local sw, sh = lg.getDimensions()
	local cx = floor(sw * 0.5)
	local startY = floor(sh * 0.5 + 40)

	buttons = {
		{
			id = "restart",
			label = L("menu.restart"),
			w = btnW,
			h = btnH,
			onClick = restartRun
		},
		{
			id = "menu",
			label = L("menu.mainMenu"),
			w = btnW,
			h = btnH,
			onClick = returnToMenu
		},
	}

	for i, btn in ipairs(buttons) do
		btn.x = cx - btn.w * 0.5
		btn.y = startY + (i - 1) * gap
	end
end

function Screen.update(dt)
	t = t + dt

	-- panel animation
	local speed = 4.5
	local pt = math.min(1, t * speed)
	panelT = pt * pt * (3 - 2 * pt)

	local sw, sh = lg.getDimensions()
	local cx = floor(sw * 0.5)

	panelW = math.min(560, sw - 64)
	panelX = cx - panelW * 0.5

	buildStats()

	contentStartY = floor(sh * 0.5 - 190)

	titleY = contentStartY
	reasonY = titleY + headerHeight + reasonSpacing
	statsY = reasonY + statsOffset
	local statRows = math.ceil(#stats / 2)
	difficultyY = statsY + statRows * statH + (statRows - 1) * statsGapY + difficultyOffset
	tipY = difficultyY + tipOffset

	local buttonsStartY = tipY + buttonsOffset

	for i, btn in ipairs(buttons) do
		btn.x = cx - btn.w * 0.5
		btn.y = buttonsStartY + (i - 1) * gap

		Button.update(btn, Cursor.x, Cursor.y, dt)
	end
end

function Screen.draw()
	local sw, sh = lg.getDimensions()
	local cx = floor(sw * 0.5)

	local count = #buttons
	local buttonsHeight = (count - 1) * gap + btnH

	local statRows = math.ceil(#stats / 2)
	local statsHeight = statRows * statH + (statRows - 1) * statsGapY
	local contentHeight = headerHeight
		+ reasonSpacing
		+ statsOffset
		+ statsHeight
		+ difficultyOffset
		+ tipOffset
		+ buttonsOffset
		+ buttonsHeight
	local boxW = panelW
	local boxH = contentHeight + paddingY * 2
	local boxX = panelX
	local boxY = contentStartY - paddingY

	-- Dim (keep static, subtle)
	lg.setColor(colorDim)
	lg.rectangle("fill", 0, 0, sw, sh)

	-- PANEL TRANSFORM
	local panelCX = boxX + boxW * 0.5
	local panelCY = boxY + boxH * 0.5

	local overshoot = 1.04
	local scale = 1 + (overshoot - 1) * (1 - panelT)
	local alpha = panelT

	lg.push()
	lg.translate(panelCX, panelCY)
	lg.scale(scale, scale)
	lg.translate(-panelCX, -panelCY)

	-- Panel outline
	lg.setColor(colorOutline[1], colorOutline[2], colorOutline[3], alpha)
	lg.rectangle("fill", boxX - outlineW, boxY - outlineW, boxW + outlineW * 2, boxH + outlineW * 2, outerRadius)

	-- Panel fill
	lg.setColor(colorBackdrop[1], colorBackdrop[2], colorBackdrop[3], alpha)
	lg.rectangle("fill", boxX, boxY, boxW, boxH, innerRadius)

	-- Title
	Fonts.set("title")
	lg.setColor(colorBad[1], colorBad[2], colorBad[3], alpha)
	Text.printfShadow(State.endTitle, 0, titleY, sw, "center")

	Fonts.set("menu")

	-- Reason
	if State.endReason then
		lg.setColor(colorText[1], colorText[2], colorText[3], alpha)
		Text.printfShadow(State.endReason, 0, reasonY, sw, "center")
	end

	-- Summary cards
	local cardW = (boxW - paddingX * 2 - statsGapX) * 0.5

	for i, item in ipairs(stats) do
		local row = floor((i - 1) / 2)
		local col = (i - 1) % 2
		local x = boxX + paddingX + col * (cardW + statsGapX)
		local y = statsY + row * (statH + statsGapY)

		lg.setColor(colorDim[1], colorDim[2], colorDim[3], 0.65 * alpha)
		lg.rectangle("fill", x, y, cardW, statH, 10, 10)

		lg.setColor(colorText[1], colorText[2], colorText[3], 0.72 * alpha)
		Fonts.set("ui")
		Text.printfShadow(item.label, x + 12, y + 9, cardW - 24, "left")

		lg.setColor(colorButton[1], colorButton[2], colorButton[3], alpha)
		Fonts.set("menu")
		Text.printfShadow(item.value, x + 12, y + 29, cardW - 24, "left")
	end

	Fonts.set("ui")
	lg.setColor(colorText[1], colorText[2], colorText[3], 0.8 * alpha)
	Text.printfShadow(getRunTip(), boxX + paddingX, tipY, boxW - paddingX * 2, "center")

	lg.setColor(colorText[1], colorText[2], colorText[3], 0.6 * alpha)
	Text.printfShadow(L("gameOver.shortcuts"), boxX + paddingX, tipY + 18, boxW - paddingX * 2, "center")

	-- Buttons
	for _, btn in ipairs(buttons) do
		btn.alpha = alpha
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

function Screen.keypressed(key)
	if key == "escape" then
		returnToMenu(false)
		Sound.play("uiBack")
	elseif key == "r" then
		restartRun()
	end
end

return Screen
