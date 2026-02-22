local State = require("core.state")
local Util = require("core.util")
local Towers = require("world.towers")
local Hotkeys = require("core.hotkeys")
local Tooltip = require("ui.tooltip")
local Text = require("ui.text")
local Theme = require("core.theme")
local L = require("core.localization")

local lg = love.graphics
local min = math.min
local max = math.max
local sin = math.sin
local abs = math.abs
local floor = math.floor

local Inspect = {}

local inspectButtons = {
    {
        id = "upgrade",
        x = 0, y = 0, w = 0, h = 0,
        canAfford = false,
        cost = nil,
        value = nil,
    },
    {
        id = "sell",
        x = 0, y = 0, w = 0, h = 0,
        canAfford = true,
        cost = nil,
        value = nil,
    }
}

function Inspect.getButtons()
    return inspectButtons
end

local formatInt = Util.formatInt

-- Internal animation state stays inside module
local inspectAnim = 0

-- Colors cached locally (no upvalue explosion)
local colorPanel = Theme.ui.panel
local colorPanel2 = Theme.ui.panel2
local colorText = Theme.ui.text
local colorGood = Theme.ui.good
local colorBad = Theme.ui.bad
local colorDisabled = Theme.ui.buttonDisabled
local colorButton = Theme.ui.button
local colorButtonHover = Theme.ui.buttonHover

local ct1, ct2, ct3 = colorText[1], colorText[2], colorText[3]
local cb1, cb2, cb3 = colorButton[1], colorButton[2], colorButton[3]
local ch1, ch2, ch3 = colorButtonHover[1], colorButtonHover[2], colorButtonHover[3]

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

local BAR_W = 64
local BAR_H = 8
local LABEL_W = 44

local function drawStatusBar(label, color, timeLeft, duration, x, y)
	if not timeLeft or timeLeft <= 0 then
		return
	end

	if not duration or duration <= 0 then
		return
	end

	local t = max(0, min(1, timeLeft / duration))

	-- Subtle pulse near expiration
	local pulse = 1

	if t < 0.25 then
		pulse = 0.85 + sin(getTime() * 10) * 0.15
	end

	-- Label
	lg.setColor(colorText)
	Text.printShadow(label, x, y)

	-- Bar background
	lg.setColor(0, 0, 0, 0.35)
	lg.rectangle("fill", x + LABEL_W, y + 4, BAR_W, BAR_H, 4, 4)

	-- Bar fill
	lg.setColor(color[1] * pulse, color[2] * pulse, color[3] * pulse, 1)
	lg.rectangle("fill", x + LABEL_W, y + 4, BAR_W * t, BAR_H, 4, 4)

	-- Timer
	lg.setColor(1, 1, 1, 0.85)
	Text.printShadow(L("ui.seconds", timeLeft), x + LABEL_W + BAR_W + 6, y)
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

    if not hasInspect then
        inspectAnim = inspectAnim + (0 - inspectAnim) * dt * 10

        return
    end

    inspectAnim = inspectAnim + (1 - inspectAnim) * dt * 10
    local slide = (1 - inspectAnim) * 16

    local panelX = x + slide
    local panelY = y

    lg.setColor(colorPanel)
    lg.rectangle("fill", panelX, panelY, w, h, OUTER_R, OUTER_R)

    local infoX = panelX + OUTER_PAD
    local infoY = panelY + OUTER_PAD
    local infoW = w - OUTER_PAD * 2
    local infoH = 28

    lg.setColor(colorPanel2)
    lg.rectangle("fill", infoX, infoY, infoW, infoH, INNER_R, INNER_R)

    local contentX = panelX + OUTER_PAD
    local contentY = infoY + infoH + PANEL_GAP
    local contentW = w - OUTER_PAD * 2
    local contentH = h - (contentY - panelY) - OUTER_PAD

    lg.setColor(colorPanel2)
    lg.rectangle("fill", contentX, contentY, contentW, contentH, INNER_R, INNER_R)

    local titleX = infoX + PAD
    local titleY = infoY + floor((infoH - textH) * 0.5 + 0.5)

    local bodyX = contentX + PAD
    local bodyY = contentY + PAD

    lg.setColor(ct1, ct2, ct3, 1)

    if State.selectedTower then
		local t = State.selectedTower

		-- Title
		Text.printShadow(L("inspect.towerTitle", L(t.def.nameKey), t.level), titleX, titleY)

		Text.printShadow(L("inspect.damage", formatInt(t.damageDealt)), bodyX, bodyY)

		Text.printShadow(L("inspect.kills", t.kills), bodyX, bodyY + 16)

		-- Buttons layout
		local actionY = contentY + contentH - BUTTON_H - PAD
		local actionX = contentX + PAD

		local upgradeCost = Towers.towerUpgradeCost(t)
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
    end
end

return Inspect