local State = require("core.state")
local Save = require("core.save")
local Theme = require("core.theme")
local AbilityDefs = require("systems.ability_defs")
local CampaignUnlocks = require("systems.campaign_unlocks")
local Abilities = require("systems.abilities")
local Text = require("ui.text")
local Tooltip = require("ui.tooltip")
local L = require("core.localization")

local lg = love.graphics
local floor = math.floor
local min = math.min
local max = math.max

local AbilityBar = {}
local buttons = {}
local abilityTooltips = {}

local SIZE = 58
local GAP = 10
local RIGHT = 18
local MAX_ABILITIES = 6
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


local function drawOverdrive(cx,cy,s) lg.setColor(1,.75,.2,1); lg.setLineWidth(3*s); lg.circle("line",cx,cy,16*s); lg.line(cx,cy-15*s,cx+7*s,cy-3*s,cx+1*s,cy-3*s,cx+8*s,cy+14*s) end
local function drawGravity(cx,cy,s) lg.setColor(.65,.35,1,1); lg.setLineWidth(3*s); for r=6,17,5 do lg.arc("line",cx,cy,r*s,r*.4,r*.4+4.7) end end
local function drawGoldRush(cx,cy,s) lg.setColor(1,.78,.16,1); lg.circle("fill",cx,cy,17*s); lg.setColor(1,.94,.5,1); lg.circle("line",cx,cy,13*s); lg.setColor(.35,.2,.03,1); Text.printfShadow("$",cx-10*s,cy-13*s,20*s,"center") end
local function drawLastStand(cx,cy,s) lg.setColor(1,.62,.2,1); lg.setLineWidth(3*s); lg.circle("line",cx,cy,16*s); lg.line(cx-20*s,cy,cx+20*s,cy); lg.line(cx,cy-20*s,cx,cy+20*s) end
local iconDrawers = {meteor=drawMeteor, frost_nova=drawFrost, overdrive=drawOverdrive, gravity_well=drawGravity, gold_rush=drawGoldRush, last_stand=drawLastStand}

local function showTooltip(abilityId, def)
	local title = L(def.nameKey)
	local description = L(def.descKey)
	local tooltip = abilityTooltips[abilityId]

	-- Rebuild if localization changed, while keeping the rows table stable during
	-- normal hovering so Tooltip does not recalculate its layout every frame.
	if not tooltip or tooltip.title ~= title or tooltip.rows[1].text ~= description then
		tooltip = {
			title = title,
			rows = {{kind = "text", text = description}},
		}
		abilityTooltips[abilityId] = tooltip
	end

	Tooltip.show(tooltip)
end

