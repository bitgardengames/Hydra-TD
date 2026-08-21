local State = require("core.state")
local Theme = require("core.theme")
local AbilityDefs = require("systems.ability_defs")
local CampaignUnlocks = require("systems.campaign_unlocks")
local Abilities = require("systems.abilities")
local Text = require("ui.text")
local Button = require("ui.button")
local Hotkeys = require("core.hotkeys")
local AbilityIcons = require("ui.ability_icons")
local AbilityTooltip = require("ui.ability_tooltip")
local Effects = require("world.effects")
local Sound = require("systems.sound")

local lg = love.graphics
local floor = math.floor
local min = math.min
local max = math.max

local AbilityBar = {}
local buttons = {}
local lastAbilityClock = nil

local SIZE = 52
-- Match the tower shop's rhythm so the two groups feel like parts of the same
-- HUD.
local GAP = 18
local PANEL_PAD = 12
local PANEL_INSET = 16
local MAX_ABILITIES = 6
local IDLE_LIFT = 5
local CHARGE_BAR_GAP = 5
local CHARGE_BAR_H = 7
local SLOT_W = SIZE
local SLOT_H = SIZE + CHARGE_BAR_GAP + CHARGE_BAR_H

local colorOutline = Theme.outline.color
local colorBackdrop = Theme.ui.backdrop
local outlineW = Theme.outline.width

local outerRadius = 9 + outlineW * 0.5
local innerRadius = 9 - outlineW * 0.25
local panelRadius = 18 + outlineW * 0.5
local panelInnerRadius = 18 - outlineW * 0.25

