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
local RecordRows = require("ui.record_rows")
local RunModes = require("systems.run_modes")
local DefeatPresentation = require("ui.defeat_presentation")
local EdgeVignette = require("ui.edge_vignette")

local lg = love.graphics

local floor = math.floor

local Screen = {}
local selectedHeadline = nil
local selectedSubheadline = nil

-- animation
local t = 0
local panelT = 0

local buttons = nil

local colorBad = Theme.ui.bad
local colorText = Theme.ui.text
local colorBackdrop = Theme.ui.backdrop
local colorDim = Theme.ui.screenDim
local colorOutline = Theme.outline.color
local colorVignette = Theme.effects.colors.danger or Theme.ui.bad

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
local buttonsOffset = 34

local contentStartY = 0
local titleY = 0
local reasonY = 0
local highlightsY = 0
local difficultyY = 0
local panelW = 420
local panelX = 0
local runStats = AnimatedRunStats.new(Theme.ui.bad or Theme.ui.warn)

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
	local rows = {}
	if RunModes.isEndless(State) then
		rows[#rows + 1] = {label = "Wave", value = RunRecap.getReachedWave()}
		rows[#rows + 1] = {label = "Kills", value = State.totalKills or 0}
		local map = RunRecap.getMap()
		local records = map and Save.getMapRecords(map.id, RunModes.ENDLESS, RunRecap.getDifficultyKey())
		for _, row in ipairs(RecordRows.build(records, State.newRecords)) do rows[#rows + 1] = row end
	end
	runStats:setRows(rows)
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

	local reason = State.endReason
	if reason == L("game.outOfLives") then
		reason = nil
	elseif not reason then
		reason = L("gameOver.recapMid")
	end
	return State.endTitle or L("game.gameOver"), reason
end

function Screen.enter()
	t = 0
	panelT = 0
	buildRunSummary()
	selectedHeadline, selectedSubheadline = selectGameOverMessage()
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
	runStats:update(dt)

	local sw, sh = lg.getDimensions()
	local cx = floor(sw * 0.5)

	panelW = math.min(420, sw - 64)
	panelX = cx - panelW * 0.5

	local buttonsHeight = (#buttons - 1) * gap + btnH
	local subheadlineHeight = selectedSubheadline and subtitleSpacing or 0
	local contentHeight = headerHeight + subheadlineHeight + highlightOffset
		+ runStats:getHeight() + difficultyOffset + 24 + buttonsOffset + buttonsHeight
	contentStartY = floor((sh - contentHeight) * 0.5)

	titleY = contentStartY
	reasonY = titleY + headerHeight + subtitleSpacing
	highlightsY = titleY + headerHeight + subheadlineHeight + highlightOffset
	difficultyY = highlightsY + runStats:getHeight() + difficultyOffset

	local buttonsStartY = difficultyY + 24 + buttonsOffset

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
	local subheadlineHeight = selectedSubheadline and subtitleSpacing or 0
	local contentHeight = headerHeight
		+ subheadlineHeight
		+ highlightOffset
		+ highlightsHeight
		+ difficultyOffset
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

	-- Defeat-only atmosphere stays behind the recap so its content remains crisp.
	local reducedMotion = Save.data.settings.cameraMotion == false
	local vignetteAlpha = DefeatPresentation.vignetteAlpha(t, reducedMotion)
	EdgeVignette.draw(sw, sh, boxW + paddingX * 2, boxH + paddingY * 2, colorVignette, vignetteAlpha)

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
