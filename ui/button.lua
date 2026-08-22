local Theme = require("core.theme")
local Text = require("ui.text")

local Button = {}

local lg = love.graphics

local min = math.min
local max = math.max

local colorBase = Theme.ui.button
local colorHover = Theme.ui.buttonHover
local colorText = Theme.ui.text
local colorOutline = Theme.outline.color

local cdR, cdG, cdB = colorText[1] * 0.60, colorText[2] * 0.60, colorText[3] * 0.60

local outlineW = Theme.outline.width
local outerRadius = 6 + outlineW * 0.5
local innerRadius = 6 - outlineW * 0.25

local idleLift = 6 -- Fixed resting height

local function pointInRect(px, py, x, y, w, h)
	return px >= x and px <= x + w and py >= y and py <= y + h
end

local function contains(btn, x, y)
	return btn.x and btn.y and btn.w and btn.h
		and pointInRect(x, y, btn.x, btn.y, btn.w, btn.h)
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function lerpColor(c1, c2, t)
	return lerp(c1[1], c2[1], t), lerp(c1[2], c2[2], t), lerp(c1[3], c2[3], t), lerp(c1[4] or 1, c2[4] or 1, t)
end

local function ensureAnim(btn)
	if not btn.anim then
		btn.anim = Button.newAnimation()
	end

	return btn.anim
end

-- Shared animation state for buttons which need custom rendering (shop,
-- inspector, ability icons). Keeping the timing here prevents each UI from
-- growing its own subtly different hover/press state machine.
function Button.newAnimation(extra)
	local anim = extra or {}
	anim.hovered = false
	anim.active = false
	anim.t = 0
	anim.pressed = false
	anim.pressT = 0
	return anim
end

function Button.updateAnimation(anim, hovered, dt)
	-- Custom-rendered buttons can retain animation tables created before all of
	-- the shared fields were initialized. Normalize them here so those callers
	-- can safely adopt the shared state machine without crashing mid-draw.
	if anim.hovered == nil then anim.hovered = false end
	if anim.active == nil then anim.active = false end
	if anim.t == nil then anim.t = 0 end
	if anim.pressed == nil then anim.pressed = false end
	if anim.pressT == nil then anim.pressT = 0 end

	if hovered ~= anim.hovered then
		anim.active = true
	end

	anim.hovered = hovered
	anim.pressT = anim.pressed and min(1, anim.pressT + dt * 20) or max(0, anim.pressT - dt * 20)

	if anim.active then
		local direction = hovered and 1 or -1
		anim.t = min(1, max(0, anim.t + direction * dt * 10))
		anim.active = anim.t > 0 and anim.t < 1
	end

	return anim
end

function Button.getHoverColor(anim)
	local t = anim.t
	local ease = t * t * (3 - 2 * t)
	return lerpColor(colorBase, colorHover, ease)
end

function Button.update(btn, mx, my, dt)
	if btn.enabled == false then
		btn.pointerHovered = false
		btn.hovered = false
		btn.anim = nil

		return
	end

	local anim = ensureAnim(btn)
	local pointerHovered = pointInRect(mx, my, btn.x, btn.y, btn.w, btn.h)
	local hovered = pointerHovered

	Button.updateAnimation(anim, hovered, dt)
	btn.pointerHovered = pointerHovered
	btn.hovered = hovered
end

