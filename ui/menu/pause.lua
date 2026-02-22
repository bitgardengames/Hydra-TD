local Button = require("ui.button")
local Cursor = require("core.cursor")
local State = require("core.state")
local Sound = require("systems.sound")
local Hotkeys = require("core.hotkeys")
local Backdrop = require("scenes.backdrop")
local Steam = require("core.steam")
local L = require("core.localization")

local Page = {}
local buttons = nil

local floor = math.floor

function Page.load()
	buttons = {
		{
			id = "resume",
			label = L("menu.resume"),
			w = 220,
			h = 42,
			onClick = function()
				State.paused = false
				State.mode = "game"
				Sound.play("uiConfirm")
			end
		},
		{
			id = "restart",
			label = L("menu.restart"),
			w = 220,
			h = 42,
			onClick = function()
				State.paused = false
				State.mode = "game"
				resetGame()
				Sound.play("uiConfirm")
			end
		},
		{
			id = "menu",
			label = L("menu.mainMenu"),
			w = 220,
			h = 42,
			onClick = function()
				State.paused = false
				Backdrop.start()
				State.mode = "menu"
				Steam.setRichPresence(L("presence.menu"))
				Sound.play("uiConfirm")
			end
		},
	}
end

function Page.update(dt)
	local sw, sh = love.graphics.getDimensions()
	local cx = floor(sw * 0.5)
	local startY = floor(sh * 0.5 - 20)
	local gap = 52

	for i, btn in ipairs(buttons) do
		btn.x = cx - btn.w * 0.5
		btn.y = startY + (i - 1) * gap

		Button.update(btn, Cursor.x, Cursor.y, dt)
	end
end

function Page.draw()
	for _, btn in ipairs(buttons) do
		Button.draw(btn)
	end
end

function Page.mousepressed(x, y, button)
	for _, btn in ipairs(buttons) do
		if Button.mousepressed(btn, x, y, button) then
			return true
		end
	end

	return false
end

function Page.keypressed(key)
	if key == Hotkeys.kb.actions.escape then
		State.mode = "game"
	end
end

return Page