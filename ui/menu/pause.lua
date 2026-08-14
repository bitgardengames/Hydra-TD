local Button = require("ui.button")
local State = require("core.state")
local Achievements = require("systems.achievements")
local Sound = require("systems.sound")
local Hotkeys = require("core.hotkeys")
local Backdrop = require("scenes.backdrop")
local Steam = require("core.steam")
local Theme = require("core.theme")
local Fonts = require("core.fonts")
local L = require("core.localization")
local Difficulty = require("systems.difficulty")
local Save = require("core.save")
local ConfirmationDialog = require("ui.confirmation_dialog")


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
local buttonFocus = Button.newFocus()
local confirmation = ConfirmationDialog.new()

local function confirmAction(origin, titleKey, descriptionKey, action)
	confirmation:show({
		title = L(titleKey), description = L(descriptionKey),
		confirmLabel = L("confirmation.confirm"), cancelLabel = L("confirmation.cancel"),
		onConfirm = action, origin = origin,
	})
end

local btnW = 220
local btnH = 42
local gap = 62

local paddingX = 24
local paddingY = 24
local headerSpacing = 36
local headerHeight = 38

local contextCardW = 190
local contextCardH = 72
local contextCardMargin = 24
local contextCardPadding = 14

local function drawDifficultyCard(sw)
	local cardX = sw - contextCardW - contextCardMargin
	local cardY = contextCardMargin

	lg.setColor(colorOutline)
	lg.rectangle(
		"fill",
		cardX - outlineW,
		cardY - outlineW,
		contextCardW + outlineW * 2,
		contextCardH + outlineW * 2,
		outerRadius
	)

	lg.setColor(colorBackdrop)
	lg.rectangle("fill", cardX, cardY, contextCardW, contextCardH, innerRadius)

	Fonts.set("ui")
	lg.setColor(Theme.ui.text)
	lg.printf(
		L("settings.difficulty"),
		cardX + contextCardPadding,
		cardY + 9,
		contextCardW - contextCardPadding * 2,
		"left"
	)

	Fonts.set("menu")
	lg.setColor(Theme.ui.selected)
	lg.printf(
		L("difficulty." .. Difficulty.key()),
		cardX + contextCardPadding,
		cardY + 32,
		contextCardW - contextCardPadding * 2,
		"left"
	)
end

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
				Sound.exitPause()
				Sound.play("uiConfirm")
			end
		},

		{
			id = "restart",
			label = L("menu.restart"),
			w = btnW,
			h = btnH,
			onClick = function()
				confirmAction(buttons[2], "confirmation.restartTitle", "confirmation.restartDescription", function()
					State.paused = false
					Achievements.onGameOver()
					State.mode = "game"
					resetGame()
					Sound.exitPause()
					Sound.play("uiConfirm")
				end)
			end
		},

		{
			id = "settings",
			label = L("menu.settings"),
			w = btnW,
			h = btnH,
			onClick = function()
				State.mode = "settings_gameplay"
				Sound.play("uiConfirm")
			end
		},

		{
			id = "menu",
			label = L("menu.mainMenu"),
			w = btnW,
			h = btnH,
			onClick = function()
				confirmAction(buttons[4], "confirmation.mainMenuTitle", "confirmation.mainMenuDescription", function()
					State.paused = false
					Achievements.onGameOver()
					Save.flush()
					Backdrop.start()
					State.mode = "menu"
					Steam.setRichPresence(L("presence.menu"))
					Sound.exitPause()
					Sound.play("uiConfirm")
					Sound.playMusic("menu")
				end)
			end
		},
	}
	Button.resetFocus(buttons, buttonFocus)
end

function Page.enter()
	Button.resetFocus(buttons, buttonFocus)
end

function Page.update(dt)
	local sw, sh = love.graphics.getDimensions()
	local cx = floor(sw * 0.5)
	local startY = floor(sh * 0.5 - 20)

	for i, btn in ipairs(buttons) do
		btn.x = cx - btn.w * 0.5
		btn.y = startY + (i - 1) * gap
	end

	if confirmation:isOpen() then confirmation:update(dt) else Button.updateList(buttons, dt) end
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

	-- Keep the current run context visible without crowding the pause actions.
	drawDifficultyCard(sw)

	-- Draw header
	lg.setColor(1, 1, 1, 1)
	lg.printf(L("menu.paused"), 0, boxY + paddingY, sw, "center")

	Fonts.set("menu")

	-- Draw buttons
	Button.drawList(buttons)
	confirmation:draw()
end

function Page.mousepressed(x, y, button)
	if confirmation:isOpen() then return confirmation:mousepressed(x, y, button) end
	return Button.mousepressedList(buttons, x, y, button, buttonFocus)
end

function Page.mousereleased(x, y, button)
	if confirmation:isOpen() then return confirmation:mousereleased(x, y, button) end
	return Button.mousereleasedList(buttons, x, y, button)
end

function Page.keypressed(key)
	if confirmation:isOpen() then return confirmation:keypressed(key) end
	if key == Hotkeys.getActionKey("escape") then
		State.mode = "game"
		Sound.exitPause()
	else
		return Button.keypressedList(buttons, buttonFocus, key)
	end
end

return Page
