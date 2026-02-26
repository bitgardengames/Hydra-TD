local State = require("core.state")
local Util = require("core.util")
local Towers = require("world.towers")
local Hotkeys = require("core.hotkeys")
local Tooltip = require("ui.tooltip")
local Text = require("ui.text")
local Theme = require("core.theme")
local L = require("core.localization")

local Inspect = {}

local lg = love.graphics
local min = math.min
local max = math.max
local sin = math.sin
local abs = math.abs
local floor = math.floor

local formatInt = Util.formatInt

-- Animation state
local inspectAnim = 0
local inspectTarget = 0

-- Colors
local colorPanel = Theme.ui.panel
local colorPanel2 = Theme.ui.panel2
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
local panel1, panel2, panel3 = colorPanel[1], colorPanel[2], colorPanel[3]
local paneldark1, paneldark2, paneldark3 = colorPanel2[1], colorPanel2[2], colorPanel2[3]

local cbd1 = ch1 - cb1
local cbd2 = ch2 - cb2
local cbd3 = ch3 - cb3

-- Layout constants local to inspect
local OUTER_PAD = 10
local PANEL_GAP = 10
local OUTER_R = 12
local INNER_R = 8
local PAD = 8
local BUTTON_H = 28
local ACTION_W = 240
local GAP = 8
local BUTTON_W = (ACTION_W - GAP) / 2

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
		onClick = function()
			local t = State.selectedTower

			if not t then
				return
			end

			local upgradeCost = Towers.getUpgradeCost(t)

			-- Only upgrade if affordable
			if upgradeCost and State.money >= upgradeCost then
				Towers.upgradeTower(t)
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
local STATUS_GAP = 10

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

local function formatModifier(label, value, suffix)
	if not value or value == 1 then
		return nil
	end

	local delta = (value - 1) * 100
	local sign = delta > 0 and "+" or "-"
	local pct = abs(floor(delta + 0.5))

	return ("%s%d%% %s %s"):format(sign, pct, label, suffix)
end

function Inspect.draw(x, y, w, h, dt, textH, now, mx, my)
	local hasInspect = State.selectedTower ~= nil or State.selectedEnemy ~= nil

	inspectTarget = hasInspect and 1 or 0

	-- Critically damped style snap
	local speed = 18
	inspectAnim = inspectAnim + (inspectTarget - inspectAnim) * min(1, dt * speed)

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

    lg.setColor(panel1, panel2, panel3, alpha)
    lg.rectangle("fill", panelX, panelY, w, h, OUTER_R, OUTER_R)

    local infoX = panelX + OUTER_PAD
    local infoY = panelY + OUTER_PAD
    local infoW = w - OUTER_PAD * 2
    local infoH = 28

    lg.setColor(paneldark1, paneldark2, paneldark3, alpha)
    lg.rectangle("fill", infoX, infoY, infoW, infoH, INNER_R, INNER_R)

    local contentX = panelX + OUTER_PAD
    local contentY = infoY + infoH + PANEL_GAP
    local contentW = w - OUTER_PAD * 2
    local contentH = h - (contentY - panelY) - OUTER_PAD

    lg.setColor(paneldark1, paneldark2, paneldark3, alpha)
    lg.rectangle("fill", contentX, contentY, contentW, contentH, INNER_R, INNER_R)

    local titleX = infoX + PAD
    local titleY = infoY + floor((infoH - textH) * 0.5 + 0.5)

    local bodyX = contentX + PAD
    local bodyY = contentY + PAD

    lg.setColor(ct1, ct2, ct3, alpha)

    if State.selectedTower then
		local t = State.selectedTower

		-- Title
		Text.printShadow(L("inspect.towerTitle", L(t.def.nameKey), t.level), titleX, titleY)

		Text.printShadow(L("inspect.damage", formatInt(t.damageDealt)), bodyX, bodyY)

		Text.printShadow(L("inspect.kills", t.kills), bodyX, bodyY + 16)

		-- Buttons layout
		local actionY = contentY + contentH - BUTTON_H - PAD
		local actionX = contentX + PAD

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

			local ease = hovered and 1 or 0

			local r = cb1 + cbd1 * ease
			local g = cb2 + cbd2 * ease
			local b = cb3 + cbd3 * ease

			lg.setColor(r, g, b, 1)
			lg.rectangle("fill", bx, by, bw, bh, 6, 6)

			if not btn.canAfford then
				lg.setColor(colorDisabled)
				lg.rectangle("fill", bx, by, bw, bh, 6, 6)
			end

			local ty = by + (bh - textH) * 0.5
			local label = btn.id == "upgrade" and L("actions.upgrade") or L("actions.sell")

			lg.setColor(ct1, ct2, ct3, btn.canAfford and 1 or 0.55)
			Text.printShadow(label, bx + PAD, ty)

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

				if preview then
					Tooltip.show{
						title = L("inspect.upgradeTitle", t.level + 1),
						rows = {
							{
								label = L("stats.damage"),
								value = t.damage,
								delta = "+" .. (preview.damage - t.damage),
							},

							{
								label = L("stats.fireRate"),
								value = t.fireRate,
								delta = "+" .. (preview.fireRate - t.fireRate),
							},

							{
								label = L("stats.range"),
								value = t.range,
								delta = "+" .. (preview.range - t.range),
							},
						}
					}
				end
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