function Button.draw(btn)
	local x, y, w, h = btn.x, btn.y, btn.w, btn.h

	-- Screens can be drawn during a menu transition before their first update
	-- has had a chance to calculate the button layout.
	if not (x and y and w and h) then
		return
	end

	-- Optional one-shot presentation offsets let screens stage a button without
	-- interfering with the shared hover/press animation state.
	local drawAlpha = btn.drawAlpha or 1
	local drawOffsetY = btn.drawOffsetY or 0
	y = y + drawOffsetY

	local anim = btn.anim
	local t = anim and anim.t or 0

	local ease = t * t * (3 - 2 * t)

	local pressEase = anim and anim.pressT or 0

	-- When pressed, ease toward base (0 lift)
	local lift = idleLift * (1 - pressEase)

	local r, g, b, a = lerpColor(colorBase, colorHover, ease)

	-- Button base
	lg.setColor(colorOutline[1], colorOutline[2], colorOutline[3], (colorOutline[4] or 1) * drawAlpha)
	lg.rectangle("fill", x - outlineW, y - outlineW, w + outlineW * 2, h + outlineW * 2, outerRadius)

	lg.setColor(r * 0.4, g * 0.4, b * 0.4, a * drawAlpha)
	lg.rectangle("fill", x, y, w, h, innerRadius)

	-- Button face
	local fy = y - lift

	lg.setColor(colorOutline[1], colorOutline[2], colorOutline[3], (colorOutline[4] or 1) * drawAlpha)
	lg.rectangle("fill", x - outlineW, fy - outlineW, w + outlineW * 2, h + outlineW * 2, outerRadius)

	lg.setColor(r, g, b, a * drawAlpha)
	lg.rectangle("fill", x, fy, w, h, innerRadius)

	-- Label
	local ty = fy + (h - lg.getFont():getHeight()) * 0.5

	if btn.enabled == false then
		lg.setColor(cdR, cdG, cdB, drawAlpha)
	else
		local textColor = btn.textColor or colorText
		lg.setColor(textColor[1], textColor[2], textColor[3], (textColor[4] or 1) * drawAlpha)
	end

	Text.printfShadow(btn.label, x, ty, w, "center")
end

-- Most screens treat buttons as a single group. Keep the iteration and event
-- short-circuiting here so every screen does not grow its own button router.
function Button.updateList(buttons, dt, mx, my)
	mx, my = mx or love.mouse.getX(), my or love.mouse.getY()

	for _, btn in ipairs(buttons or {}) do
		Button.update(btn, mx, my, dt)
	end
end

function Button.drawList(buttons)
	for _, btn in ipairs(buttons or {}) do
		Button.draw(btn)
	end
end

function Button.mousepressed(btn, x, y, button)
	if button ~= 1 or btn.enabled == false then
		return
	end

	if not btn.x or not btn.y then
		return
	end

	if pointInRect(x, y, btn.x, btn.y, btn.w, btn.h) then
		local anim = ensureAnim(btn)
		anim.pressed = true

		return true
	end
end

function Button.mousereleased(btn, x, y, button)
	if button ~= 1 then
		return
	end

	local anim = btn.anim

	if not anim then
		return
	end

	local wasPressed = anim.pressed
	anim.pressed = false

	if wasPressed and btn.onClick then
		if pointInRect(x, y, btn.x, btn.y, btn.w, btn.h) then
			btn.onClick()

			return true
		end
	end
end

function Button.mousepressedList(buttons, x, y, button)
	for _, btn in ipairs(buttons or {}) do
		if Button.mousepressed(btn, x, y, button) then
			return true
		end
	end

	return false
end

function Button.mousereleasedList(buttons, x, y, button)
	for _, btn in ipairs(buttons or {}) do
		if Button.mousereleased(btn, x, y, button) then
			return true
		end
	end

	return false
end

-- Custom-rendered gameplay panels keep their buttons in short lists. Handle
-- their shared press/release state here rather than duplicating hit testing in
-- every input router. Unlike mousepressed(), disabled buttons are deliberately
-- accepted so callers can show their own locked/cooldown feedback on release.
function Button.pressInList(buttons, x, y)
	for _, btn in ipairs(buttons or {}) do
		if contains(btn, x, y) then
			if btn.anim then
				btn.anim.pressed = true
			end

			return btn
		end
	end
end

function Button.releaseInList(buttons, x, y, onRelease)
	for _, btn in ipairs(buttons or {}) do
		if btn.anim then
			local wasPressed = btn.anim.pressed
			btn.anim.pressed = false

			if wasPressed and contains(btn, x, y) then
				if onRelease then
					onRelease(btn, x, y)
				end

				return btn
			end
		end
	end
end

return Button
