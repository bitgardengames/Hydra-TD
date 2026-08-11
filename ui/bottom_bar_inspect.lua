local State = require("core.state")
local Util = require("core.util")
local Towers = require("world.towers")
local Enemies = require("world.enemies")
local Sound = require("systems.sound")
local ModulePicker = require("ui.module_picker")
local Hotkeys = require("core.hotkeys")
local Tooltip = require("ui.tooltip")
local Floaters = require("ui.floaters")
local Text = require("ui.text")
local Button = require("ui.button")
local Theme = require("core.theme")
local L = require("core.localization")

local Inspect = {}

local lg = love.graphics
local min = math.min
local max = math.max
local abs = math.abs
local floor = math.floor

local formatInt = Util.formatInt

-- Animation state
local inspectAnim = 0
local inspectTarget = 0

-- Colors
local colorBackdrop = Theme.ui.backdrop
local colorOutline = Theme.outline.color
local colorText = Theme.ui.text
local colorGood = Theme.ui.good
local colorBad = Theme.ui.bad
local colorDisabled = Theme.ui.buttonDisabled

local ct1, ct2, ct3 = colorText[1], colorText[2], colorText[3]
local cd1, cd2, cd3 = colorDisabled[1], colorDisabled[2], colorDisabled[3]


-- Layout constants local to inspect
local OUTER_PAD = 12
local PANEL_GAP = 10
local PAD = 8
local BUTTON_H = 32
local GAP = 16
local IDLE_LIFT = 6
local STAT_LINE_H = 22

local outlineW = Theme.outline.width
local baseRadius = 6 * 3
local outerRadius = baseRadius + outlineW * 0.5
local innerRadius = baseRadius - outlineW * 0.25

local outerSmallRadius = 6 + outlineW * 0.5
local innerSmallRadius = 6 - outlineW * 0.25

local inspectButtons

local function showUpgradeFailure(t, messageKey)
	Sound.play("uiError")

	local upgradeBtn = inspectButtons[1]
	if upgradeBtn and upgradeBtn.anim then
		upgradeBtn.anim.errorT = 1
	end

	local floaterY = (t.renderY or t.y) - 30
	Floaters.add(t.x, floaterY, L(messageKey), colorBad[1], colorBad[2], colorBad[3], true)
end

local function drawHotkeyVisual(action, x, y, textY)
	local label = Hotkeys.getDisplay(action)

	if label then
		lg.setColor(colorText)
		Text.printShadow(label, x, textY)

		return 14
	end

	return 0
end

-- Buttons
inspectButtons = {
	{
		id = "upgrade",
		x = 0,
		y = 0,
		w = 0,
		h = 0,
		canAfford = false,
		cost = nil,
		value = nil,
		anim = Button.newAnimation({errorT = 0}),
		onClick = function()
			local t = State.selectedTower

			if not t then
				return
			end

			local upgradeCost = Towers.getUpgradeCost(t)

			-- Only upgrade if affordable
			if upgradeCost and State.money >= upgradeCost then
				ModulePicker.openTowerUpgrade(t)
			else
				showUpgradeFailure(t, upgradeCost and "floater.needMoney" or "floater.maxLevel")
			end
		end,
	},

	{
		id = "sell",
		x = 0,
		y = 0,
		w = 0,
		h = 0,
		canAfford = true,
		cost = nil,
		value = nil,
		anim = Button.newAnimation({errorT = 0}),
		onClick = function()
			local t = State.selectedTower

			if t then
				Towers.sellTower(t)
			end
		end
	}
}

function Inspect.getButtons()
	return inspectButtons
end

-- Compact status rows. The caller controls the available row count, preventing
-- elaborate elite/boss combinations from entering the bottom action region.
local STATUS_ROW_H = 18
local STATUS_BAR_W = 54

local function drawStatusRow(status, x, y, w)
	local color = status.color or colorText
	lg.setColor(color)
	local label = status.icon .. " " .. status.label
	if status.stacks then label = label .. " x" .. status.stacks end
	Text.printShadow(label, x, y)
	if status.value then
		lg.setColor(ct1, ct2, ct3, 1)
		Text.printfShadow(status.value, x, y, w, "right")
	end
	if status.remainingFraction then
		local bx = x + w - STATUS_BAR_W
		local by = y + 13
		lg.setColor(0, 0, 0, 0.35)
		lg.rectangle("fill", bx, by, STATUS_BAR_W, 3, 2, 2)
		lg.setColor(color)
		lg.rectangle("fill", bx, by, STATUS_BAR_W * status.remainingFraction, 3, 2, 2)
	end
end

local forceShow = true

function Inspect.overrideAnimation(v)
	forceShow = v

	if v ~= false then
		inspectAnim = 1
	else
		inspectAnim = 0
	end
