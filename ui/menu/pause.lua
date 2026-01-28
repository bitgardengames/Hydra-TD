local Button = require("ui.button")
local Cursor = require("core.cursor")
local State = require("core.state")
local Sound = require("systems.sound")

local Page = {}

local floor = math.floor

local pauseButtons = {
	{
		id = "resume",
		label = "Resume",
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
		label = "Restart",
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
		label = "Main Menu",
		w = 220,
		h = 42,
		onClick = function()
			State.paused = false
			State.mode = "menu"
			Sound.play("uiConfirm")
		end
	},
}

function Page.update(dt)
	local sw, sh = love.graphics.getDimensions()
	local cx = floor(sw * 0.5)
	local startY = floor(sh * 0.5 - 20)
	local gap = 52

	for i, btn in ipairs(pauseButtons) do
		btn.x = cx - btn.w * 0.5
		btn.y = startY + (i - 1) * gap

		Button.update(btn, Cursor.x, Cursor.y, dt)
	end
end

function Page.draw()
	for _, btn in ipairs(pauseButtons) do
		Button.draw(btn)
	end
end

function Page.mousepressed(x, y, button)
	for _, btn in ipairs(pauseButtons) do
		if Button.mousepressed(btn, x, y, button) then
			return true
		end
	end

	return false
end

return Page