local function getDisplayedAbilities()
	local displayed = {}
	local unlockedSlots = CampaignUnlocks.getUnlockedAbilitySlots()
	for _, abilityId in ipairs(State.equippedAbilities or {}) do
		if #displayed >= unlockedSlots then break end
		if CampaignUnlocks.isAbilityUnlocked(abilityId) then
			displayed[#displayed + 1] = abilityId
		end
	end

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
	local charge = State.abilityCharges[button.abilityId] or 0
	local ready = available and charge >= def.chargeRequired

	local anim = button.anim or Button.newAnimation({errorT = 0})
	local errorEase = anim.errorT * anim.errorT * (3 - 2 * anim.errorT)
	-- Keep invalid clicks legible without making the whole ability tray lurch.
	local fx = x + math.sin(anim.errorT * math.pi * 5) * errorEase * 1.75
	local fy = y - IDLE_LIFT * (1 - anim.pressT)
	local readyT = button.readyT or 0
	local readyEase = readyT * readyT * (3 - 2 * readyT)
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
		iconState = "charging"
	else
		iconState = "ready"
	end
	AbilityIcons.draw(button.abilityId, fx + SIZE * 0.5, fy + SIZE * 0.5, (available and 1 or 0.82) + readyEase * 0.1, 1, iconState)

	-- Preserve the authored icon colors beneath a neutral veil. This reads as
	-- temporarily disabled without replacing the ability art with a dim glyph.
	if not available or not ready then
		lg.setColor(0.12, 0.13, 0.15, available and (0.38 + 0.12 * errorEase) or (0.62 + 0.1 * errorEase))
		lg.rectangle("fill", fx, fy, SIZE, SIZE, innerRadius)
	end

	-- A high-contrast border remains visible even with motion/particle options
	-- disabled; the moving sweep is merely an additional short accent.
	if readyT > 0 and ready then
		lg.setColor(1, 0.9, 0.3, 0.45 + readyEase * 0.55)
		lg.setLineWidth(2 + readyEase * 2)
		lg.rectangle("line", fx - readyEase * 2, fy - readyEase * 2,
			SIZE + readyEase * 4, SIZE + readyEase * 4, 9)
	end

	if activeTime then
		local activeAlpha = Effects.expirationPulse(activeTime, State.abilityClock or 0)
		lg.setColor(1, .78, .12, .35 + .6 * activeAlpha)
		lg.setLineWidth(3)
		lg.rectangle("line", fx + 1, fy + 1, SIZE - 2, SIZE - 2, 8)
		Text.printfShadow(string.format("%.1fs", activeTime), fx, fy + SIZE - 20, SIZE, "center")
	elseif not available then
		lg.setColor(1, 1 - 0.55 * errorEase, 1 - 0.55 * errorEase, 0.95)
		Text.printfShadow("🔒", fx, fy + 6, SIZE, "center")
	elseif not ready then
		local ratio = min(1, charge / def.chargeRequired)
		local barY = fy + SIZE + CHARGE_BAR_GAP
		lg.setColor(colorOutline)
		lg.rectangle("fill", fx - outlineW, barY - outlineW,
			SIZE + outlineW * 2, CHARGE_BAR_H + outlineW * 2, CHARGE_BAR_H * 0.5 + outlineW)
		lg.setColor(0.04 + 0.25 * errorEase, 0.05, 0.07, 0.96)
		lg.rectangle("fill", fx, barY, SIZE, CHARGE_BAR_H, CHARGE_BAR_H * 0.5)
		if ratio > 0 then
			lg.setColor(1, 0.78 - 0.22 * errorEase, 0.18, 1)
			local fillW = SIZE * ratio
			lg.rectangle("fill", fx, barY, fillW, CHARGE_BAR_H, CHARGE_BAR_H * 0.5)
		end
	elseif State.abilityTargeting and State.abilityTargeting.abilityId == button.abilityId then
		lg.setColor(1, 0.86, 0.35, 1)
		lg.setLineWidth(3)
		lg.rectangle("line", fx + 1, fy + 1, SIZE - 2, SIZE - 2, 8)
	end

	local binding = Hotkeys.getDisplay("abilitySlot" .. button.slotIndex)
	if binding then
		lg.setColor(1, 1, 1, available and 0.95 or 0.6)
		Text.printfShadow(binding, fx + 4, fy + 2, SIZE - 8, "left")
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
	local totalW = count * SLOT_W + math.max(0, count - 1) * GAP
	local panelW = totalW + PANEL_PAD * 2
	local panelH = SLOT_H + PANEL_PAD * 2
	local panelX = floor((sw - panelW) * 0.5)
	local panelY = sh - PANEL_INSET - panelH
	local clock = State.abilityClock or 0
	local runReset = lastAbilityClock ~= nil and clock < lastAbilityClock
	lastAbilityClock = clock

	for i = 1, count do
		local abilityId = equipped[i]
		local def = AbilityDefs[abilityId]
		if def then
			local x, y = panelX + PANEL_PAD + (i - 1) * (SLOT_W + GAP), panelY + PANEL_PAD
			local hovered = mx >= x and mx <= x + SIZE and my >= y and my <= y + SIZE
			local button = buttons[i] or {}
			buttons[i] = button
			local charge = State.abilityCharges[abilityId] or 0
			local lockMessage = CampaignUnlocks.getAbilityLockMessage(abilityId, i)
			local available = lockMessage == nil
			local sameDisplay = button.abilityId == abilityId and button.wasAvailable == available
			if sameDisplay and not runReset and button.previousCharge and
				button.previousCharge < def.chargeRequired and charge >= def.chargeRequired and available then
				button.readyT = 1
				Sound.playAbilityReady()
			elseif not sameDisplay or runReset then
				button.readyT = 0
			end
			button.x, button.y, button.w, button.h = x, y, SIZE, SIZE
			button.abilityId = abilityId
			button.slotIndex = i
			button.lockMessage = lockMessage
			button.enabled = available and charge >= def.chargeRequired
			button.hovered = hovered
			button.previousCharge = charge
			button.wasAvailable = available
			button.readyT = max(0, (button.readyT or 0) - dt * 2.8)
			updateButton(button, hovered, dt)
		end
	end
	for i = count + 1, #buttons do buttons[i] = nil end
end

function AbilityBar.draw()
	local count = #buttons
	local activeRemaining = getActiveTimes()
	local sw, sh = lg.getDimensions()
	local totalW = count * SLOT_W + math.max(0, count - 1) * GAP
	local panelW = totalW + PANEL_PAD * 2
	local panelH = SLOT_H + PANEL_PAD * 2
	local panelX = floor((sw - panelW) * 0.5)
	local panelY = sh - PANEL_INSET - panelH

	if count > 0 then
		lg.setColor(colorOutline)
		lg.rectangle("fill", panelX - outlineW, panelY - outlineW, panelW + outlineW * 2, panelH + outlineW * 2, panelRadius)
		lg.setColor(colorBackdrop)
		lg.rectangle("fill", panelX, panelY, panelW, panelH, panelInnerRadius)
	end

	for i = 1, count do
		local button = buttons[i]
		local def = AbilityDefs[button.abilityId]
		if def then
			drawButton(button, def, activeRemaining[button.abilityId])
			if button.hovered then AbilityTooltip.show(button.abilityId) end
		end
	end
end

function AbilityBar.getButtons()
	return buttons
end

return AbilityBar
