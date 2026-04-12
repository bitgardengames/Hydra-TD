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
local L = require("core.localization")

local lg = love.graphics

local floor = math.floor
local format = string.format

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

local outlineW = Theme.outline.width
local baseRadius = 6 * 3
local outerRadius = baseRadius + outlineW * 0.5
local innerRadius = baseRadius - outlineW * 0.25

local paddingX = 24
local paddingY = 24

local btnW = 240
local btnH = 42
local gap = 62

local headerHeight = 36
local headerSpacing = 30
local reasonSpacing = 32
local buttonsOffset = 48

local contentStartY = 0
local titleY = 0
local reasonY = 0
local difficultyY = 0

local function getDifficultyLabel()
	local key = Difficulty.key()
	return L("difficulty." .. key)
end

function Screen.enter()
	t = 0
	panelT = 0
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
			onClick = function()
				Sound.play("uiConfirm")
				State.mode = "game"
				State.gameOver = false
				Sound.playMusic("gameplay")
				resetGame()
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
				Sound.playMusic("menu")
			end
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

	contentStartY = floor(sh * 0.5 - 110)

	titleY = contentStartY
	reasonY = titleY + headerHeight + headerSpacing
	difficultyY = reasonY + reasonSpacing

	local buttonsStartY = difficultyY + buttonsOffset

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

	local contentHeight = headerHeight + headerSpacing + reasonSpacing + buttonsOffset + buttonsHeight

	local boxW = btnW + paddingX * 2
	local boxH = contentHeight + paddingY * 2
	local boxX = cx - boxW * 0.5
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

	-- Difficulty
	local difficultyLabel = getDifficultyLabel()

	if difficultyLabel then
		lg.setColor(colorText[1], colorText[2], colorText[3], 0.7 * alpha)
		Text.printfShadow(format("%s: %s", L("settings.difficulty"), difficultyLabel), 0, difficultyY, sw, "center")
	end

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
		State.mode = "menu"
		Steam.setRichPresence(L("presence.menu"))
		Sound.play("uiBack")
	end
end

return Screen