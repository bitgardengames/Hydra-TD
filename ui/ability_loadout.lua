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
local COLLAPSED_W = PAD * 2 + ICON_SIZE * SLOT_COUNT + GAP
local SLOT_BOTTOM_INSET = 15
local TITLE_GAP = 8
local TITLE_H = 22
local POOL_GAP = 8
local POOL_LABEL_H = 22

local buttons = {}
local equipped = {}
local selectedSlot

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

local rebuildButtons

local function selectAbility(abilityId)
	-- Re-check progression at the point of mutation. The campaign can refresh its
	-- progress while this screen is open, so the button's cached state is not a
	-- sufficient authorization check on its own.
	if not CampaignUnlocks.isAbilityUnlocked(abilityId) then
		Sound.play("uiError")
		return
	end

	if equipped[selectedSlot] == abilityId then
		selectedSlot = nil
		rebuildButtons()
		Sound.play("uiMove")
		return
	end

	if contains(equipped, abilityId) then
		Sound.play("uiError")
		return
	end

	equipped[selectedSlot] = abilityId
	selectedSlot = nil
	saveSelection()
	rebuildButtons()
	Sound.play("uiConfirm")
end

rebuildButtons = function()
	buttons = {}
	for slot = 1, SLOT_COUNT do
		buttons[#buttons + 1] = {kind = "slot", slot = slot, anim = Button.newAnimation()}
	end
	if selectedSlot then
		for _, abilityId in ipairs(unlockedAbilities()) do
			buttons[#buttons + 1] = {
				kind = "ability",
				abilityId = abilityId,
				anim = Button.newAnimation(),
			}
		end
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

	selectedSlot = nil
	saveSelection()
	rebuildButtons()
end

local function layout()
	local _, sh = lg.getDimensions()
	local abilityCount = selectedSlot and #unlockedAbilities() or 0
	local panelW = math.max(COLLAPSED_W, PAD * 2 + ICON_SIZE * abilityCount + GAP * math.max(0, abilityCount - 1))
	local panelBottom = sh - 22
	-- Anchor the slots to the bottom of the screen so opening the picker does not
	-- make the controls jump. The picker grows upward above the title and slots.
	local slotY = panelBottom - SLOT_BOTTOM_INSET - ICON_SIZE
	local titleY = slotY - TITLE_GAP - TITLE_H
	local poolY = titleY - POOL_GAP - ICON_SIZE
	local panelTop = selectedSlot and poolY - POOL_LABEL_H - PAD or titleY - PAD
	local panelH = panelBottom - panelTop
	local x, y = 22, panelTop
	local abilityIndex = 0
	for _, button in ipairs(buttons) do
		if button.kind == "slot" then
			button.x = x + PAD + (button.slot - 1) * (ICON_SIZE + GAP)
			button.y = slotY
		else
			abilityIndex = abilityIndex + 1
			button.x = x + PAD + (abilityIndex - 1) * (ICON_SIZE + GAP)
			button.y = poolY
		end
		button.w, button.h = ICON_SIZE, ICON_SIZE
	end
	return x, y, panelW, panelH, titleY, poolY
end

function Loadout.update(dt)
	layout()
	Button.updateList(buttons, dt)
end

local function drawIconButton(button, abilityId, selected)
	local x, y = button.x, button.y
	local hovered = button.anim and button.anim.hovered
	local face = selected and Theme.ui.buttonHover or Theme.ui.button
	lg.setColor(face[1], face[2], face[3], face[4] or 1)
	lg.rectangle("fill", x, y, ICON_SIZE, ICON_SIZE, 6)
	lg.setColor(Theme.outline.color)
	lg.setLineWidth(selected and 3 or 2)
	lg.rectangle("line", x, y, ICON_SIZE, ICON_SIZE, 6)
	lg.setLineWidth(1)
	if abilityId then
		AbilityIcons.draw(abilityId, x + ICON_SIZE / 2, y + ICON_SIZE / 2,
			hovered and 0.92 or 0.84, 1)
	else
		Fonts.set("menu")
		lg.setColor(Theme.ui.text)
		Text.printfShadow("+", x, y + 9, ICON_SIZE, "center")
	end
end

function Loadout.draw()
	local x, y, panelW, panelH, titleY, poolY = layout()
	lg.setColor(Theme.outline.color)
	lg.rectangle("fill", x - 2, y - 2, panelW + 4, panelH + 4, 9)
	lg.setColor(Theme.ui.backdrop)
	lg.rectangle("fill", x, y, panelW, panelH, 8)

	Fonts.set("ui")
	lg.setColor(Theme.ui.text)
	Text.printfShadow(L("campaign.abilityLoadout"), x + PAD, titleY, panelW - PAD * 2, "left")

	for _, button in ipairs(buttons) do
		if button.kind == "slot" then
			drawIconButton(button, equipped[button.slot], selectedSlot == button.slot)
		else
			drawIconButton(button, button.abilityId, equipped[selectedSlot] == button.abilityId)
			if button.anim.hovered then
				Fonts.set("ui")
				lg.setColor(Theme.ui.text)
				local label = L(AbilityDefs[button.abilityId].nameKey)
				Text.printfShadow(label, x + PAD, poolY - POOL_LABEL_H, panelW - PAD * 2, "left")
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
				-- The slots control the picker as a single panel: clicking either slot
				-- closes an open picker, while clicking a slot when closed opens it for
				-- that slot.
				selectedSlot = selectedSlot and nil or button.slot
				rebuildButtons()
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
