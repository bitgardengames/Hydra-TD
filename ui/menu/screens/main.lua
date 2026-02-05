local Constants = require("core.constants")
local Theme = require("core.theme")
local Button = require("ui.button")
local Cursor = require("core.cursor")
local State = require("core.state")
local Title = require("ui.title")
local Sound = require("systems.sound")
local Fonts = require("core.fonts")

local Screen = {}

local getTime = love.timer.getTime
local floor = math.floor

local menuColor = Theme.menu

local buttons = nil

local verText = Constants.VERSION_STRING
local verAlpha = 0.65
local verPad = 12

local lancerIdle = {
	angle = -math.pi / 6,
	from = -math.pi / 6,
	to = -math.pi / 6 - math.rad(28),
	t = 0,
	hold = 0,
	dir = 1,
	startupHold = 5.0,
}

local ROTATE_TIME = 1.8
local HOLD_TIME = 5.0

function Screen.load()
	-- Reset cursor when entering menu
	Cursor.usingVirtual = false

	buttons = {
		{
			id = "play",
			label = "Play",
			w = 240,
			h = 46,
			onClick = function()
				State.mode = "campaign"
				Sound.play("uiConfirm")
			end
		},
		{
			id = "settings",
			label = "Settings",
			w = 240,
			h = 46,
			onClick = function()
				State.mode = "settings"
				Sound.play("uiConfirm")
			end
		},
		{
			id = "quit",
			label = "Quit",
			w = 240,
			h = 46,
			onClick = function()
				love.event.quit()
			end
		},
	}
end

function Screen.update(dt)
	local sw, sh = love.graphics.getDimensions()
	local t = getTime()
	local cx = floor(sw * 0.5)

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

		-- Smoothstep
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
			local SERVO_AMPLITUDE = math.rad(0.35)
			local SERVO_SPEED = 1.8
			local fade = math.min(1, lancerIdle.hold / 0.6)

			local servo = math.sin(t * SERVO_SPEED) * SERVO_AMPLITUDE * fade
			lancerIdle.angle = lancerIdle.angle + servo
		end
	end

	local startY = floor(sh * 0.58)
	local gap = 58

	for i, btn in ipairs(buttons) do
		btn.x = cx - btn.w * 0.5
		btn.y = startY + (i - 1) * gap

		Button.update(btn, Cursor.x, Cursor.y, dt)
	end
end

function Screen.draw()
	local sw, sh = love.graphics.getDimensions()
	local titleY = floor(sh * 0.34)

	-- Background
	love.graphics.setColor(menuColor)
	love.graphics.rectangle("fill", 0, 0, sw, sh)

	-- Title
	Title.draw({x = sw * 0.5, y = titleY, lancerScale = 4.0, angle = lancerIdle.angle, alpha = 1})

	Fonts.set("menu")

	-- Buttons
	for _, btn in ipairs(buttons) do
		Button.draw(btn)
	end
	
	-- Version tag
	Fonts.set("ui")

	love.graphics.setColor(Theme.ui.text[1], Theme.ui.text[2], Theme.ui.text[3], verAlpha)

	local font = love.graphics.getFont()
	local tw = font:getWidth(verText)
	local th = font:getHeight()

	love.graphics.print(verText, sw - tw - verPad - 5, sh - th - verPad)
end

function Screen.mousepressed(x, y, button)
	for _, btn in ipairs(buttons) do
		if Button.mousepressed(btn, x, y, button) then
			return true
		end
	end
end

function Screen.keypressed(key)
	if key == "escape" then
		love.event.quit()
	end
end

return Screen