end

function Inspect.draw(x, y, w, h, dt, textH, now, mx, my)
	local hasInspect = State.selectedTower ~= nil or State.selectedEnemy ~= nil

	inspectTarget = hasInspect and 1 or 0

	-- Critically damped style snap
	local speed = 18

	--if not forceShow then
		inspectAnim = inspectAnim + (inspectTarget - inspectAnim) * min(1, dt * speed)
	--end

	-- Clamp to avoid micro drift
	if abs(inspectAnim - inspectTarget) < 0.001 then
		inspectAnim = inspectTarget
	end

	-- Slide from left
	local slide = (1 - inspectAnim) * 18

	-- Fade
	local alpha = inspectAnim

    local panelX = x + slide
    local panelY = y

	-- Outer outlined panel
	lg.setColor(colorOutline[1], colorOutline[2], colorOutline[3], alpha)
	lg.rectangle("fill", panelX - outlineW, panelY - outlineW, w + outlineW * 2, h + outlineW * 2, outerRadius)

	lg.setColor(colorBackdrop[1], colorBackdrop[2], colorBackdrop[3], alpha)
	lg.rectangle("fill", panelX, panelY, w, h, innerRadius)

    local infoX = panelX + OUTER_PAD
    local infoY = panelY + OUTER_PAD
    local infoW = w - OUTER_PAD * 2
    local infoH = 28

	lg.setColor(colorOutline[1], colorOutline[2], colorOutline[3], alpha)
	lg.rectangle("fill", infoX - outlineW, infoY - outlineW, infoW + outlineW * 2, infoH + outlineW * 2, outerSmallRadius)

	lg.setColor(Theme.ui.panel2[1], Theme.ui.panel2[2], Theme.ui.panel2[3], alpha)
	lg.rectangle("fill", infoX, infoY, infoW, infoH, innerSmallRadius)

    local titleX = infoX + PAD
    local titleY = infoY + floor((infoH - textH) * 0.5 + 0.5)

	local bodyX = panelX + OUTER_PAD
	local bodyY = infoY + infoH + PANEL_GAP

    lg.setColor(ct1, ct2, ct3, alpha)

    if State.selectedTower then
		local t = State.selectedTower

		-- Title
		Text.printShadow(L("inspect.towerTitle", L(t.def.nameKey), t.level), titleX, titleY)

		Text.printShadow(L("inspect.damage", formatInt(t.damageDealt)), bodyX, bodyY)

		Text.printShadow(L("inspect.kills", t.kills), bodyX, bodyY + STAT_LINE_H)

		-- Buttons layout
		local actionX = panelX + OUTER_PAD
		local usableW = w - OUTER_PAD * 2
		local BUTTON_W = floor((usableW - GAP) / 2)
		local actionY = panelY + h - OUTER_PAD - BUTTON_H

		local upgradeCost = Towers.getUpgradeCost(t)
		local canUpgrade = upgradeCost and State.money >= upgradeCost

		-- Configure upgrade button
		local upgradeBtn = inspectButtons[1]
		upgradeBtn.x = actionX
		upgradeBtn.y = actionY
		upgradeBtn.w = BUTTON_W
		upgradeBtn.h = BUTTON_H
		upgradeBtn.canAfford = canUpgrade
		upgradeBtn.cost = upgradeCost
		upgradeBtn.value = nil

		-- Configure sell button
		local sellBtn = inspectButtons[2]
		sellBtn.x = actionX + BUTTON_W + GAP
		sellBtn.y = actionY
		sellBtn.w = BUTTON_W
		sellBtn.h = BUTTON_H
		sellBtn.canAfford = true
		sellBtn.cost = nil
		sellBtn.value = t.sellValue
		-- Draw buttons
		for _, btn in ipairs(inspectButtons) do
			local bx, by = btn.x, btn.y
			if btn.anim and btn.anim.errorT and btn.anim.errorT > 0 then
				local shake = ((floor(btn.anim.errorT * 24) % 2 == 0) and 1 or -1) * 3 * btn.anim.errorT
				bx = bx + shake
			end
			local bw, bh = btn.w, btn.h

			local hovered = mx >= bx and mx <= bx + bw and my >= by and my <= by + bh

			local anim = btn.anim

			Button.updateAnimation(anim, hovered, dt)

			-- press animation
			if anim.errorT and anim.errorT > 0 then
				anim.errorT = max(0, anim.errorT - dt * 4)
			end

			local r, g, b = Button.getHoverColor(anim)

			local pressEase = anim.pressT
			local lift = IDLE_LIFT * (1 - pressEase)

			local faceR = r
			local faceG = g
			local faceB = b

			if not btn.canAfford then
				faceR, faceG, faceB = cd1, cd2, cd3
			end

			if anim.errorT and anim.errorT > 0 then
				local errorPulse = anim.errorT * anim.errorT
				faceR = faceR + (colorBad[1] - faceR) * errorPulse
				faceG = faceG + (colorBad[2] - faceG) * errorPulse
				faceB = faceB + (colorBad[3] - faceB) * errorPulse
			end

			-- Base
			lg.setColor(colorOutline)
			lg.rectangle("fill", bx - outlineW, by - outlineW, bw + outlineW * 2, bh + outlineW * 2, outerSmallRadius)

			lg.setColor(faceR * 0.4, faceG * 0.4, faceB * 0.4, 1)
			lg.rectangle("fill", bx, by, bw, bh, innerSmallRadius)

			-- Lifted face
			local fy = by - lift

			lg.setColor(colorOutline)
			lg.rectangle("fill", bx - outlineW, fy - outlineW, bw + outlineW * 2, bh + outlineW * 2, outerSmallRadius)

			lg.setColor(faceR, faceG, faceB, 1)
			lg.rectangle("fill", bx, fy, bw, bh, innerSmallRadius)

			local ty = fy + (bh - textH) * 0.5
			local action = btn.id
			local baseLabel = L("actions." .. action)

			local nameX = bx + PAD

			local used = drawHotkeyVisual(action, bx + PAD, fy, ty)

			if used > 0 then
				nameX = nameX + used
			end

			lg.setColor(ct1, ct2, ct3, btn.canAfford and 1 or 0.55)
			Text.printShadow(baseLabel, nameX, ty)

			if btn.cost then
				lg.setColor(btn.canAfford and colorGood or colorBad)
				Text.printfShadow("$" .. btn.cost, bx + PAD, ty, bw - PAD * 2, "right")
			elseif btn.value then
				lg.setColor(colorGood)
				Text.printfShadow("+$" .. btn.value, bx + PAD, ty, bw - PAD * 2, "right")
			end

			-- Upgrade tooltip
			if hovered and btn.id == "upgrade" and upgradeCost then
				local preview = Towers.getUpgradePreview(t)
				local rows = {}
				-- Preview rows are already fully derived by Towers from tower, branch,
				-- and module definitions; this layer only gives them a compact layout.
				for i = 1, math.min(#(preview and preview.rows or {}), 7) do
					local row = preview.rows[i]
					rows[#rows + 1] = {
						label = L(row.labelKey),
						value = row.current .. "  →",
						delta = row.next,
						deltaColor = row.direction == "bad" and colorBad or colorGood,
					}
				end

				Tooltip.show({
					title = L("inspect.upgradeTitle", t.level + 1),
					rows = rows,
				})
			end
		end
    elseif State.selectedEnemy then
        local e = State.selectedEnemy

        Text.printShadow(L(e.def.nameKey), titleX, titleY)

        Text.printShadow(L("inspect.hp", formatInt(e.hp), formatInt(e.maxHp)), bodyX, bodyY)

		local rows = {}
		local statuses = Enemies.getDisplayStatuses(e)
		if #statuses > 0 then
			rows[#rows + 1] = {header = L("inspect.temporaryStatuses")}
			for _, status in ipairs(statuses) do rows[#rows + 1] = {status = status} end
		end
		local traits = (e.def and e.def.traits) or {}
		if #traits > 0 or #(e.affixes or {}) > 0 then
			rows[#rows + 1] = {header = L("inspect.permanentTraits")}
			for _, traitId in ipairs(traits) do
				rows[#rows + 1] = {trait = "• " .. L("enemyTrait." .. traitId .. ".tag")}
			end
			for _, affix in ipairs(e.affixes or {}) do
				rows[#rows + 1] = {trait = affix.icon .. " " .. L(affix.nameKey), color = affix.color}
			end
		end

		local statusY = bodyY + 24
		local availableH = max(0, panelY + h - OUTER_PAD - statusY)
		local visibleRows = min(#rows, floor(availableH / STATUS_ROW_H))
		for i = 1, visibleRows do
			local row = rows[i]
			if row.header then
				lg.setColor(colorDisabled)
				Text.printShadow(row.header, bodyX, statusY)
			elseif row.status then
				drawStatusRow(row.status, bodyX, statusY, infoW)
			else
				lg.setColor(row.color or colorText)
				Text.printShadow(row.trait, bodyX + 4, statusY)
			end
			statusY = statusY + STATUS_ROW_H
		end
		if visibleRows < #rows and visibleRows > 0 then
			lg.setColor(colorDisabled)
			Text.printfShadow(L("inspect.moreStatuses", #rows - visibleRows), bodyX, statusY - STATUS_ROW_H, infoW, "right")
		end
    end
end

return Inspect
