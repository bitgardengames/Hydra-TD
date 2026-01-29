local Constants = require("core.constants")
local Cursor = require("core.cursor")
local Theme = require("core.theme")
local State = require("core.state")
local Enemies = require("world.enemies")
local Towers = require("world.towers")
local Waves = require("systems.waves")
local Hotkeys = require("core.hotkeys")
local Text = require("ui.text")
local L = require("core.localization")

local lg = love.graphics
local getTime = love.timer.getTime
local getDelta = love.timer.getDelta

local min = math.min
local max = math.max
local sin = math.sin
local abs = math.abs
local floor = math.floor
local tostring = tostring
local tinsert = table.insert

local colorText = Theme.ui.text
local colorGood = Theme.ui.good
local colorBad = Theme.ui.bad
local colorPanel = Theme.ui.panel
local colorPanel2 = Theme.ui.panel2
local colorSelected = Theme.ui.selected
local colorHovered = Theme.ui.hovered

local BottomBar = {}

local hudCache = {
	money = {value = nil, text = ""},
	lives = {value = nil, text = ""},
	wave = {value = nil, text = ""},
	prep = {value = nil, text = ""},
	spawn = {remaining = nil, count = nil, text = ""},
}

local bottomBarButtons = {}
local shopButtons = {}
local shopBumps = {}
local shopAnims = {}

local function ensureShopAnim(kind)
	if not shopAnims[kind] then
		shopAnims[kind] = {
			hovered = false,
			active = false,
			t = 0,
		}
	end

	return shopAnims[kind]
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function lerpColor(c1, c2, t)
	return {lerp(c1[1], c2[1], t), lerp(c1[2], c2[2], t), lerp(c1[3], c2[3], t), lerp(c1[4] or 1, c2[4] or 1, t)}
end