local function getDisplayedAbilities()
	local displayed = {}
	local included = {}

	local function appendUnique(abilityIds)
		for _, abilityId in ipairs(abilityIds or {}) do
			if not included[abilityId] then
				displayed[#displayed + 1] = abilityId
				included[abilityId] = true
			end
		end
	end

	-- Runtime equipment includes progression fallbacks. Saved equipment is kept
	-- afterward so locked selections can still preview their requirements.
	appendUnique(State.equippedAbilities)
	appendUnique(Save.data and Save.data.equippedAbilities)

	return displayed
end

local function getActiveTimes()
	local remaining = {}
	local activeEffects, clock = Abilities.getActive()
	for _, effect in ipairs(activeEffects) do
		if effect.abilityId then
			remaining[effect.abilityId] = max(0, effect.expires - clock)
		end
	end
	return remaining
end

local function updateButton(button, hovered, dt)
	local anim = ensureAnim(button)
	if hovered ~= anim.hovered then
		anim.active = true
	end
	anim.hovered = hovered
	anim.pressT = anim.pressed and min(1, anim.pressT + dt * 20) or max(0, anim.pressT - dt * 20)
	anim.errorT = max(0, anim.errorT - dt * 4)

	if anim.active then
		local direction = hovered and 1 or -1
		anim.t = min(1, max(0, anim.t + direction * dt * 10))
		anim.active = anim.t > 0 and anim.t < 1
	end

	return anim
end

local function drawButton(button, def, activeTime, dt, hovered)
	local x, y = button.x, button.y
	local available = button.lockMessage == nil
	local cooldown = State.abilityCooldowns[button.abilityId] or 0
	local ready = available and cooldown <= 0
	button.enabled = ready

	local anim = updateButton(button, hovered, dt)
	local ease = anim.t * anim.t * (3 - 2 * anim.t)
	local errorEase = anim.errorT * anim.errorT * (3 - 2 * anim.errorT)
	local fx = x + math.sin(anim.errorT * math.pi * 8) * errorEase * 4
	local fy = y - IDLE_LIFT * (1 - anim.pressT)
	local r = cb1 + cbd1 * ease
	local g = cb2 + cbd2 * ease
	local b = cb3 + cbd3 * ease

	lg.setColor(colorOutline)
	lg.rectangle("fill", x - outlineW, y - outlineW, SIZE + outlineW * 2, SIZE + outlineW * 2, outerRadius)
	lg.setColor(r * 0.4, g * 0.4, b * 0.4, 0.96)
	lg.rectangle("fill", x, y, SIZE, SIZE, innerRadius)

	lg.setColor(colorOutline)
	lg.rectangle("fill", fx - outlineW, fy - outlineW, SIZE + outlineW * 2, SIZE + outlineW * 2, outerRadius)
	lg.setColor(r, g, b, available and 0.96 or 0.48)
	lg.rectangle("fill", fx, fy, SIZE, SIZE, innerRadius)

	local drawer = iconDrawers[button.abilityId]
	if drawer then
		drawer(fx + SIZE * 0.5, fy + SIZE * 0.5, available and 1 or 0.82)
	end

	if activeTime then
		lg.setColor(1, .78, .12, .95)
		lg.setLineWidth(3)
		lg.rectangle("line", fx + 1, fy + 1, SIZE - 2, SIZE - 2, 8)
		Text.printfShadow(string.format("%.1fs", activeTime), fx, fy + SIZE - 20, SIZE, "center")
	elseif not available then
		lg.setColor(0.02 + 0.35 * errorEase, 0.03, 0.05, 0.7 + 0.18 * errorEase)
		lg.rectangle("fill", fx, fy, SIZE, SIZE, innerRadius)
		lg.setColor(1, 1 - 0.55 * errorEase, 1 - 0.55 * errorEase, 0.95)
		Text.printfShadow("🔒", fx, fy + 6, SIZE, "center")
		Text.printfShadow(button.lockMessage, fx + 3, fy + SIZE - 25, SIZE - 6, "center")
	elseif not ready then
		local ratio = min(1, cooldown / def.cooldown)
		lg.setColor(0.02 + 0.35 * errorEase, 0.03, 0.05, 0.72 + 0.18 * errorEase)
		lg.rectangle("fill", fx, fy + SIZE * (1 - ratio), SIZE, SIZE * ratio, innerRadius)
		lg.setColor(1, 1 - 0.55 * errorEase, 1 - 0.55 * errorEase, 0.9 + 0.1 * errorEase)
		Text.printfShadow(tostring(math.ceil(cooldown)), fx, fy + 20, SIZE, "center")
	elseif State.abilityTargeting and State.abilityTargeting.abilityId == button.abilityId then
		lg.setColor(1, 0.86, 0.35, 1)
		lg.setLineWidth(3)
		lg.rectangle("line", fx + 1, fy + 1, SIZE - 2, SIZE - 2, 8)
	end
end

function AbilityBar.draw(dt, mx, my)
	local equipped = getDisplayedAbilities()
	local count = min(#equipped, MAX_ABILITIES)
	local activeRemaining = getActiveTimes()
	local sw, sh = lg.getDimensions()
	local totalH = count * SIZE + math.max(0, count - 1) * GAP
	local startY = floor((sh - totalH) * 0.5)

	for i = 1, count do
		local abilityId = equipped[i]
		local def = AbilityDefs[abilityId]
		if def then
			local x, y = sw - RIGHT - SIZE, startY + (i - 1) * (SIZE + GAP)
			local lockMessage = CampaignUnlocks.getAbilityLockMessage(abilityId, i)
			local hovered = mx >= x and mx <= x + SIZE and my >= y and my <= y + SIZE
			if hovered then
				showTooltip(abilityId, def)
			end
			local button = buttons[i] or {anim = {}}
			buttons[i] = button
			button.x, button.y, button.w, button.h = x, y, SIZE, SIZE
			button.abilityId = abilityId
			button.lockMessage = lockMessage
			drawButton(button, def, activeRemaining[abilityId], dt, hovered)
		end
	end

	for i = count + 1, #buttons do buttons[i] = nil end
end

function AbilityBar.getButtons()
	return buttons
end

return AbilityBar
