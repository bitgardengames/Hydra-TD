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

local lg = love.graphics
local floor = math.floor
local min = math.min
local max = math.max

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
	if activeTime or (State.abilityTargeting and State.abilityTargeting.abilityId == button.abilityId) then
		iconState = "active"
	elseif not available then
		iconState = "locked"
	elseif not ready then
		iconState = {kind = "cooldown", progress = 1 - min(1, cooldown / def.cooldown)}
	else
		iconState = "ready"
	end
	AbilityIcons.draw(button.abilityId, fx + SIZE * 0.5, fy + SIZE * 0.5, available and 1 or 0.82, 1, iconState)

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

	local binding = Hotkeys.getDisplay("abilitySlot" .. button.slotIndex)
	if binding then
		lg.setColor(1, 1, 1, available and 0.95 or 0.6)
		Text.printfShadow(binding, fx + 4, fy + 2, SIZE - 8, "right")
	end
end

function AbilityBar.update(dt, mx, my)
	mx, my = mx or love.mouse.getPosition()
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
end

function AbilityBar.getButtons()
	return buttons
end

return AbilityBar
