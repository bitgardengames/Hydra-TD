-- ui/menu/screens/victory.lua
local Theme = require("core.theme")
local Button = require("ui.button")
local Cursor = require("core.cursor")
local State = require("core.state")
local Sound = require("systems.sound")
local Difficulty = require("systems.difficulty")
local Text = require("ui.text")
local Fonts = require("core.fonts")
local Backdrop = require("scenes.backdrop")
local Steam = require("core.steam")
local L = require("core.localization")

local lg = love.graphics

local min = math.min
local floor = math.floor
local format = string.format

local Screen = {}

local buttons = nil

local colorGood = Theme.ui.good
local colorText = Theme.ui.text
local colorBackdrop = Theme.ui.backdrop
local colorDim = Theme.ui.screenDim
local colorOutline = Theme.outline.color

local outlineW = Theme.outline.width
local baseRadius = 6 * 3
local outerRadius = baseRadius + outlineW * 0.5
local innerRadius = baseRadius - outlineW * 0.25

-- Match pause/game_over
local paddingX = 24
local paddingY = 24
local corner = 18

local btnW = 240
local btnH = 42
local gap = 62

local headerHeight = 36
local headerSpacing = 38
local difficultySpacing = 36

local function getDifficultyLabel()
	local key = Difficulty.key()

	return L("difficulty." .. key)
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
				State.mapIndex = State.worldMapIndex
				State.gameOver = false
				State.victory = false
				State.mode = "game"
				resetGame()
			end
		},

		{
			id = "endless",
			label = L("menu.endless"),
			w = btnW,
			h = btnH,
			onClick = function()
				Sound.play("uiConfirm")
				State.endless = true
				State.gameOver = false
				State.victory = false
				State.mode = "game"
			end
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

	local sw, sh = lg.getDimensions()
	local cx = floor(sw * 0.5)

	local contentStartY = floor(sh * 0.5 - 110)

	local buttonsStartY = contentStartY + headerHeight + headerSpacing + difficultySpacing

    for i, btn in ipairs(buttons) do
		btn.x = cx - btn.w * 0.5
		btn.y = buttonsStartY + (i - 1) * gap
    end
end

function Screen.update(dt)
	local sw, sh = lg.getDimensions()
	local cx = floor(sw * 0.5)

	local contentStartY = floor(sh * 0.5 - 110)

	local buttonsStartY = contentStartY + headerHeight + headerSpacing + difficultySpacing

	for i, btn in ipairs(buttons) do
		btn.x = cx - btn.w * 0.5
		btn.y = buttonsStartY + (i - 1) * gap
		Button.update(btn, Cursor.x, Cursor.y, dt)
	end
end

function Screen.draw()
	local sw, sh = lg.getDimensions()
	local cx = floor(sw * 0.5)

	local contentStartY = floor(sh * 0.5 - 110)

	local count = #buttons
	local buttonsHeight = (count - 1) * gap + btnH

	local contentHeight = headerHeight + headerSpacing + difficultySpacing + buttonsHeight

	local boxW = btnW + paddingX * 2
	local boxH = contentHeight + paddingY * 2
	local boxX = cx - boxW * 0.5
	local boxY = contentStartY - paddingY

	-- Dim background
	lg.setColor(colorDim)
	lg.rectangle("fill", 0, 0, sw, sh)

	-- Panel
	lg.setColor(colorOutline)
	lg.rectangle("fill", boxX - outlineW, boxY - outlineW, boxW + outlineW * 2, boxH + outlineW * 2, outerRadius)

	lg.setColor(colorBackdrop)
	lg.rectangle("fill", boxX, boxY, boxW, boxH, innerRadius)

	-- Optional grounding shadow (recommended)
	lg.setColor(0, 0, 0, 0.18)
	lg.ellipse("fill", boxX + boxW * 0.5, boxY + boxH + 6, boxW * 0.45, 8)

	-- Title
	local titleY = boxY + paddingY

	Fonts.set("title")

	lg.setColor(colorGood)
	Text.printfShadow(L("game.victory"), 0, titleY, sw, "center")

	Fonts.set("menu")

	-- Difficulty
	local difficultyLabel = getDifficultyLabel()

	if difficultyLabel then
		local difficultyY = titleY + headerHeight + headerSpacing - 12

		lg.setColor(colorText[1], colorText[2], colorText[3], 0.75)
		Text.printfShadow(
			format("%s: %s", L("settings.difficulty"), difficultyLabel),
			0,
			difficultyY,
			sw,
			"center"
		)
	end

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

function Screen.keypressed(key)
	if key == "escape" then
		Steam.setRichPresence(L("presence.menu"))
		State.mode = "menu"
	end
end

return Screen