local function formatNum(n)
	return tostring(floor(n + 0.5)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

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

-- Spacing
local PAD = 8
local PAD2 = PAD * 2
local GAP = PAD

-- Content sizing
local SHOP_BTN_W = 124
local SHOP_BTN_H = 32
local SHOP_COLS = 3
local SHOP_CONTENT_W = (SHOP_BTN_W * SHOP_COLS) + (GAP * (SHOP_COLS - 1))
local SHOP_W = SHOP_CONTENT_W + PAD * 2
local INSPECT_W = 260 -- right panel content width (new: constrains total panel width)
local COL_W = 120
local HUD_H = 28 -- top strip height

local ACTION_W = 220 -- matches divider width
local BUTTON_W = (ACTION_W - GAP) / 2
local BUTTON_H = 28

-- Floating panel styling (new)
local PANEL_RADIUS = 12
local PANEL_LIFT = 12     -- lift from bottom of screen
local PANEL_INSET = 16    -- nudge right from left edge
local PANEL_PAD = 12      -- inner padding
--local PANEL_SHADOW = 4    -- soft drop shadow offset

function BottomBar.draw()
	local font = lg.getFont()
	local textH = font:getHeight()
	local sw, sh = love.graphics.getDimensions()

	local UI_H = Constants.UI_H

	-- Floating panel rect (new)
	local panelW = SHOP_W + INSPECT_W + (PANEL_PAD * 3) -- pad left + gap + pad right
	local panelH = UI_H
	local panelX = PANEL_INSET
	local panelY = sh - panelH - PANEL_LIFT

	-- Soft shadow (new)
	--lg.setColor(0, 0, 0, 0.25)
	--lg.rectangle("fill", panelX, panelY + PANEL_SHADOW, panelW, panelH, PANEL_RADIUS, PANEL_RADIUS)

	-- Panel background (new)
	lg.setColor(colorPanel)
	lg.rectangle("fill", panelX, panelY, panelW, panelH, PANEL_RADIUS, PANEL_RADIUS)

	-- Header strip (new)
	lg.setColor(colorPanel2)
	lg.rectangle("fill", panelX, panelY, panelW, HUD_H, PANEL_RADIUS, PANEL_RADIUS)

	-- Inner section backgrounds (keeps old “two panel” feeling, but inside the floating panel)
	local shopAreaX = panelX
	local shopAreaY = panelY + HUD_H
	local shopAreaW = PANEL_PAD + SHOP_W + PANEL_PAD
	local shopAreaH = panelH - HUD_H

	local inspectAreaX = panelX + PANEL_PAD + SHOP_W
	local inspectAreaY = panelY + HUD_H
	local inspectAreaW = panelW - shopAreaW
	local inspectAreaH = panelH - HUD_H

	local innerInset = PANEL_RADIUS * 0.75

	-- Shop inner panel
	lg.setColor(colorPanel)
	lg.rectangle("fill", shopAreaX + innerInset, shopAreaY + innerInset, shopAreaW - innerInset * 2, shopAreaH - innerInset * 2, 8, 8)

	-- Inspect inner panel
	lg.setColor(colorPanel)
	lg.rectangle("fill", inspectAreaX + innerInset, inspectAreaY + innerInset, inspectAreaW - innerInset * 2, inspectAreaH - innerInset * 2, 8, 8)

	-- Divider line between shop and inspect
	lg.setColor(1, 1, 1, 0.10)
	lg.line(inspectAreaX - 0.5, inspectAreaY + 8, inspectAreaX - 0.5, inspectAreaY + inspectAreaH - 8)

	-- Top HUD
	local y = panelY + floor((HUD_H - textH) * 0.5 + 0.5) + 1

	-- Animation math
	local livesAnim = State.livesAnim or 0
	local livesFlash = livesAnim
	local lp = 1 - (1 - livesAnim) * (1 - livesAnim)
	local livesDrop = floor(lp * 3 + 0.5)

	local waveAnim = State.waveAnim or 0
	local waveFlash = waveAnim
	local wp = 1 - (1 - waveAnim) * (1 - waveAnim)
	local waveLift = floor(wp * 3 + 0.5)

	State.moneyLerp = State.moneyLerp + (State.money - State.moneyLerp) * 0.25

	-- Money text
	lg.setColor(colorText)

	local moneyRounded = floor(State.moneyLerp + 0.5)
	local moneyCache = hudCache.money

	if moneyCache.value ~= moneyRounded then
		moneyCache.value = moneyRounded
		moneyCache.text = "$" .. formatNum(moneyRounded)
	end

	Text.printShadow(moneyCache.text, panelX + 12, y)

	-- Lives text
	local livesX = panelX + 90

	lg.setColor(1, 1 - livesFlash * 0.6, 1 - livesFlash * 0.6, 1)

	local livesCache = hudCache.lives

	if livesCache.value ~= State.lives then
		livesCache.value = State.lives
		livesCache.text = L("hud.lives", State.lives)
	end

	Text.printShadow(livesCache.text, livesX, y + livesDrop)

	-- Wave text
	local base = 0.85
	local boost = waveFlash * 0.25
	local waveColor = min(1, base + boost) -- Bass boosted wub wub

	lg.setColor(waveColor, waveColor, waveColor, 0.85)

	local waveCache = hudCache.wave

	if waveCache.value ~= State.wave then
		waveCache.value = State.wave
		waveCache.text = L("hud.wave", State.wave)
	end

	Text.printShadow(waveCache.text, panelX + 170, y - waveLift)

	if State.inPrep then
		local t = floor(State.prepTimer * 10 + 0.5) / 10
		local prepCache = hudCache.prep

		if prepCache.value ~= t then
			prepCache.value = t
			prepCache.text = L("hud.prep", t)
		end

		lg.setColor(colorGood)
		Text.printShadow(prepCache.text, panelX + 260, y)
	else
		local spawner = Waves.getSpawner()
		local spawnCache = hudCache.spawn
		local remaining = spawner.remaining
		local count = #Enemies.enemies

		if spawnCache.remaining ~= remaining or spawnCache.count ~= count then
			spawnCache.remaining = remaining
			spawnCache.count = count
			spawnCache.text = L("hud.spawning", remaining, count)
		end

		lg.setColor(0.85, 0.85, 0.85, 0.85)
		Text.printShadow(spawnCache.text, panelX + 260, y)
	end

	-- Tower shop (now panel-relative)
	local shopX = panelX + PANEL_PAD
	local shopY = panelY + HUD_H + PANEL_PAD

	local btnW = SHOP_BTN_W
	local btnH = SHOP_BTN_H
	local i = 0

	for i = #shopButtons, 1, -1 do
		shopButtons[i] = nil
	end

	for _, key in ipairs(Towers.shopOrder) do
		local def = Towers.TowerDefs[key]
		local hotkey = Hotkeys.getShopKey(key)

		local col = i % SHOP_COLS
		local row = floor(i / SHOP_COLS)

		local x = shopX + col * (btnW + GAP)
		local yb = shopY + row * (btnH + GAP)

		local selected = State.placing == key
		local canAfford = State.money >= def.cost
		local pulse = selected and (0.9 + sin(getTime() * 6) * 0.1) or 1

		shopButtons[#shopButtons + 1] = {
			kind = key,
			x = x,
			y = yb,
			w = btnW,
			h = btnH,
			canAfford = canAfford,
		}

		-- Detect transition: unaffordable -> affordable
		local bump = shopBumps[key]
		local bumpPad = 0

		if not bump then
			bump = {t = 0, active = false, wasAffordable = canAfford}
			shopBumps[key] = bump
		end

		-- Trigger bump
		if canAfford and not bump.wasAffordable then
			bump.t = 0
			bump.active = true
		end

		bump.wasAffordable = canAfford

		if bump.active then
			bump.t = bump.t + getDelta() * 8 -- speed

			if bump.t >= 1 then
				bump.t = 1
				bump.active = false
			end

			-- Ease out (quick expand, gentle settle)
			local p = bump.t
			local ease = p * p * (3 - 2 * p)

			bumpPad = ease * 1 -- 1px per edge
		end

		local mx, my = Cursor.x, Cursor.y
		local hovered = mx >= x and mx <= x + btnW and my >= yb and my <= yb + btnH

		local anim = ensureShopAnim(key)

		if hovered ~= anim.hovered then
			anim.active = true
		end

		anim.hovered = hovered

		if anim.active then
			local speed = getDelta() * 10

			if anim.hovered then
				anim.t = min(1, anim.t + speed)
			else
				anim.t = max(0, anim.t - speed)
			end

			if anim.t == 0 or anim.t == 1 then
				anim.active = false
			end
		end

		local ease = anim.t * anim.t * (3 - 2 * anim.t)
		local bg = lerpColor(colorPanel2, colorHovered, ease)

		lg.setColor(bg[1] * pulse, bg[2] * pulse, bg[3] * pulse, 1)
		lg.rectangle("fill", x - bumpPad, yb - bumpPad, btnW + bumpPad * 2, btnH + bumpPad * 2, 6 + bumpPad, 6 + bumpPad)

		-- Disabled overlay if unaffordable
		if not canAfford then
			lg.setColor(0, 0, 0, 0.35)
			lg.rectangle("fill", x, yb, btnW, btnH, 6, 6)
		end

		local ty = yb + (btnH - textH) * 0.5

		-- Name
		local towerName = L(def.nameKey)
		local textX = x + PAD
		local colorAfford = canAfford and colorText or colorBad

		if hotkey then
			-- Hotkey
			local hkText = "[" .. hotkey:upper() .. "] "

			lg.setColor(colorAfford[1], colorAfford[2], colorAfford[3], 0.85)
			Text.printShadow(hkText, textX, ty)

			-- Name
			local hkW = font:getWidth(hkText .. " ")

			lg.setColor(colorAfford)
			Text.printShadow(towerName, textX + hkW, ty)
		else
			-- Name only
			lg.setColor(colorAfford)
			Text.printShadow(towerName, textX, ty)
		end

		-- Cost
		lg.setColor(colorAfford)
		Text.printfShadow("$" .. def.cost, x + PAD, ty, btnW - PAD2, "right")

		i = i + 1
	end

	-- Inspect panel (now panel-relative)
	local inspectX = panelX + PANEL_PAD + SHOP_W + PANEL_PAD
	local inspectY = panelY + HUD_H + PANEL_PAD
	local rightColX = inspectX + COL_W + 32
	local statsY = inspectY + 18
	local lineH = 16
	local actionX = inspectX
	local actionY = statsY + lineH * 2 + 14
	local sellX = actionX + BUTTON_W + GAP

	-- Clear exposed buttons every frame
	bottomBarButtons.upgrade = nil
	bottomBarButtons.sell = nil

	if State.selectedTower then
		local t = State.selectedTower
		local towerName = L(t.def.nameKey)

		-- Name and level
		lg.setColor(colorText)
		Text.printShadow(L("inspect.towerTitle", towerName, t.level), inspectX, inspectY)

		-- Divider
		lg.setColor(1, 1, 1, 0.15)
		lg.line(inspectX, inspectY + 16, inspectX + 220, inspectY + 16)

		-- Stats
		lg.setColor(colorText)
		Text.printShadow(L("inspect.damage", formatNum(t.damageDealt)), inspectX, statsY)
		Text.printShadow(L("inspect.kills", t.kills), inspectX, statsY + lineH)

		-- Upgrade button
		local upgradeCost = Towers.towerUpgradeCost(t)
		local canUpgrade = State.money >= upgradeCost
		local upgradeKey = Hotkeys.getActionKey("upgrade")
		local tyBtn = actionY + (BUTTON_H - textH) * 0.5

		local mx, my = Cursor.x, Cursor.y
		local hoveredUpgrade = mx >= actionX and mx <= actionX + BUTTON_W and my >= actionY and my <= actionY + BUTTON_H

		local animU = ensureShopAnim("inspect_upgrade")

		if hoveredUpgrade ~= animU.hovered then
			animU.active = true
		end

		animU.hovered = hoveredUpgrade and canUpgrade

		if animU.active then
			local speed = getDelta() * 10

			if animU.hovered then
				animU.t = min(1, animU.t + speed)
			else
				animU.t = max(0, animU.t - speed)
			end

			if animU.t == 0 or animU.t == 1 then
				animU.active = false
			end
		end

		local easeU = animU.t * animU.t * (3 - 2 * animU.t)
		local bgU = lerpColor(colorPanel2, colorHovered, easeU)

		lg.setColor(bgU)
		lg.rectangle("fill", actionX, actionY, BUTTON_W, BUTTON_H, 6, 6)

		-- Disabled overlay
		if not canUpgrade then
			lg.setColor(0, 0, 0, 0.35)
			lg.rectangle("fill", actionX, actionY, BUTTON_W, BUTTON_H, 6, 6)
		end

		-- Text
		local ux = actionX + PAD
		local colorUpgrade = canUpgrade and colorText or colorBad

		if upgradeKey then
			local hkText = L("ui.hotkey", upgradeKey:upper())

			lg.setColor(colorUpgrade[1], colorUpgrade[2], colorUpgrade[3], 0.85)
			Text.printShadow(hkText, ux, tyBtn)

			local hkW = font:getWidth(hkText .. " ")
			lg.setColor(colorUpgrade)
			Text.printShadow(L("actions.upgrade"), ux + hkW, tyBtn)
		else
			lg.setColor(colorUpgrade)
			Text.printShadow(L("actions.upgrade"), ux, tyBtn)
		end

		lg.setColor(colorUpgrade)
		Text.printfShadow("$" .. upgradeCost, actionX + PAD, tyBtn, BUTTON_W - PAD2, "right")

		if canUpgrade then
			bottomBarButtons.upgrade = {x = actionX, y = actionY, w = BUTTON_W, h = BUTTON_H}
		end

		-- Sell button
		local sellKey = Hotkeys.getActionKey("sell")
		local sellValue = t.sellValue or 0

		local hoveredSell =
			mx >= sellX and mx <= sellX + BUTTON_W and
			my >= actionY and my <= actionY + BUTTON_H

		local animS = ensureShopAnim("inspect_sell")

		if hoveredSell ~= animS.hovered then
			animS.active = true
		end

		animS.hovered = hoveredSell

		if animS.active then
			local speed = getDelta() * 10

			if animS.hovered then
				animS.t = min(1, animS.t + speed)
			else
				animS.t = max(0, animS.t - speed)
			end

			if animS.t == 0 or animS.t == 1 then
				animS.active = false
			end
		end

		local easeS = animS.t * animS.t * (3 - 2 * animS.t)
		local bgS = lerpColor(colorPanel2, colorHovered, easeS)

		lg.setColor(bgS)
		lg.rectangle("fill", sellX, actionY, BUTTON_W, BUTTON_H, 6, 6)

		-- Text
		local sx = sellX + PAD

		if sellKey then
			local hkText = "[" .. sellKey:upper() .. "] "

			lg.setColor(colorGood[1], colorGood[2], colorGood[3], 0.85)
			Text.printShadow(hkText, sx, tyBtn)

			local hkW = font:getWidth(hkText .. " ")
			lg.setColor(colorGood)
			Text.printShadow(L("actions.sell"), sx + hkW, tyBtn)
		else
			lg.setColor(colorGood)
			Text.printShadow(L("actions.sell"), sx, tyBtn)
		end

		lg.setColor(colorGood)
		Text.printfShadow("+$" .. sellValue, sellX + PAD, tyBtn, BUTTON_W - PAD2, "right")

		bottomBarButtons.sell = {x = sellX, y = actionY, w = BUTTON_W, h = BUTTON_H}
	elseif State.selectedEnemy then
		local e = State.selectedEnemy

		local hpY = inspectY + 18

		-- Name
		lg.setColor(colorText)
		Text.printShadow(L(e.def.nameKey), inspectX, inspectY)

		-- Divider
		lg.setColor(1, 1, 1, 0.15)
		lg.line(inspectX, inspectY + 16, inspectX + 220, inspectY + 16)

		lg.setColor(colorText)
		Text.printShadow(L("inspect.hp", formatNum(e.hp), formatNum(e.maxHp)), inspectX, hpY)

		-- Status effects
		local statusY = hpY + 16

		if e.slowTimer and e.slowTimer > 0 then
			drawStatusBar(L("status.slow"), Theme.tower.slow, e.slowTimer, e.slowDuration, inspectX, statusY)
			statusY = statusY + 16
		end

		if e.poisonStacks and e.poisonStacks > 0 then
			drawStatusBar(L("status.poison"), Theme.tower.poison, e.poisonTimer, e.poisonDuration, inspectX, statusY)
			statusY = statusY + 16
		end

		-- Modifiers (resistances / vulnerabilities)
		if e.modifiers then
			local modLines = {}
			local slowLine = formatModifier(L("status.slow"), e.modifiers.slow, L("modifier.effect"))
			local poisonLine = formatModifier(L("status.poison"), e.modifiers.poison, L("modifier.damage"))

			if slowLine then
				tinsert(modLines, slowLine)
			end

			if poisonLine then
				tinsert(modLines, poisonLine)
			end

			lg.setColor(colorText)

			if #modLines > 0 then
				Text.printShadow(L("inspect.modifiers"), rightColX, hpY)

				for i, line in ipairs(modLines) do
					Text.printShadow(line, rightColX, hpY + i * 16)
				end
			end
		end
	end
end

function BottomBar.getShopButtons()
	return shopButtons
end

function BottomBar.getBottomBarButtons()
	return bottomBarButtons
end

return BottomBar