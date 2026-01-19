local Theme = require("core.theme")
local Text = require("ui.text")

local Button = {}

local lg = love.graphics

local colorBase = Theme.ui.panel2
local colorHover = Theme.ui.hovered
local colorText = Theme.ui.text

local RADIUS = 8

local function pointInRect(px, py, x, y, w, h)
	return px >= x and px <= x + w and py >= y and py <= y + h
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function lerpColor(c1, c2, t)
	return {
		lerp(c1[1], c2[1], t),
		lerp(c1[2], c2[2], t),
		lerp(c1[3], c2[3], t),
		lerp(c1[4] or 1, c2[4] or 1, t),
	}
end

local function elasticOut(t)
	return math.sin(-13 * math.pi * 0.5 * (t + 1)) * math.pow(2, -10 * t) + 1
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

	-- Detect hover enter / leave
	if hovered ~= anim.hovered then
		anim.t = 0
		anim.active = true
	end

	anim.hovered = hovered
	btn.hovered = hovered

	-- Advance hover animation
	if anim.active then
		anim.t = anim.t + dt * 10  -- slightly snappier for elastic

		if anim.t >= 1 then
			anim.t = 1
			anim.active = false
		end
	end
end

function Button.draw(btn)
	local x, y, w, h = btn.x, btn.y, btn.w, btn.h
	local anim = btn.anim
	local bumpPad = 0
	local bg = colorBase
	local fade = 0

	if anim then
		local p = anim.t
		local dir = anim.hovered and 1 or -1

		local ease
		if anim.hovered then
			ease = elasticOut(p)       -- pop on enter
		else
			ease = p * p * (3 - 2 * p)  -- clean settle on leave
		end

		fade = anim.hovered and ease or (1 - ease)
		bumpPad = ease * dir * 2.5     -- 🔴 IMPORTANT: larger amplitude
	end

	-- Fade background color
	bg = lerpColor(colorBase, colorHover, fade)

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