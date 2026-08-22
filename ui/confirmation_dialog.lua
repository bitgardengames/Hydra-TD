local Button = require("ui.button")
local Fonts = require("core.fonts")
local Theme = require("core.theme")
local Text = require("ui.text")
local Presentation = require("ui.confirmation_dialog_presentation")

local ConfirmationDialog = {}
ConfirmationDialog.__index = ConfirmationDialog

local lg = love.graphics
local outlineW = Theme.outline.width
local radius = 12

function ConfirmationDialog.new(options)
	options = options or {}
	return setmetatable({
		open = false,
		state = "closed",
		elapsed = 0,
		buttons = {},
		defaultReducedMotion = options.reducedMotion == true,
		reducedMotion = options.reducedMotion == true,
	}, ConfirmationDialog)
end

function ConfirmationDialog:isOpen()
	return self.open
end

function ConfirmationDialog:show(options)
	self.open = true
	self.state = "opening"
	self.closeReason = nil
	self.elapsed = 0
	self.reducedMotion = options.reducedMotion == nil and self.defaultReducedMotion or options.reducedMotion == true
	self.title = options.title
	self.description = options.description
	self.onConfirm = options.onConfirm

	self.buttons = {
		{ label = options.confirmLabel, w = 150, h = 42 },
		{ label = options.cancelLabel, w = 150, h = 42 },
	}
	self.buttons[1].onClick = function() self:confirm() end
	self.buttons[2].onClick = function() self:cancel() end
end

function ConfirmationDialog:confirm()
	if self.state ~= "open" and not (self.state == "opening" and self:pose().pointerReady) then return false end
	self.state = "closing"
	self.closeReason = "confirm"
	self.elapsed = 0
	return true
end

function ConfirmationDialog:cancel()
	if self.state ~= "open" and self.state ~= "opening" then return false end
	self.state = "closing"
	self.closeReason = "cancel"
	self.elapsed = 0
	return true
end

function ConfirmationDialog:pose()
	return Presentation.pose(self.state, self.elapsed, self.reducedMotion, self.closeReason)
end

function ConfirmationDialog:_finishClosing()
	local callback = self.closeReason == "confirm" and self.onConfirm or nil
	-- The dialog becomes fully closed and loses its callback before user code is
	-- invoked. A callback can therefore open another dialog, but cannot activate
	-- this confirmation twice through re-entrant or repeated input.
	self.open = false
	self.state = "closed"
	self.closeReason = nil
	self.elapsed = 0
	self.title, self.description, self.onConfirm = nil, nil, nil
	self.buttons = {}
	if callback then callback() end
end

function ConfirmationDialog:update(dt)
	if not self.open then return end
	self.elapsed = self.elapsed + dt
	local pose = self:pose()
	if self.state ~= "open" and pose.complete then
		if self.state == "opening" then
			self.state = "open"
			self.elapsed = 0
		else
			self:_finishClosing()
			return
		end
	end
	local sw, sh = lg.getDimensions()
	local gap = 18
	local totalW = self.buttons[1].w + self.buttons[2].w + gap
	local y = math.floor(sh * 0.5 + 58)

	for i, button in ipairs(self.buttons) do
		button.x = math.floor((sw - totalW) * 0.5 + (i - 1) * (button.w + gap))
		button.y = y
	end
	pose = self:pose()
	if pose.pointerReady then
		local mx, my = love.mouse.getPosition()
		local cx, cy = sw * 0.5, sh * 0.5
		mx = cx + (mx - cx) / pose.scale
		my = cy + (my - cy - pose.offsetY) / pose.scale
		Button.updateList(self.buttons, dt, mx, my)
	else
		for _, button in ipairs(self.buttons) do
			button.pointerHovered, button.hovered = false, false
		end
	end
end

function ConfirmationDialog:draw()
	if not self.open then return end
	local sw, sh = lg.getDimensions()
	local panelW, panelH = math.min(540, sw - 48), 230
	local x, y = (sw - panelW) * 0.5, (sh - panelH) * 0.5
	local pose = self:pose()

	lg.setColor(0, 0, 0, pose.dimmerAlpha)
	lg.rectangle("fill", 0, 0, sw, sh)
	lg.push()
	lg.translate(sw * 0.5, sh * 0.5 + pose.offsetY)
	lg.scale(pose.scale, pose.scale)
	lg.translate(-sw * 0.5, -sh * 0.5)
	local outline = Theme.outline.color
	lg.setColor(outline[1], outline[2], outline[3], (outline[4] or 1) * pose.panelAlpha)
	lg.rectangle("fill", x - outlineW, y - outlineW, panelW + outlineW * 2, panelH + outlineW * 2, radius)
	local backdrop = Theme.ui.backdrop
	lg.setColor(backdrop[1], backdrop[2], backdrop[3], (backdrop[4] or 1) * pose.panelAlpha)
	lg.rectangle("fill", x, y, panelW, panelH, radius)

	Fonts.set("title")
	local textColor = Theme.ui.text
	lg.setColor(textColor[1], textColor[2], textColor[3], (textColor[4] or 1) * pose.panelAlpha)
	Text.printfShadow(self.title, x + 24, y + 28, panelW - 48, "center")
	Fonts.set("ui")
	lg.setColor(textColor[1], textColor[2], textColor[3], (textColor[4] or 1) * pose.panelAlpha)
	Text.printfShadow(self.description, x + 36, y + 82, panelW - 72, "center")
	Fonts.set("menu")
	for _, button in ipairs(self.buttons) do button.drawAlpha = pose.panelAlpha end
	Button.drawList(self.buttons)
	lg.pop()
end

function ConfirmationDialog:keypressed(key)
	if not self.open then return false end
	if key == "escape" then
		self:cancel()
	end
	return true
end

function ConfirmationDialog:mousepressed(x, y, button)
	if not self.open then return false end
	local pose = self:pose()
	if not pose.pointerReady then return true end
	local sw, sh = lg.getDimensions()
	x = sw * 0.5 + (x - sw * 0.5) / pose.scale
	y = sh * 0.5 + (y - sh * 0.5 - pose.offsetY) / pose.scale
	Button.mousepressedList(self.buttons, x, y, button)
	return true
end

function ConfirmationDialog:mousereleased(x, y, button)
	if not self.open then return false end
	local pose = self:pose()
	if not pose.pointerReady then return true end
	local sw, sh = lg.getDimensions()
	x = sw * 0.5 + (x - sw * 0.5) / pose.scale
	y = sh * 0.5 + (y - sh * 0.5 - pose.offsetY) / pose.scale
	Button.mousereleasedList(self.buttons, x, y, button)
	return true
end

return ConfirmationDialog
