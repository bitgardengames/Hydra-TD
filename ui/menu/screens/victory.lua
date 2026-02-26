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

local floor = math.floor
local format = string.format

local Screen = {}

local buttons = nil

local colorGood = Theme.ui.good
local colorText = Theme.ui.text
local colorBackdrop = Theme.ui.backdrop
local colorDim = Theme.ui.screenDim

local paddingX = 60
local paddingY = 44
local corner = 18

local btnW = 240
local btnH = 46
local gap = 58

local function getDifficultyLabel()
    local key = Difficulty.key()

    return L("difficulty." .. key)
end

function Screen.load()
    local sw, sh = lg.getDimensions()
    local cx = floor(sw * 0.5)
    local startY = floor(sh * 0.5 + 40)

    buttons = {
        {
            id = "next",
            label = L("menu.nextMap"),
            w = btnW,
            h = btnH,
            onClick = function()
                Sound.play("uiConfirm")

                -- Advance to next map
                State.worldMapIndex = State.worldMapIndex + 1
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

    for i, btn in ipairs(buttons) do
        btn.x = cx - btn.w * 0.5
        btn.y = startY + (i - 1) * gap
    end
end

function Screen.update(dt)
    for _, btn in ipairs(buttons) do
        Button.update(btn, Cursor.x, Cursor.y, dt)
    end
end

function Screen.draw()
	local sw, sh = lg.getDimensions()
	local screenHalf = sh * 0.5
	local cx = floor(sw * 0.5)

	local titleY = screenHalf - 120
	local bottomY = buttons[#buttons].y + btnH

	local boxW = btnW + paddingX * 2
	local boxX = cx - boxW * 0.5
	local boxY = titleY - paddingY
	local boxH = (bottomY + paddingY) - boxY

	-- Dim background
	lg.setColor(colorDim)
	lg.rectangle("fill", 0, 0, sw, sh)

	-- Backdrop panel
	lg.setColor(colorBackdrop)
	lg.rectangle("fill", boxX, boxY, boxW, boxH, corner, corner)

	-- Title
	Fonts.set("menu")

	lg.setColor(colorGood)
	Text.printfShadow(L("game.victory"), 0, titleY, sw, "center")

	-- Difficulty
	local difficultyLabel = getDifficultyLabel()

	if difficultyLabel then
		lg.setColor(colorText)
		Text.printfShadow(format("%s: %s", L("settings.difficulty"), difficultyLabel), 0, screenHalf - 64, sw, "center")
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

function Screen.keypressed(key)
    if key == "escape" then
		Steam.setRichPresence(L("presence.menu"))
        State.mode = "menu"
    end
end

return Screen