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

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function lerpColor(c1, c2, t)
	return lerp(c1[1], c2[1], t), lerp(c1[2], c2[2], t), lerp(c1[3], c2[3], t), lerp(c1[4] or 1, c2[4] or 1, t)
end

local function ensureAnim(btn)
	if not btn.anim then
		btn.anim = {hovered = false, active = false, t = 0, pressed = false, pressT = 0}
	end

	return btn.anim
end

function Button.update(btn, mx, my, dt)
	if btn.enabled == false then
		btn.hovered = false
		btn.anim = nil

		return
	end

	local anim = ensureAnim(btn)
	local hovered = pointInRect(mx, my, btn.x, btn.y, btn.w, btn.h)

	if hovered ~= anim.hovered then
		anim.active = true
	end

	anim.hovered = hovered
	btn.hovered = hovered

	-- Press animation
	if anim.pressed then
		anim.pressT = min(1, anim.pressT + dt * 20)
	else
		anim.pressT = max(0, anim.pressT - dt * 20)
	end

	if anim.active then
		local speed = dt * 10

		if anim.hovered then
			anim.t = min(1, anim.t + speed)
		else
			anim.t = max(0, anim.t - speed)
		end

		if anim.t == 0 or anim.t == 1 then
			anim.active = false
		end
	end
end

function Button.draw(btn)
	local x, y, w, h = btn.x, btn.y, btn.w, btn.h
	local anim = btn.anim
	local t = anim and anim.t or 0

	local ease = t * t * (3 - 2 * t)

	local pressEase = anim and anim.pressT or 0

	-- When pressed, ease toward base (0 lift)
	local lift = idleLift * (1 - pressEase)

	local r, g, b, a = lerpColor(colorBase, colorHover, ease)

	-- Button base
	lg.setColor(colorOutline)
	lg.rectangle("fill", x - outlineW, y - outlineW, w + outlineW * 2, h + outlineW * 2, outerRadius)

	lg.setColor(r * 0.4, g * 0.4, b * 0.4, a)
	lg.rectangle("fill", x, y, w, h, innerRadius)

	-- Button face
	local fy = y - lift

	lg.setColor(colorOutline)
	lg.rectangle("fill", x - outlineW, fy - outlineW, w + outlineW * 2, h + outlineW * 2, outerRadius)

	lg.setColor(r, g, b, a)
	lg.rectangle("fill", x, fy, w, h, innerRadius)

	-- Label
	local ty = fy + (h - lg.getFont():getHeight()) * 0.5

	if btn.enabled == false then
		lg.setColor(cdR, cdG, cdB)
	else
		lg.setColor(colorText)
	end

	Text.printfShadow(btn.label, x, ty, w, "center")
end

function Button.mousepressed(btn, x, y, button)
	if button ~= 1 or btn.enabled == false then
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

return Button