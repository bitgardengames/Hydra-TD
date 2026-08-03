local State = require("core.state")
local Theme = require("core.theme")
local AbilityDefs = require("systems.ability_defs")
local Text = require("ui.text")

local lg = love.graphics
local floor = math.floor
local min = math.min

local AbilityBar = {}
local buttons = {}

local SIZE = 58
local GAP = 10
local RIGHT = 18
local MAX_ABILITIES = 4

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

			lg.setColor(Theme.outline.color)
			lg.rectangle("fill", x - 3, y - 3, SIZE + 6, SIZE + 6, 12)
			lg.setColor(hovered and 0.25 or 0.13, hovered and 0.31 or 0.16, hovered and 0.38 or 0.20, 0.96)
			lg.rectangle("fill", x, y, SIZE, SIZE, 9)

			local drawer = iconDrawers[abilityId]
			if drawer then drawer(x + SIZE * 0.5, y + SIZE * 0.5, 1) end

			if not ready then
				local ratio = min(1, cooldown / def.cooldown)
				lg.setColor(0.02, 0.03, 0.05, 0.72)
				lg.rectangle("fill", x, y + SIZE * (1 - ratio), SIZE, SIZE * ratio, 9)
				lg.setColor(1, 1, 1, 0.9)
				Text.printfShadow(tostring(math.ceil(cooldown)), x, y + 20, SIZE, "center")
			elseif State.abilityTargeting and State.abilityTargeting.abilityId == abilityId then
				lg.setColor(1, 0.86, 0.35, 1)
				lg.setLineWidth(3)
				lg.rectangle("line", x + 1, y + 1, SIZE - 2, SIZE - 2, 8)
			end
		end
	end

	for i = count + 1, #buttons do buttons[i] = nil end
end

function AbilityBar.getButtons()
	return buttons
end

return AbilityBar
