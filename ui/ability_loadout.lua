local AbilityDefs = require("systems.ability_defs")
local AbilityIcons = require("ui.ability_icons")
local Button = require("ui.button")
local CampaignUnlocks = require("systems.campaign_unlocks")
local Fonts = require("core.fonts")
local L = require("core.localization")
local Save = require("core.save")
local Sound = require("systems.sound")
local Text = require("ui.text")
local Theme = require("core.theme")

local Loadout = {}
local lg = love.graphics

local SLOT_COUNT = 2
local ICON_SIZE = 46
local GAP = 8
local PAD = 14
local PANEL_W = PAD * 2 + ICON_SIZE * 6 + GAP * 5
local PANEL_H = 142

local buttons = {}
local equipped = {}
local selectedSlot = 1

local function unlockedAbilities()
	local result = {}
	for _, abilityId in ipairs(AbilityDefs.order) do
		if CampaignUnlocks.isAbilityUnlocked(abilityId) then
			result[#result + 1] = abilityId
		end
	end
	return result
end

local function contains(list, value)
	for _, item in ipairs(list) do
		if item == value then return true end
	end
	return false
end

local function saveSelection()
	Save.setEquippedAbilities(equipped)
end

local function selectAbility(abilityId)
	if contains(equipped, abilityId) then
		Sound.play("uiError")
		return
	end

	equipped[selectedSlot] = abilityId
	selectedSlot = selectedSlot == 1 and 2 or 1
	saveSelection()
	Sound.play("uiConfirm")
end

local function rebuildButtons()
	buttons = {}
	for slot = 1, SLOT_COUNT do
		buttons[#buttons + 1] = {kind = "slot", slot = slot, anim = Button.newAnimation()}
	end
	for _, abilityId in ipairs(unlockedAbilities()) do
		buttons[#buttons + 1] = {kind = "ability", abilityId = abilityId, anim = Button.newAnimation()}
	end
end

function Loadout.refresh()
	local available = unlockedAbilities()
	local saved = Save.data and Save.data.equippedAbilities or {}
	equipped = {}

	for i = 1, SLOT_COUNT do
		local abilityId = saved[i]
		if contains(available, abilityId) and not contains(equipped, abilityId) then
			equipped[#equipped + 1] = abilityId
		end
	end
	for _, abilityId in ipairs(available) do
		if #equipped >= SLOT_COUNT then break end
		if not contains(equipped, abilityId) then equipped[#equipped + 1] = abilityId end
	end

	selectedSlot = math.min(selectedSlot, math.max(1, #equipped + 1), SLOT_COUNT)
	saveSelection()
	rebuildButtons()
end

local function layout()
	local _, sh = lg.getDimensions()
	local x, y = 22, sh - PANEL_H - 22
	local poolY = y + 82
	for _, button in ipairs(buttons) do
		if button.kind == "slot" then
			button.x = x + PAD + (button.slot - 1) * (ICON_SIZE + GAP)
			button.y = y + 27
		else
			local index = 1
			for i, abilityId in ipairs(AbilityDefs.order) do
				if abilityId == button.abilityId then break end
				if CampaignUnlocks.isAbilityUnlocked(abilityId) then index = index + 1 end
			end
			button.x = x + PAD + (index - 1) * (ICON_SIZE + GAP)
			button.y = poolY
		end
		button.w, button.h = ICON_SIZE, ICON_SIZE
	end
	return x, y
end

function Loadout.update(dt)
	layout()
	Button.updateList(buttons, dt)
end

local function drawIconButton(button, abilityId, selected)
	local x, y = button.x, button.y
	local hovered = button.anim and button.anim.hovered
	lg.setColor(selected and Theme.ui.buttonHover or Theme.ui.button)
	lg.rectangle("fill", x, y, ICON_SIZE, ICON_SIZE, 6)
	lg.setColor(Theme.outline.color)
	lg.setLineWidth(selected and 3 or 2)
	lg.rectangle("line", x, y, ICON_SIZE, ICON_SIZE, 6)
	lg.setLineWidth(1)
	if abilityId then
		AbilityIcons.draw(abilityId, x + ICON_SIZE / 2, y + ICON_SIZE / 2, hovered and 0.92 or 0.84, 1)
	else
		Fonts.set("menu")
		lg.setColor(Theme.ui.text)
		Text.printfShadow("+", x, y + 9, ICON_SIZE, "center")
	end
end

function Loadout.draw()
	local x, y = layout()
	lg.setColor(Theme.outline.color)
	lg.rectangle("fill", x - 2, y - 2, PANEL_W + 4, PANEL_H + 4, 9)
	lg.setColor(Theme.ui.backdrop)
	lg.rectangle("fill", x, y, PANEL_W, PANEL_H, 8)

	Fonts.set("ui")
	lg.setColor(Theme.ui.text)
	Text.printfShadow(L("campaign.abilityLoadout"), x + PAD, y + 7, PANEL_W - PAD * 2, "left")

	for _, button in ipairs(buttons) do
		if button.kind == "slot" then
			drawIconButton(button, equipped[button.slot], selectedSlot == button.slot)
		else
			drawIconButton(button, button.abilityId, contains(equipped, button.abilityId))
			if button.anim.hovered then
				Fonts.set("ui")
				lg.setColor(Theme.ui.text)
				Text.printfShadow(L(AbilityDefs[button.abilityId].nameKey), x + 126, y + 48, PANEL_W - 140, "left")
			end
		end
	end
end

function Loadout.mousepressed(x, y, mouseButton)
	return Button.mousepressedList(buttons, x, y, mouseButton)
end

function Loadout.mousereleased(x, y, mouseButton)
	for _, button in ipairs(buttons) do
		local wasPressed = button.anim and button.anim.pressed
		if Button.mousereleased(button, x, y, mouseButton) then return true end
		if wasPressed and x >= button.x and x <= button.x + button.w and y >= button.y and y <= button.y + button.h then
			if button.kind == "slot" then
				selectedSlot = button.slot
				Sound.play("uiMove")
			else
				selectAbility(button.abilityId)
			end
			return true
		end
	end
end

function Loadout.getEquipped()
	return {equipped[1], equipped[2]}
end

return Loadout
