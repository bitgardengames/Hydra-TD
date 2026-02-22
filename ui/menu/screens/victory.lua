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
local Screen = {}

local buttons = nil

local colorGood = Theme.ui.good
local colorText = Theme.ui.text

local function getDifficultyLabel()
    local key = Difficulty.key()

    return L("difficulty." .. key)
end

function Screen.load()
    local sw, sh = lg.getDimensions()
    local cx = math.floor(sw * 0.5)
    local startY = math.floor(sh * 0.5 + 40)
    local gap = 58

    buttons = {
        {
            id = "next",
            label = L("menu.nextMap"),
            w = 240,
            h = 46,
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
            w = 240,
            h = 46,
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
            w = 240,
            h = 46,
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

    -- Dim background
    lg.setColor(0, 0, 0, 0.55)
    lg.rectangle("fill", 0, 0, sw, sh)

    -- Title
    Fonts.set("title")

    lg.setColor(colorGood)
	Text.printfShadow(L("game.victory"), 0, sh * 0.5 - 120, sw, "center")

	Fonts.set("menu")

	-- Difficulty
	local difficultyLabel = getDifficultyLabel()

	if difficultyLabel then
		lg.setColor(colorText)
		Text.printfShadow(string.format("%s: %s", L("settings.difficulty"), difficultyLabel), 0, screenHalf - 64, sw, "center")
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