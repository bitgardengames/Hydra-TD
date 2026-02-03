-- ui/menu/screens/victory.lua
local Theme = require("core.theme")
local Button = require("ui.button")
local Cursor = require("core.cursor")
local State = require("core.state")
local Sound = require("systems.sound")
local Fonts = require("core.fonts")
local L = require("core.localization")

local lg = love.graphics
local Screen = {}

local buttons = nil
local colorGood = Theme.ui.good

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
                State.mapIndex = State.mapIndex + 1
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

    -- Dim background
    lg.setColor(0, 0, 0, 0.5)
    lg.rectangle("fill", 0, 0, sw, sh)

    -- Title
    Fonts.set("menu")
    lg.setColor(colorGood)
    lg.printf(L("game.victory"), 0, sh * 0.5 - 70, sw, "center")

    -- Optional subtitle / flavor text
    if State.victoryReasonKey then
        lg.setColor(1, 1, 1, 0.7)
        lg.printf(L(State.victoryReasonKey), 0, sh * 0.5 - 36, sw, "center")
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