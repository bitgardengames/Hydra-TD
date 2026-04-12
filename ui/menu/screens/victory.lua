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
local format = string.format

local Screen = {}

local buttons = nil
local previousMedalCount = 0
local currentMedalCount = 0

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
local gap = 62

local headerHeight = 36
local headerSpacing = 42
local difficultySpacing = 32
local medalSpacing = 64
local buttonsOffset = 32

-- Medal visuals
local medalR = 16
local medalGap = 14

local function getDifficultyLabel()
	local key = Difficulty.key()
	return L("difficulty." .. key)
end

-- 🧠 IMPORTANT: initialize positions here (fixes crash)
local function layoutButtons()
	local sw, sh = lg.getDimensions()
	local cx = floor(sw * 0.5)

	local contentStartY = floor(sh * 0.5 - 120)
	local buttonsStartY = contentStartY
		+ headerHeight
		+ headerSpacing
		+ difficultySpacing
		+ medalSpacing
		+ buttonsOffset

	for i, btn in ipairs(buttons) do
		btn.x = cx - btn.w * 0.5
		btn.y = buttonsStartY + (i - 1) * gap
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

	layoutButtons() -- ✅ FIX
end

function Screen.enter()
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
	layoutButtons() -- keep responsive

	Medals.update(dt)

	for _, btn in ipairs(buttons) do
		Button.update(btn, Cursor.x, Cursor.y, dt)
	end
end

function Screen.draw()
	local sw, sh = lg.getDimensions()
	local cx = floor(sw * 0.5)

	local contentStartY = floor(sh * 0.5 - 120)

	local count = #buttons
	local buttonsHeight = (count - 1) * gap + btnH

	local contentHeight =
		headerHeight
		+ headerSpacing
		+ difficultySpacing
		+ medalSpacing
		+ buttonsOffset
		+ buttonsHeight

	local boxW = btnW + paddingX * 2
	local boxH = contentHeight + paddingY * 2
	local boxX = cx - boxW * 0.5
	local boxY = contentStartY - paddingY

	-- Dim world
	lg.setColor(colorDim)
	lg.rectangle("fill", 0, 0, sw, sh)

	-- Panel
	lg.setColor(colorOutline)
	lg.rectangle("fill", boxX - outlineW, boxY - outlineW, boxW + outlineW * 2, boxH + outlineW * 2, outerRadius)

	lg.setColor(colorBackdrop)
	lg.rectangle("fill", boxX, boxY, boxW, boxH, innerRadius)

	-- Title
	local titleY = boxY + paddingY

	Fonts.set("title")
	lg.setColor(colorGood)
	Text.printfShadow(L("game.victory"), 0, titleY, sw, "center")

	Fonts.set("menu")

	-- Difficulty
	local difficultyLabel = getDifficultyLabel()
	local difficultyY = titleY + headerHeight + headerSpacing - 12

	if difficultyLabel then
		lg.setColor(colorText[1], colorText[2], colorText[3], 0.75)
		Text.printfShadow(format("%s: %s", L("settings.difficulty"), difficultyLabel), 0, difficultyY, sw, "center")
	end

	-- Medals
	local clusterW, clusterH = Medals.getClusterSize(medalR, medalGap)
	local medalX = cx - clusterW * 0.5

	local medalTop = difficultyY + difficultySpacing
	local buttonsStartY = contentStartY
		+ headerHeight
		+ headerSpacing
		+ difficultySpacing
		+ medalSpacing
		+ buttonsOffset

	local medalBottom = buttonsStartY - buttonsOffset
	local medalY = medalTop + (medalBottom - medalTop - clusterH) * 0.5

	lg.setColor(colorDim)
	lg.rectangle("fill", medalX - 16, medalY - 12, clusterW + 32, clusterH + 24, 14, 14)

	Medals.drawReveal(medalX, medalY, medalR, medalGap)

	-- Buttons
	for _, btn in ipairs(buttons) do
		Button.draw(btn)
	end
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