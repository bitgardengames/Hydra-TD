local Button = require("ui.button")
local Cursor = require("core.cursor")
local State = require("core.state")
local Achievements = require("systems.achievements")
local Sound = require("systems.sound")
local Hotkeys = require("core.hotkeys")
local Backdrop = require("scenes.backdrop")
local Steam = require("core.steam")
local Theme = require("core.theme")
local Fonts = require("core.fonts")
local L = require("core.localization")


local floor = math.floor
local lg = love.graphics

local colorBackdrop = Theme.ui.backdrop
local colorOutline = Theme.outline.color

local outlineW = Theme.outline.width
local baseRadius = 6 * 3
local outerRadius = baseRadius + outlineW * 0.5
local innerRadius = baseRadius - outlineW * 0.25

local Page = {}
local buttons = nil

local btnW = 220
local btnH = 42
local gap = 62
local corner = 18

local paddingX = 24
local paddingY = 24
local headerSpacing = 36
local headerHeight = 38

function Page.load()
	buttons = {
		{
			id = "resume",
			label = L("menu.resume"),
			w = btnW,
			h = btnH,
			onClick = function()
				State.paused = false
				State.mode = "game"
				Sound.play("uiConfirm")
			end
		},

		{
			id = "restart",
			label = L("menu.restart"),
			w = btnW,
			h = btnH,
			onClick = function()
				State.paused = false
				Achievements.onGameOver()
				State.mode = "game"
				resetGame()
				Sound.play("uiConfirm")
			end
		},

		{
			id = "menu",
			label = L("menu.mainMenu"),
			w = btnW,
			h = btnH,
			onClick = function()
				State.paused = false
				Achievements.onGameOver()
				Backdrop.start()
				State.mode = "menu"
				Steam.setRichPresence(L("presence.menu"))
				Sound.exitPause()
				Sound.play("uiConfirm")
			end
		},
	}
end

function Page.update(dt)
	local sw, sh = love.graphics.getDimensions()
	local cx = floor(sw * 0.5)
	local startY = floor(sh * 0.5 - 20)

	for i, btn in ipairs(buttons) do
		btn.x = cx - btn.w * 0.5
		btn.y = startY + (i - 1) * gap

		Button.update(btn, Cursor.x, Cursor.y, dt)
	end
end

function Page.draw()
	local sw, sh = lg.getDimensions()

	local cx = floor(sw * 0.5)
	local startY = floor(sh * 0.5 - 20)
	local count = #buttons

	-- Header
	Fonts.set("title")

	-- Button block height
	local buttonsHeight = (count - 1) * gap + btnH

	-- Total content height (header + spacing + buttons)
	local contentHeight = headerHeight + headerSpacing + buttonsHeight

	local boxW = btnW + paddingX * 2
	local boxH = contentHeight + paddingY * 2

	local boxX = cx - boxW * 0.5
	local boxY = startY - paddingY - headerHeight - headerSpacing

	-- Panel
	lg.setColor(colorOutline)
	lg.rectangle("fill", boxX - outlineW, boxY - outlineW, boxW + outlineW * 2, boxH + outlineW * 2, outerRadius)

	lg.setColor(colorBackdrop)
	lg.rectangle("fill", boxX, boxY, boxW, boxH, innerRadius)

	-- Draw header
	lg.setColor(1, 1, 1, 1)
	lg.printf(L("menu.paused"), 0, boxY + paddingY, sw, "center")

	Fonts.set("menu")

	-- Draw buttons
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

function Page.mousereleased(x, y, button)
	for _, btn in ipairs(buttons) do
		if Button.mousereleased(btn, x, y, button) then
			return true
		end
	end
end

function Page.keypressed(key)
	if key == Hotkeys.kb.actions.escape then
		State.mode = "game"
		Sound.exitPause()
	end
end

return Page