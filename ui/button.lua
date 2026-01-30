local Theme = require("core.theme")
local Text = require("ui.text")

local Button = {}

local lg = love.graphics

local colorBase = Theme.ui.button
local colorHover = Theme.ui.buttonHover
local colorText = Theme.ui.text

local RADIUS = 8

local function pointInRect(px, py, x, y, w, h)
	return px >= x and px <= x + w and py >= y and py <= y + h
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function lerpColor(c1, c2, t)
	return {lerp(c1[1], c2[1], t), lerp(c1[2], c2[2], t), lerp(c1[3], c2[3], t), lerp(c1[4] or 1, c2[4] or 1, t)}
end

local function ensureAnim(btn)
	if not btn.anim then
		btn.anim = {
			hovered = false,
			active = false,
			t = 0,
		}
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

	if anim.active then
		local speed = dt * 10

		if anim.hovered then
			anim.t = math.min(1, anim.t + speed)
		else
			anim.t = math.max(0, anim.t - speed)
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

	-- Smoothstep
	local ease = t * t * (3 - 2 * t)

	-- Size + color
	local bumpPad = ease * 2
	local bg = lerpColor(colorBase, colorHover, ease)

	-- Background
	lg.setColor(bg)
	lg.rectangle("fill", x - bumpPad, y - bumpPad, w + bumpPad * 2, h + bumpPad * 2, RADIUS + bumpPad, RADIUS + bumpPad)

	-- Label
	local ty = y + (h - lg.getFont():getHeight()) * 0.5

	lg.setColor(colorText)
	Text.printfShadow(btn.label, x, ty, w, "center")
end

function Button.mousepressed(btn, x, y, button)
	if button ~= 1 then
		return
	end

	if btn.hovered and btn.onClick then
		btn.onClick()

		return true
	end
end

return Button