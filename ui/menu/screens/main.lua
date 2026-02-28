local Constants = require("core.constants")
local Theme = require("core.theme")
local Button = require("ui.button")
local Cursor = require("core.cursor")
local State = require("core.state")
local Title = require("ui.title")
local Sound = require("systems.sound")
local Fonts = require("core.fonts")
local Backdrop = require("scenes.backdrop")

local Screen = {}

local getTime = love.timer.getTime

local sin = math.sin
local min = math.min
local rad = math.rad
local floor = math.floor

local colorText = Theme.ui.text
local colorBackdrop = Theme.ui.backdrop

local buttons = nil

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
local gap = 58

local panelPaddingX = 24
local panelPaddingY = 24
local panelCorner = 18

function Screen.load()
	-- Reset cursor when entering menu
	Cursor.usingVirtual = false

	Backdrop.start()

	buttons = {
		{
			id = "play",
			label = "Play",
			w = btnW,
			h = btnH,
			onClick = function()
				State.mode = "campaign"
				Sound.play("uiConfirm")
			end
		},

		{
			id = "settings",
			label = "Settings",
			w = btnW,
			h = btnH,
			onClick = function()
				State.mode = "settings"
				Sound.play("uiConfirm")
			end
		},

		{
			id = "quit",
			label = "Quit",
			w = btnW,
			h = btnH,
			onClick = function()
				love.event.quit()
			end
		},
	}
end

function Screen.update(dt)
	Backdrop.update(dt)

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
			local SERVO_AMPLITUDE = rad(0.35)
			local SERVO_SPEED = 1.8
			local fade = min(1, lancerIdle.hold / 0.6)

			local servo = sin(t * SERVO_SPEED) * SERVO_AMPLITUDE * fade
			lancerIdle.angle = lancerIdle.angle + servo
		end
	end

	local startY = floor(sh * 0.52)

	for i, btn in ipairs(buttons) do
		btn.x = cx - btn.w * 0.5
		btn.y = startY + (i - 1) * gap

		Button.update(btn, Cursor.x, Cursor.y, dt)
	end
end

function Screen.draw()
	local sw, sh = love.graphics.getDimensions()
	local cx = floor(sw * 0.5)
	local titleY = floor(sh * 0.41)

	-- Background scene
	Backdrop.draw()

	-- Title
	Title.draw({x = sw * 0.5, y = titleY, lancerScale = 3.0, angle = lancerIdle.angle, alpha = 1})

	-- Calculate button block size
	local totalHeight = (#buttons - 1) * gap + btnH

	local panelW = btnW + panelPaddingX * 2
	local panelH = totalHeight + panelPaddingY * 2

	local panelX = cx - panelW * 0.5
	local panelY = buttons[1].y - panelPaddingY

	-- Draw button backdrop panel
	love.graphics.setColor(colorBackdrop)
	love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, panelCorner, panelCorner)

	Fonts.set("menu")

	-- Draw buttons
	for _, btn in ipairs(buttons) do
		Button.draw(btn)
	end
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