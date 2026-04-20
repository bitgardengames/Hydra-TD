local State = require("core.state")
local Util = require("core.util")
local Towers = require("world.towers")
local Modules = require("systems.modules")
local ModulePicker = require("ui.module_picker")
local Hotkeys = require("core.hotkeys")
local Glyphs = require("ui.glyphs")
local Tooltip = require("ui.tooltip")
local Text = require("ui.text")
local Theme = require("core.theme")
local L = require("core.localization")

local Inspect = {}

local lg = love.graphics
local min = math.min
local max = math.max
local abs = math.abs
local floor = math.floor
local format = string.format

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
local colorButton = Theme.ui.button
local colorButtonHover = Theme.ui.buttonHover
local colorSlow = Theme.tower.slow
local colorPoison = Theme.tower.poison

local ct1, ct2, ct3 = colorText[1], colorText[2], colorText[3]
local cb1, cb2, cb3 = colorButton[1], colorButton[2], colorButton[3]
local ch1, ch2, ch3 = colorButtonHover[1], colorButtonHover[2], colorButtonHover[3]
local cs1, cs2, cs3 = colorSlow[1], colorSlow[2], colorSlow[3]
local cp1, cp2, cp3 = colorPoison[1], colorPoison[2], colorPoison[3]
local cd1, cd2, cd3 = colorDisabled[1], colorDisabled[2], colorDisabled[3]

local cbd1 = ch1 - cb1
local cbd2 = ch2 - cb2
local cbd3 = ch3 - cb3

-- Layout constants local to inspect
local OUTER_PAD = 12
local PANEL_GAP = 10
local PAD = 8
local BUTTON_H = 32
local GAP = 16
local IDLE_LIFT = 6
local GLYPH_X_OFFSET = -5
local STAT_LINE_H = 22

local idleLift = 6

local outlineW = Theme.outline.width
local baseRadius = 6 * 3
local outerRadius = baseRadius + outlineW * 0.5
local innerRadius = baseRadius - outlineW * 0.25

local outerSmallRadius = 6 + outlineW * 0.5
local innerSmallRadius = 6 - outlineW * 0.25

local function drawHotkeyVisual(action, x, y, textY)
	local glyph = Hotkeys.getGlyph(action)

	if glyph then
		local gw = Glyphs.getSize(glyph, 1)
		Glyphs.draw(glyph, x + GLYPH_X_OFFSET, textY - 1)

		return gw - 10
	end

	local label = Hotkeys.getDisplay(action)

	if label then
		lg.setColor(colorText)
		Text.printShadow(label, x, textY)

		return 14
	end

	return 0
end

-- Buttons
local inspectButtons = {
	{
		id = "upgrade",
		x = 0,
		y = 0,
		w = 0,
		h = 0,
		canAfford = false,
		cost = nil,
		value = nil,
		anim = {hovered = false, active = false, t = 0, pressed = false, pressT = 0},
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
				-- optional error sound / floater
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
		anim = {hovered = false, active = false, t = 0, pressed = false, pressT = 0},
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

-- Status effects
local BAR_W = 120
local BAR_H = 12
local STATUS_GAP = 12

local function drawStatusBar(r, g, b, timer, duration, x, y, now)
	if not timer or timer <= 0 then
		return 0
	end

	if not duration or duration <= 0 then
		return 0
	end

	local pct = timer / duration

	if pct < 0 then pct = 0 end
	if pct > 1 then pct = 1 end

	-- Background
	lg.setColor(0, 0, 0, 0.35)
	lg.rectangle("fill", x, y, BAR_W, BAR_H, 4, 4)

	-- Fill width
	local fillW = BAR_W * pct

	if fillW > 0 then
		local minW = 4
		local visibleW = max(fillW, minW)

		-- Fade near zero instead of collapsing
		local alphaScale = 1

		if pct < 0.10 then
			alphaScale = pct / 0.10
		end

		local radius = min(4, visibleW * 0.5, BAR_H * 0.5)

		lg.setColor(r, g, b, alphaScale)
		lg.rectangle("fill", x, y, visibleW, BAR_H, radius, radius)
	end

	-- Timer (right of bar)
	lg.setColor(ct1, ct2, ct3, 1)
	Text.printShadow(L("ui.seconds", timer), x + BAR_W + 8, y - 2)

	return BAR_H + STATUS_GAP
end

local function formatStat(value)
	if not value then
		return value
	end

	-- Round to 1 decimal
	local rounded = floor(value * 10 + 0.5) / 10

	-- If effectively whole number, return integer string
	if abs(rounded - floor(rounded)) < 0.001 then
		return tostring(floor(rounded))
	end

	return format("%.1f", rounded)
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
		local BUTTON_W = floor((usableW - GAP) * 0.5)
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
			local bw, bh = btn.w, btn.h

			local hovered = mx >= bx and mx <= bx + bw and my >= by and my <= by + bh

			local anim = btn.anim

			if hovered ~= anim.hovered then
				anim.active = true
			end

			anim.hovered = hovered

			if anim.active then
				local speed = dt * 10

				if anim.hovered then
					anim.t = min(1, anim.t + speed)
				else
					anim.t = max(0, anim.t - speed)
				end

				if anim.t == 0 or anim.t == 1 then
					anim.active = false
				end
			end

			-- press animation
			if anim.pressed then
				anim.pressT = min(1, anim.pressT + dt * 20)
			else
				anim.pressT = max(0, anim.pressT - dt * 20)
			end

			local ease = anim.t * anim.t * (3 - 2 * anim.t)

			local r = cb1 + cbd1 * ease
			local g = cb2 + cbd2 * ease
			local b = cb3 + cbd3 * ease

			local pressEase = anim.pressT
			local lift = IDLE_LIFT * (1 - pressEase)

			local faceR = r
			local faceG = g
			local faceB = b

			if not btn.canAfford then
				faceR, faceG, faceB = cd1, cd2, cd3
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
				local specName = nil
				if t.specializationId then
					local mod = Modules.getDef(t.specializationId)
					specName = mod and L(mod.nameKey) or nil
				end

				Tooltip.show({
					title = L("inspect.upgradeTitle", t.level + 1),
					text = specName and L("modulePicker.currentSpec", specName) or L("modulePicker.noSpec"),
				})
			end
		end
    elseif State.selectedEnemy then
        local e = State.selectedEnemy

        Text.printShadow(L(e.def.nameKey), titleX, titleY)

        Text.printShadow(L("inspect.hp", formatInt(e.hp), formatInt(e.maxHp)), bodyX, bodyY)

		local statusY = bodyY + 24

		-- Slow
		if e.slowTimer > 0 and e.slowDuration > 0 then
			statusY = statusY + drawStatusBar(cs1, cs2, cs3, e.slowTimer, e.slowDuration, bodyX, statusY, now)
		end

		-- Poison
		if e.poisonTimer > 0 and e.poisonDuration > 0 then
			statusY = statusY + drawStatusBar(cp1, cp2, cp3, e.poisonTimer, e.poisonDuration, bodyX, statusY, now)
		end
    end
end

return Inspect
