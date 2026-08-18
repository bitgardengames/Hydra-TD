local Theme = require("core.theme")
local Button = require("ui.button")
local State = require("core.state")
local Sound = require("systems.sound")
local Text = require("ui.text")
local Fonts = require("core.fonts")
local Backdrop = require("scenes.backdrop")
local Steam = require("core.steam")
local L = require("core.localization")
local RunRecap = require("ui.run_recap")
local Save = require("core.save")
local Hotkeys = require("core.hotkeys")
local AnimatedRunStats = require("ui.animated_run_stats")
local CampaignWaveDefs = require("systems.campaign_wave_defs")

local lg = love.graphics

local floor = math.floor

local Screen = {}
local selectedHeadline = nil
local selectedSubheadline = nil
local shortcutsText = nil

-- animation
local t = 0
local panelT = 0

local buttons = nil

local colorBad = Theme.ui.bad
local colorText = Theme.ui.text
local colorBackdrop = Theme.ui.backdrop
local colorDim = Theme.ui.screenDim
local colorOutline = Theme.outline.color

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
local subtitleSpacing = 28
local highlightOffset = 22
local difficultyOffset = 18
local tipOffset = 16
local buttonsOffset = 34

local contentStartY = 0
local titleY = 0
local reasonY = 0
local highlightsY = 0
local difficultyY = 0
local tipY = 0
local panelW = 560
local panelX = 0
local runStats = AnimatedRunStats.new(Theme.ui.bad or Theme.ui.warn)

local function buildShortcutsText()
	local unbound = L("settings.controlUnbound")
	local restartKey = Hotkeys.getDisplay("restartRun") or unbound
	local menuKey = Hotkeys.getDisplay("returnToMenu") or unbound

	shortcutsText = L("gameOver.shortcuts", restartKey, menuKey)
end

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
	Save.flush()
	State.mode = "menu"
	Sound.playMusic("menu")
end

local function buildRunSummary()
	local reachedWave = RunRecap.getReachedWave()
	local score = State.score or 0

	local map = RunRecap.getMap()
	runStats:setRows({
		{label = L("runRecap.enemiesDefeated"), value = State.spawnedKills or 0,
			denominator = CampaignWaveDefs.getTotalEnemyCount(map)},
		{label = L("runRecap.wavesReached"), value = reachedWave,
			denominator = CampaignWaveDefs.getFinalWave(map)},
		{label = L("runRecap.score"), value = score},
	})
end

local function selectGameOverMessage()
	local reachedWave = RunRecap.getReachedWave()
	local lateWave = RunRecap.isLateWave(reachedWave)
	local leaks = State.totalLeaks or 0
	local lives = State.lives or 0
	local diff = RunRecap.getDifficultyKey()

	if lateWave and (leaks <= 6 or lives <= 3) then
		return L("gameOver.headline.lateWave"), L("gameOver.subheadline.lateWave")
	end

	if diff == "hard" and reachedWave >= 10 then
		return L("gameOver.headline.hardFight"), L("gameOver.subheadline.hardFight")
	end

	return State.endTitle or L("game.gameOver"), State.endReason or L("gameOver.recapMid")
end

function Screen.enter()
	t = 0
	panelT = 0
	buildShortcutsText()
	buildRunSummary()
	selectedHeadline, selectedSubheadline = selectGameOverMessage()
end

function Screen.load()
	buildShortcutsText()
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
	runStats:update(dt)

	local sw, sh = lg.getDimensions()
	local cx = floor(sw * 0.5)

	panelW = math.min(560, sw - 64)
	panelX = cx - panelW * 0.5

	local buttonsHeight = (#buttons - 1) * gap + btnH
	local contentHeight = headerHeight + subtitleSpacing + highlightOffset
		+ runStats:getHeight() + difficultyOffset + tipOffset + 24 + buttonsOffset + buttonsHeight
	contentStartY = floor((sh - contentHeight) * 0.5)

	titleY = contentStartY
	reasonY = titleY + headerHeight + subtitleSpacing
	highlightsY = reasonY + highlightOffset
	difficultyY = highlightsY + runStats:getHeight() + difficultyOffset
	tipY = difficultyY + tipOffset + 24

	local buttonsStartY = tipY + buttonsOffset

	local mx, my = love.mouse.getPosition()
	for i, btn in ipairs(buttons) do
		btn.x = cx - btn.w * 0.5
		btn.y = buttonsStartY + (i - 1) * gap
	end
	Button.updateList(buttons, dt, mx, my)
end

function Screen.draw()
	local sw, sh = lg.getDimensions()

	local count = #buttons
	local buttonsHeight = (count - 1) * gap + btnH

	local highlightsHeight = runStats:getHeight()
	local contentHeight = headerHeight
		+ subtitleSpacing
		+ highlightOffset
		+ highlightsHeight
		+ difficultyOffset
		+ tipOffset
		+ 24
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
	Text.printfShadow(selectedHeadline or State.endTitle or L("game.gameOver"), 0, titleY, sw, "center")

	Fonts.set("menu")

	-- Reason / subtitle
	if selectedSubheadline then
		lg.setColor(colorText[1], colorText[2], colorText[3], alpha)
		Text.printfShadow(selectedSubheadline, 0, reasonY, sw, "center")
	end

	runStats:draw(boxX + paddingX, highlightsY, boxW - paddingX * 2, alpha)

	-- Map/difficulty context
	Fonts.set("ui")
	lg.setColor(colorText[1], colorText[2], colorText[3], 0.74 * alpha)
	local contextLine = string.format(
		"%s: %s  •  %s: %s",
		L("gameOver.map"),
		RunRecap.getMapName(),
		L("gameOver.difficultyLabel"),
		RunRecap.getDifficultyLabel() or "--"
	)
	Text.printfShadow(contextLine, boxX + paddingX, difficultyY, boxW - paddingX * 2, "center")
	lg.setColor(colorText[1], colorText[2], colorText[3], 0.6 * alpha)
	Text.printfShadow(shortcutsText, boxX + paddingX, tipY, boxW - paddingX * 2, "center")

	-- Buttons
	for _, btn in ipairs(buttons) do
		btn.alpha = alpha
	end
	Button.drawList(buttons)

	lg.pop()
end

function Screen.mousepressed(x, y, button)
	if button == 1 and not runStats:isComplete() then
		runStats:finish()
		return true
	end
	return Button.mousepressedList(buttons, x, y, button)
end

function Screen.mousereleased(x, y, button)
	return Button.mousereleasedList(buttons, x, y, button)
end

function Screen.keypressed(key)
	if (key == "return" or key == "kpenter" or key == "space") and not runStats:isComplete() then
		runStats:finish()
		return true
	elseif key == Hotkeys.getActionKey("returnToMenu") then
		returnToMenu(false)
		Sound.play("uiBack")
	elseif key == Hotkeys.getActionKey("restartRun") then
		restartRun()
	end
end

return Screen
