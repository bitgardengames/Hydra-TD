local Theme = require("core.theme")
local Button = require("ui.button")
local State = require("core.state")
local Sound = require("systems.sound")
local Text = require("ui.text")
local Fonts = require("core.fonts")
local Backdrop = require("scenes.backdrop")
local Steam = require("core.steam")
local L = require("core.localization")
local Modules = require("systems.modules")
local RunStats = require("systems.run_stats")
local RunRecap = require("ui.run_recap")
local Save = require("core.save")
local Hotkeys = require("core.hotkeys")

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
local buttonFocus = Button.newFocus()

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
local subtitleSpacing = 28
local highlightOffset = 22
local highlightGap = 12
local highlightH = 52
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
local highlights = {}
local summaryLines = {}

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

	highlights = {
		{ label = L("gameOver.waveReached"), value = tostring(reachedWave) },
		{ label = L("gameOver.score"), value = tostring(score) },
	}
	RunStats.captureLoadout(Modules.active, State.selectedContracts or State.contracts)
	local summary = RunStats.summarize(State.money, State.score)
	State.runSummary = summary
	summaryLines = {
		string.format("MVP %s  •  Leak %s (%d)  •  Damage %s", summary.mvp, summary.leak, summary.leakCount, summary.damageType),
		"Build: " .. (summary.build ~= "" and summary.build or "none") .. (summary.paths ~= "" and "  •  " .. summary.paths or ""),
		summary.observation .. "  •  [C] Copy build code",
	}
	if State.isReplayMode() and (summary.modules ~= "" or summary.contracts ~= "") then
		table.insert(summaryLines, 3, "Modules: " .. (summary.modules ~= "" and summary.modules or "none") .. "  •  Contracts: " .. (summary.contracts ~= "" and summary.contracts or "none"))
	end
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
	Button.resetFocus(buttons, buttonFocus)
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
	Button.resetFocus(buttons, buttonFocus)

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

	contentStartY = floor(sh * 0.5 - 190)

	titleY = contentStartY
	reasonY = titleY + headerHeight + subtitleSpacing
	highlightsY = reasonY + highlightOffset
	difficultyY = highlightsY + highlightH + difficultyOffset
	tipY = difficultyY + tipOffset + 72

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

	local highlightsHeight = highlightH
	local contentHeight = headerHeight
		+ subtitleSpacing
		+ highlightOffset
		+ highlightsHeight
		+ difficultyOffset
		+ tipOffset
		+ 72
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

	-- Highlight strip
	local count = #highlights
	local totalGap = highlightGap * (count - 1)
	local cardW = (boxW - paddingX * 2 - totalGap) / count

	for i, item in ipairs(highlights) do
		local x = boxX + paddingX + (i - 1) * (cardW + highlightGap)
		local y = highlightsY

		lg.setColor(colorDim[1], colorDim[2], colorDim[3], 0.6 * alpha)
		lg.rectangle("fill", x, y, cardW, highlightH, 10, 10)

		lg.setColor(colorText[1], colorText[2], colorText[3], 0.68 * alpha)
		Fonts.set("ui")
		Text.printfShadow(item.label, x + 10, y + 8, cardW - 20, "left")

		lg.setColor(colorButton[1], colorButton[2], colorButton[3], alpha)
		Fonts.set("menu")
		Text.printfShadow(item.value, x + 10, y + 28, cardW - 20, "left")
	end

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
	for i, line in ipairs(summaryLines) do
		Text.printfShadow(line, boxX + paddingX, difficultyY + 17 + (i - 1) * 15, boxW - paddingX * 2, "center")
	end

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
	return Button.mousepressedList(buttons, x, y, button, buttonFocus)
end

function Screen.mousereleased(x, y, button)
	return Button.mousereleasedList(buttons, x, y, button)
end

function Screen.keypressed(key)
	if key == "c" and State.runSummary then
		love.system.setClipboardText(State.runSummary.code)
		return true
	elseif key == Hotkeys.getActionKey("returnToMenu") then
		returnToMenu(false)
		Sound.play("uiBack")
	elseif key == Hotkeys.getActionKey("restartRun") then
		restartRun()
	else
		return Button.keypressedList(buttons, buttonFocus, key)
	end
end

return Screen
