local State = require("core.state")
local Save = require("core.save")
local Theme = require("core.theme")
local AbilityDefs = require("systems.ability_defs")
local CampaignUnlocks = require("systems.campaign_unlocks")
local Abilities = require("systems.abilities")
local Text = require("ui.text")
local Tooltip = require("ui.tooltip")
local L = require("core.localization")
local Button = require("ui.button")
local Hotkeys = require("core.hotkeys")
local AbilityIcons = require("ui.ability_icons")
local Effects = require("world.effects")
local Camera = require("core.camera")

local lg = love.graphics
local floor = math.floor
local min = math.min
local max = math.max
local pi = math.pi

local AbilityBar = {}
local buttons = {}
local abilityTooltips = {}

local SIZE = 58
-- Match the tower shop's vertical rhythm so the two groups feel like parts of
-- the same HUD.
local GAP = 18
local PANEL_PAD = 12
local PANEL_INSET = 16
local MAX_ABILITIES = 6
local IDLE_LIFT = 5
local NEAR_READY_WINDOW = 3

local colorOutline = Theme.outline.color
local colorBackdrop = Theme.ui.backdrop
local outlineW = Theme.outline.width

local outerRadius = 9 + outlineW * 0.5
local innerRadius = 9 - outlineW * 0.25
local panelRadius = 18 + outlineW * 0.5
local panelInnerRadius = 18 - outlineW * 0.25

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
	local anim = button.anim
	if not anim then
		anim = Button.newAnimation({errorT = 0})
		button.anim = anim
	end
	Button.updateAnimation(anim, hovered, dt)
	anim.errorT = max(0, anim.errorT - dt * 4)
	return anim
end

local function drawButton(button, def, activeTime)
	local x, y = button.x, button.y
	local available = button.lockMessage == nil
	local cooldown = State.abilityCooldowns[button.abilityId] or 0
	local ready = available and cooldown <= 0

	local anim = button.anim or Button.newAnimation({errorT = 0})
	local errorEase = anim.errorT * anim.errorT * (3 - 2 * anim.errorT)
	local fx = x + math.sin(anim.errorT * math.pi * 8) * errorEase * 4
	local fy = y - IDLE_LIFT * (1 - anim.pressT)
	local r, g, b = Button.getHoverColor(anim)

	lg.setColor(colorOutline)
	lg.rectangle("fill", x - outlineW, y - outlineW, SIZE + outlineW * 2, SIZE + outlineW * 2, outerRadius)
	lg.setColor(r * 0.4, g * 0.4, b * 0.4, 0.96)
	lg.rectangle("fill", x, y, SIZE, SIZE, innerRadius)

	lg.setColor(colorOutline)
	lg.rectangle("fill", fx - outlineW, fy - outlineW, SIZE + outlineW * 2, SIZE + outlineW * 2, outerRadius)
	lg.setColor(r, g, b, available and 0.96 or 0.48)
	lg.rectangle("fill", fx, fy, SIZE, SIZE, innerRadius)

	local iconState
	if activeTime then
		iconState = {kind = "sustained", ratio = min(1, activeTime / (def.effect.duration or activeTime))}
	elseif State.abilityTargeting and State.abilityTargeting.abilityId == button.abilityId then
		iconState = "active"
	elseif not available then
		iconState = "locked"
	elseif not ready and cooldown <= NEAR_READY_WINDOW then
		iconState = {kind = "nearly_ready", progress = 1 - min(1, cooldown / def.cooldown)}
	elseif not ready then
		iconState = {kind = "cooldown", progress = 1 - min(1, cooldown / def.cooldown)}
	else
		iconState = "ready"
	end
	AbilityIcons.draw(button.abilityId, fx + SIZE * 0.5, fy + SIZE * 0.5, available and 1 or 0.82, 1, iconState)

	local feedback, feedbackClock = Abilities.getFeedback()
	local readyAt = feedback.ready[button.abilityId]
	local readyAge = readyAt and feedbackClock - readyAt
	if readyAge and readyAge >= 0 and readyAge < .55 then
		local t = readyAge / .55
		local reducedFlash = Save.data and Save.data.settings and Save.data.settings.reducedFlash
		local grow = reducedFlash and (2 + 3 * math.sin(t * math.pi)) or (2 + 8 * t)
		lg.setLineWidth(reducedFlash and 2 or 3)
		lg.setColor(.42, 1, .62, reducedFlash and (.8 * (1 - t)) or (.95 * (1 - t)))
		lg.rectangle("line", fx - grow, fy - grow, SIZE + grow * 2, SIZE + grow * 2, 10 + grow)
		-- Reduced-flash keeps only outline/scale motion; the standard treatment
		-- adds a short radial sweep rather than flashing the whole slot.
		if not reducedFlash then
			lg.arc("line", fx + SIZE * .5, fy + SIZE * .5, SIZE * .47,
				-pi / 2, -pi / 2 + pi * 2 * min(1, t * 2.5))
		end
	end

	if activeTime then
		local activeAlpha = Effects.expirationPulse(activeTime, State.abilityClock or 0)
		lg.setColor(1, .78, .12, .35 + .6 * activeAlpha)
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

	local binding = Hotkeys.getDisplay("abilitySlot" .. button.slotIndex)
	if binding then
		lg.setColor(1, 1, 1, available and 0.95 or 0.6)
		Text.printfShadow(binding, fx + 4, fy + 2, SIZE - 8, "right")
	end
