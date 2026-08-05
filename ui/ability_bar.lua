local State = require("core.state")
local Theme = require("core.theme")
local AbilityDefs = require("systems.ability_defs")
local Text = require("ui.text")

local lg = love.graphics
local floor = math.floor
local min = math.min
local max = math.max

local AbilityBar = {}
local buttons = {}

local SIZE = 58
local GAP = 10
local RIGHT = 18
local MAX_ABILITIES = 4
local IDLE_LIFT = 5

local colorButton = Theme.ui.button
local colorButtonHover = Theme.ui.buttonHover
local colorOutline = Theme.outline.color
local outlineW = Theme.outline.width

local cb1, cb2, cb3 = colorButton[1], colorButton[2], colorButton[3]
local ch1, ch2, ch3 = colorButtonHover[1], colorButtonHover[2], colorButtonHover[3]

local cbd1 = ch1 - cb1
local cbd2 = ch2 - cb2
local cbd3 = ch3 - cb3

local outerRadius = 9 + outlineW * 0.5
local innerRadius = 9 - outlineW * 0.25

local function ensureAnim(button)
	local anim = button.anim

	if not anim then
		anim = {}
		button.anim = anim
	end

	anim.hovered = anim.hovered or false
	anim.active = anim.active or false
	anim.t = anim.t or 0
	anim.pressed = anim.pressed or false
	anim.pressT = anim.pressT or 0
	anim.errorT = anim.errorT or 0

	return anim
end

local function drawMeteor(cx, cy, scale)
	lg.setLineWidth(5 * scale)
	lg.setColor(1, 0.48, 0.18, 0.9)
	lg.line(cx - 15 * scale, cy - 15 * scale, cx - 5 * scale, cy - 5 * scale)
	lg.setColor(1, 0.76, 0.28, 1)
	lg.circle("fill", cx + 3 * scale, cy + 3 * scale, 12 * scale)
	lg.setColor(1, 0.92, 0.55, 1)
	lg.circle("fill", cx, cy, 5 * scale)
end

local function drawFrost(cx, cy, scale)
	lg.setColor(0.55, 0.88, 1, 1)
	lg.setLineWidth(3 * scale)
	for i = 0, 2 do
		local angle = i * math.pi / 3
		local dx, dy = math.cos(angle) * 17 * scale, math.sin(angle) * 17 * scale
		lg.line(cx - dx, cy - dy, cx + dx, cy + dy)
	end
	lg.circle("fill", cx, cy, 4 * scale)
end

local iconDrawers = {meteor = drawMeteor, frost_nova = drawFrost}

function AbilityBar.draw(dt, mx, my)
	local equipped = State.equippedAbilities or {}
	local count = min(#equipped, MAX_ABILITIES)
	local sw, sh = lg.getDimensions()
	local totalH = count * SIZE + math.max(0, count - 1) * GAP
	local startY = floor((sh - totalH) * 0.5)

	for i = 1, count do
		local abilityId = equipped[i]
		local def = AbilityDefs[abilityId]
		if def then
			local x, y = sw - RIGHT - SIZE, startY + (i - 1) * (SIZE + GAP)
			local cooldown = State.abilityCooldowns[abilityId] or 0
			local ready = cooldown <= 0
			local hovered = mx >= x and mx <= x + SIZE and my >= y and my <= y + SIZE
			local button = buttons[i] or {anim = {}}
			buttons[i] = button
			button.x, button.y, button.w, button.h = x, y, SIZE, SIZE
			button.abilityId, button.enabled = abilityId, ready
			local anim = ensureAnim(button)

			if hovered ~= anim.hovered then
				anim.active = true
			end

			anim.hovered = hovered

			if anim.pressed then
				anim.pressT = min(1, anim.pressT + dt * 20)
			else
				anim.pressT = max(0, anim.pressT - dt * 20)
			end

			anim.errorT = max(0, anim.errorT - dt * 4)

			if anim.active then
				local speed = dt * 10

				anim.t = hovered and min(1, anim.t + speed) or max(0, anim.t - speed)

				if anim.t == 0 or anim.t == 1 then
					anim.active = false
				end
			end

			local ease = anim.t * anim.t * (3 - 2 * anim.t)
			local pressEase = anim.pressT
			local errorEase = anim.errorT * anim.errorT * (3 - 2 * anim.errorT)
			local lift = IDLE_LIFT * (1 - pressEase)
			local shake = math.sin(anim.errorT * math.pi * 8) * errorEase * 4
			local fx = x + shake
			local fy = y - lift

			local r = cb1 + cbd1 * ease
			local g = cb2 + cbd2 * ease
			local b = cb3 + cbd3 * ease

			lg.setColor(colorOutline)
			lg.rectangle("fill", x - outlineW, y - outlineW, SIZE + outlineW * 2, SIZE + outlineW * 2, outerRadius)
			lg.setColor(r * 0.4, g * 0.4, b * 0.4, 0.96)
			lg.rectangle("fill", x, y, SIZE, SIZE, innerRadius)

			lg.setColor(colorOutline)
			lg.rectangle("fill", fx - outlineW, fy - outlineW, SIZE + outlineW * 2, SIZE + outlineW * 2, outerRadius)
			lg.setColor(r, g, b, 0.96)
			lg.rectangle("fill", fx, fy, SIZE, SIZE, innerRadius)

			local drawer = iconDrawers[abilityId]
			if drawer then drawer(fx + SIZE * 0.5, fy + SIZE * 0.5, 1) end

			if not ready then
				local ratio = min(1, cooldown / def.cooldown)
				lg.setColor(0.02 + 0.35 * errorEase, 0.03, 0.05, 0.72 + 0.18 * errorEase)
				lg.rectangle("fill", fx, fy + SIZE * (1 - ratio), SIZE, SIZE * ratio, innerRadius)
				lg.setColor(1, 1 - 0.55 * errorEase, 1 - 0.55 * errorEase, 0.9 + 0.1 * errorEase)
				Text.printfShadow(tostring(math.ceil(cooldown)), fx, fy + 20, SIZE, "center")
			elseif State.abilityTargeting and State.abilityTargeting.abilityId == abilityId then
				lg.setColor(1, 0.86, 0.35, 1)
				lg.setLineWidth(3)
				lg.rectangle("line", fx + 1, fy + 1, SIZE - 2, SIZE - 2, 8)
			end
		end
	end

	for i = count + 1, #buttons do buttons[i] = nil end
end

function AbilityBar.getButtons()
	return buttons
end

return AbilityBar
