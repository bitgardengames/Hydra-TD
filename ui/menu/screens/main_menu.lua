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
local Save = require("core.save")
local Difficulty = require("systems.difficulty")
local ConfirmationDialog = require("ui.confirmation_dialog")

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
local focusButtons = nil
local buttonFocus = Button.newFocus()
local storeButton = nil
local confirmation = ConfirmationDialog.new()

local function confirmQuit(origin)
	confirmation:show({
		title = L("confirmation.quitTitle"),
		description = L("confirmation.quitDescription"),
		confirmLabel = L("confirmation.confirm"),
		cancelLabel = L("confirmation.cancel"),
		onConfirm = function() love.event.quit() end,
		origin = origin,
	})
end

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
				State.ignoreStats = false
				Difficulty.set(Save.data.settings.difficulty)
				require("ui.menu.menu").set("campaign")
				Sound.play("uiConfirm")
			end
		},

		{
			id = "settings",
			label = L("menu.settings"),
			w = btnW,
			h = btnH,
			onClick = function()
				require("ui.menu.menu").set("settings")
				Sound.play("uiConfirm")
			end
		},

		{
			id = "quit",
			label = L("menu.quit"),
			w = btnW,
			h = btnH,
			onClick = function()
				confirmQuit(buttons[3])
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

	focusButtons = {unpack(buttons)}
	if storeButton then focusButtons[#focusButtons + 1] = storeButton end
	Button.resetFocus(focusButtons, buttonFocus)
end

function Screen.enter()
	Button.resetFocus(focusButtons, buttonFocus)
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

	if confirmation:isOpen() then confirmation:update(dt) else Button.updateList(buttons, dt) end

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
	Button.drawList(buttons)

	if storeButton then
		Button.draw(storeButton)
	end

	confirmation:draw()
end

function Screen.mousepressed(x, y, button)
	if confirmation:isOpen() then return confirmation:mousepressed(x, y, button) end
	if Button.mousepressedList(buttons, x, y, button, buttonFocus) then
		return true
	end

	if storeButton and Button.mousepressed(storeButton, x, y, button) then
		Button.focusButton(focusButtons, buttonFocus, storeButton)
		return true
	end
end

function Screen.mousereleased(x, y, button)
	if confirmation:isOpen() then return confirmation:mousereleased(x, y, button) end
	if Button.mousereleasedList(buttons, x, y, button) then
		return true
	end

	if storeButton and Button.mousereleased(storeButton, x, y, button) then
		return true
	end
end

function Screen.keypressed(key)
	if confirmation:isOpen() then return confirmation:keypressed(key) end
	if key == "escape" then
		Button.focusButton(focusButtons, buttonFocus, buttons[3])
		confirmQuit(buttons[3])
	else
		return Button.keypressedList(focusButtons, buttonFocus, key)
	end
end

return Screen