end

function AbilityBar.update(dt, mx, my)
	if mx == nil or my == nil then
		local mouseX, mouseY = love.mouse.getPosition()
		mx, my = mx or mouseX, my or mouseY
	end
	local equipped = getDisplayedAbilities()
	local count = min(#equipped, MAX_ABILITIES)
	local sw, sh = lg.getDimensions()
	local totalH = count * SIZE + math.max(0, count - 1) * GAP
	local startY = floor((sh - totalH) * 0.5)
	local panelW = SIZE + PANEL_PAD * 2
	local panelX = sw - PANEL_INSET - panelW

	for i = 1, count do
		local abilityId = equipped[i]
		local def = AbilityDefs[abilityId]
		if def then
			local x, y = panelX + PANEL_PAD, startY + (i - 1) * (SIZE + GAP)
			local hovered = mx >= x and mx <= x + SIZE and my >= y and my <= y + SIZE
			local button = buttons[i] or {}
			buttons[i] = button
			button.x, button.y, button.w, button.h = x, y, SIZE, SIZE
			button.abilityId = abilityId
			button.slotIndex = i
			button.lockMessage = CampaignUnlocks.getAbilityLockMessage(abilityId, i)
			button.enabled = button.lockMessage == nil and (State.abilityCooldowns[abilityId] or 0) <= 0
			updateButton(button, hovered, dt)
			if hovered then showTooltip(abilityId, def) end
		end
	end
	for i = count + 1, #buttons do buttons[i] = nil end
end

function AbilityBar.draw()
	local count = #buttons
	local activeRemaining = getActiveTimes()
	local sw = lg.getWidth()
	local totalH = count * SIZE + math.max(0, count - 1) * GAP
	local startY = count > 0 and buttons[1].y or 0
	local panelW = SIZE + PANEL_PAD * 2
	local panelH = totalH + PANEL_PAD * 2
	local panelX = sw - PANEL_INSET - panelW
	local panelY = startY - PANEL_PAD

	if count > 0 then
		lg.setColor(colorOutline)
		lg.rectangle("fill", panelX - outlineW, panelY - outlineW, panelW + outlineW * 2, panelH + outlineW * 2, panelRadius)
		lg.setColor(colorBackdrop)
		lg.rectangle("fill", panelX, panelY, panelW, panelH, panelInnerRadius)
	end

	for i = 1, count do
		local button = buttons[i]
		local def = AbilityDefs[button.abilityId]
		if def then drawButton(button, def, activeRemaining[button.abilityId]) end
	end

	local targeting = State.abilityTargeting
	if targeting and targeting.x and targeting.y then
		local preview = Abilities.getTargetPreview(targeting.x, targeting.y)
		if preview then
			local sx, sy = Camera.worldToScreen(targeting.x, targeting.y)
			local status, color
			if preview.reason == "outside" then status, color = "OUT OF BOUNDS", {1, .28, .28}
			elseif preview.count == 0 then status, color = "EMPTY", {1, .68, .2}
			else status, color = "VALID", (preview.def.target and preview.def.target.color) or {.4, 1, .6} end
			lg.setColor(.02, .03, .05, .86)
			lg.rectangle("fill", sx - 48, sy - 25, 96, 23, 6)
			lg.setColor(color[1], color[2], color[3], 1)
			Text.printfShadow(string.format("%d · %s", preview.count, status), sx - 48, sy - 22, 96, "center")
		end
	end

	local feedback, clock = Abilities.getFeedback()
	local cast = feedback.cast
	if cast and cast.x and cast.y then
		local age = clock - cast.started
		local alpha = max(0, 1 - age / (cast.expires - cast.started))
		local def = AbilityDefs[cast.abilityId]
		local color = (def and def.target and def.target.color) or {1, .75, .2}
		local sx, sy = Camera.worldToScreen(cast.x, cast.y)
		for _, button in ipairs(buttons) do
			if button.abilityId == cast.abilityId then
				lg.setColor(color[1], color[2], color[3], .7 * alpha)
				lg.setLineWidth(2)
				lg.line(button.x, button.y + SIZE * .5, sx, sy)
				AbilityIcons.draw(cast.abilityId, sx, sy, .48 + age * .15, alpha, "active")
				break
			end
		end
	end

	-- Sustained targets repeat the slot's icon/color and carry a compact timer.
	for _, effect in ipairs((select(1, Abilities.getActive()))) do
		local def = effect.abilityId and AbilityDefs[effect.abilityId]
		if def and def.sustained and def.sustained.entityMarker then
			local entities = effect.towers or (def.target and def.target.entities == "enemies"
				and Abilities.getEntitiesInActiveArea(effect, "enemies")) or {}
			local remaining = max(0, effect.expires - clock)
			for _, entity in ipairs(entities) do
				local sx, sy = Camera.worldToScreen(entity.rx or entity.x, (entity.ry or entity.renderY or entity.y) - 27)
				AbilityIcons.draw(effect.abilityId, sx - 13, sy, .28, .9, "sustained")
				Text.printfShadow(string.format("%.1f", remaining), sx, sy - 7, 38, "left")
			end
		end
	end
end

function AbilityBar.getButtons()
	return buttons
end

return AbilityBar
