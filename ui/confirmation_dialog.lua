local Button = require("ui.button")
local Fonts = require("core.fonts")
local Theme = require("core.theme")
local Text = require("ui.text")

local ConfirmationDialog = {}
ConfirmationDialog.__index = ConfirmationDialog

local lg = love.graphics
local outlineW = Theme.outline.width
local radius = 12

function ConfirmationDialog.new()
	return setmetatable({ open = false, buttonFocus = Button.newFocus(), buttons = {} }, ConfirmationDialog)
end

function ConfirmationDialog:isOpen()
	return self.open
end

function ConfirmationDialog:show(options)
	self.open = true
	self.title = options.title
	self.description = options.description
	self.onConfirm = options.onConfirm
	self.origin = options.origin

	if self.origin then
		self.origin.focused = false
	end

	self.buttons = {
		{ label = options.confirmLabel, w = 150, h = 42 },
		{ label = options.cancelLabel, w = 150, h = 42 },
	}
	self.buttons[1].onClick = function() self:confirm() end
	self.buttons[2].onClick = function() self:cancel() end
	Button.resetFocus(self.buttons, self.buttonFocus)
end

function ConfirmationDialog:confirm()
	if not self.open then return end
	local callback = self.onConfirm
	self.open = false
	self.onConfirm = nil
	self.origin = nil
	if callback then callback() end
end

function ConfirmationDialog:cancel()
	if not self.open then return end
	self.open = false
	self.onConfirm = nil
	if self.origin then
		self.origin.focused = true
	end
	self.origin = nil
end

function ConfirmationDialog:update(dt)
	if not self.open then return end
	local sw, sh = lg.getDimensions()
	local gap = 18
	local totalW = self.buttons[1].w + self.buttons[2].w + gap
	local y = math.floor(sh * 0.5 + 58)

	for i, button in ipairs(self.buttons) do
		button.x = math.floor((sw - totalW) * 0.5 + (i - 1) * (button.w + gap))
		button.y = y
	end
	Button.updateList(self.buttons, dt)
end

function ConfirmationDialog:draw()
	if not self.open then return end
	local sw, sh = lg.getDimensions()
	local panelW, panelH = math.min(540, sw - 48), 230
	local x, y = (sw - panelW) * 0.5, (sh - panelH) * 0.5

	lg.setColor(0, 0, 0, 0.72)
	lg.rectangle("fill", 0, 0, sw, sh)
	lg.setColor(Theme.outline.color)
	lg.rectangle("fill", x - outlineW, y - outlineW, panelW + outlineW * 2, panelH + outlineW * 2, radius)
	lg.setColor(Theme.ui.backdrop)
	lg.rectangle("fill", x, y, panelW, panelH, radius)

	Fonts.set("title")
	lg.setColor(Theme.ui.text)
	Text.printfShadow(self.title, x + 24, y + 28, panelW - 48, "center")
	Fonts.set("ui")
	Text.printfShadow(self.description, x + 36, y + 82, panelW - 72, "center")
	Fonts.set("menu")
	Button.drawList(self.buttons)
end

function ConfirmationDialog:keypressed(key)
	if not self.open then return false end
	if key == "escape" then
		self:cancel()
	else
		Button.keypressedList(self.buttons, self.buttonFocus, key)
	end
	return true
end

function ConfirmationDialog:mousepressed(x, y, button)
	if not self.open then return false end
	Button.mousepressedList(self.buttons, x, y, button, self.buttonFocus)
	return true
end

function ConfirmationDialog:mousereleased(x, y, button)
	if not self.open then return false end
	Button.mousereleasedList(self.buttons, x, y, button)
	return true
end

return ConfirmationDialog
