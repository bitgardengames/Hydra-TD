local Constants = require("core.constants")
local Theme = require("core.theme")
local Button = require("ui.button")
local State = require("core.state")
local Title = require("ui.title")
local Sound = require("systems.sound")
local Steam = require("core.steam")
local Fonts = require("core.fonts")
local Backdrop = require("scenes.backdrop")
local L = require("core.localization")

local Screen = {}

local getTime = love.timer.getTime

local sin = math.sin
local min = math.min
local rad = math.rad
local floor = math.floor

local colorBackdrop = Theme.ui.backdrop
local colorOutline = Theme.outline.color

local outlineW = Theme.outline.width
local baseRadius = 6 * 3
local outerRadius = baseRadius + outlineW * 0.5
local innerRadius = baseRadius - outlineW * 0.25

local buttons = nil
local storeButton = nil

local lancerIdle = {
	angle = -math.pi / 6,
	from = -math.pi / 6,
	to = -math.pi / 6 - rad(28),
	t = 0,
	hold = 0,
	dir = 1,
	startupHold = 5.0,
}

local ROTATE_TIME = 1.8
local HOLD_TIME = 5.0

local btnW = 240
local btnH = 42
local gap = 62

local panelPaddingX = 24
local panelPaddingY = 24

function Screen.load()

	Backdrop.start()

	buttons = {
		{
			id = "play",
			label = L("menu.play"),
			w = btnW,
			h = btnH,
			onClick = function()
				State.mode = "campaign"
				Sound.play("uiConfirm")
			end
		},

		{
			id = "settings",
			label = L("menu.settings"),
			w = btnW,
			h = btnH,
			onClick = function()
				State.mode = "settings"
				Sound.play("uiConfirm")
			end
		},

		{
			id = "quit",
			label = L("menu.quit"),
			w = btnW,
			h = btnH,
			onClick = function()
				love.event.quit()
			end
		},
	}

	if Constants.IS_DEMO then
		storeButton = {
			id = "store",
			label = L("overlay.wishlistSteam"),
			w = 200,
			h = 36,
			onClick = function()
				Steam.openStorePage(4095520)
				Sound.play("uiConfirm")
			end
		}
	end
end

function Screen.update(dt)
	Backdrop.update(dt)

	local sw, sh = love.graphics.getDimensions()
	local t = getTime()
	local cx = floor(sw * 0.5)
	local startY = floor(sh * 0.52)

	for i, btn in ipairs(buttons) do
		btn.x = cx - btn.w * 0.5
		btn.y = startY + (i - 1) * gap
	end

	-- Startup hero pose
	if lancerIdle.startupHold > 0 then
		lancerIdle.startupHold = lancerIdle.startupHold - dt
		lancerIdle.angle = lancerIdle.from
	else
		-- Swivel timing
		if lancerIdle.hold > 0 then
			lancerIdle.hold = lancerIdle.hold - dt
		else
			lancerIdle.t = lancerIdle.t + dt / ROTATE_TIME

			if lancerIdle.t >= 1 then
				lancerIdle.t = 0
				lancerIdle.hold = HOLD_TIME
				lancerIdle.dir = -lancerIdle.dir
			end
		end

		local p = lancerIdle.t
		p = p * p * (3 - 2 * p)

		local a, b

		if lancerIdle.dir == 1 then
			a, b = lancerIdle.from, lancerIdle.to
		else
			a, b = lancerIdle.to, lancerIdle.from
		end

		lancerIdle.angle = a + (b - a) * p

		-- Servo while holding
		if lancerIdle.hold > 0 then
			local SERVO_AMPLITUDE = rad(0.35)
			local SERVO_SPEED = 1.8
			local fade = min(1, lancerIdle.hold / 0.6)

			local servo = sin(t * SERVO_SPEED) * SERVO_AMPLITUDE * fade
			lancerIdle.angle = lancerIdle.angle + servo
		end
	end

	for _, btn in ipairs(buttons) do
		local mx, my = love.mouse.getPosition()
		Button.update(btn, mx, my, dt)
	end

	if storeButton then
		storeButton.x = 24
		storeButton.y = sh - storeButton.h - 24

		local mx, my = love.mouse.getPosition()
		Button.update(storeButton, mx, my, dt)
	end
end

local idleLift = 6

function Screen.draw()
	local sw, sh = love.graphics.getDimensions()
	local cx = floor(sw * 0.5)
	local titleY = floor(sh * 0.41)

	-- Background scene
	Backdrop.draw()

	-- Title
	Title.draw(sw * 0.5, titleY, 1, 3.0, lancerIdle.angle, 1, 26)

	-- Calculate button block size
	local totalHeight = (#buttons - 1) * gap + btnH + idleLift

	local panelW = btnW + panelPaddingX * 2
	local panelH = totalHeight + panelPaddingY * 2

	local panelX = cx - panelW * 0.5
	local panelY = buttons[1].y - panelPaddingY - idleLift

	-- Panel
	love.graphics.setColor(colorOutline)
	love.graphics.rectangle("fill", panelX - outlineW, panelY - outlineW, panelW + outlineW * 2, panelH + outlineW * 2, outerRadius)

	love.graphics.setColor(colorBackdrop)
	love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, innerRadius)

	Fonts.set("menu")

	-- Draw buttons
	for _, btn in ipairs(buttons) do
		Button.draw(btn)
	end

	if storeButton then
		Button.draw(storeButton)
	end
end

function Screen.mousepressed(x, y, button)
	for _, btn in ipairs(buttons) do
		if Button.mousepressed(btn, x, y, button) then
			return true
		end
	end

	if storeButton and Button.mousepressed(storeButton, x, y, button) then
		return true
	end
end

function Screen.mousereleased(x, y, button)
	for _, btn in ipairs(buttons) do
		if Button.mousereleased(btn, x, y, button) then
			return true
		end
	end

	if storeButton and Button.mousereleased(storeButton, x, y, button) then
		return true
	end
end

function Screen.keypressed(key)
	if key == "escape" then
		love.event.quit()
	end
end

return Screen