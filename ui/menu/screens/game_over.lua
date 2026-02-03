local Theme = require("core.theme")
local Button = require("ui.button")
local Cursor = require("core.cursor")
local State = require("core.state")
local Sound = require("systems.sound")
local Difficulty = require("systems.difficulty")
local Fonts = require("core.fonts")
local L = require("core.localization")

local lg = love.graphics
local Screen = {}

local buttons = nil

local colorBad = Theme.ui.bad

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
            id = "restart",
            label = L("menu.restart"),
            w = 240,
            h = 46,
            onClick = function()
                Sound.play("uiConfirm")
                State.mode = "game"
                State.gameOver = false
                resetGame()
            end
        },
        {
            id = "menu",
            label = L("menu.mainMenu"),
            w = 240,
            h = 46,
            onClick = function()
                Sound.play("uiConfirm")
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
    lg.setColor(0, 0, 0, 0.5)
    lg.rectangle("fill", 0, 0, sw, sh)

    -- Title
    Fonts.set("menu")
    lg.setColor(colorBad)
    lg.printf(L("game.gameOver"), 0, screenHalf - 96, sw, "center")

	-- Difficulty
	local difficultyLabel = getDifficultyLabel()
	
	if difficultyLabel then
		lg.setColor(1, 1, 1, 0.6)
		lg.printf(string.format("%s: %s", L("settings.difficulty"), difficultyLabel), 0, screenHalf - 64, sw, "center")
	end

    -- Reason
    if State.gameOverReasonKey then
        lg.setColor(1, 1, 1, 0.7)
        lg.printf(L(State.gameOverReasonKey), 0, screenHalf - 32, sw, "center")
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
        State.mode = "menu"
    end
end

return Screen