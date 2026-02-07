local Constants = require("core.constants")
local Cursor = require("core.cursor")
local Theme = require("core.theme")
local State = require("core.state")
local Enemies = require("world.enemies")
local Towers = require("world.towers")
local Waves = require("systems.waves")
local Hotkeys = require("core.hotkeys")
local Glyphs = require("ui.glyphs")
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
local colorButton = Theme.ui.button
local colorButtonHover = Theme.ui.buttonHover
local colorDisabled = Theme.ui.buttonDisabled
local colorMoney = Theme.ui.money
local colorLives = Theme.ui.lives
local colorWave = Theme.ui.wave

local BottomBar = {}

local hudCache = {
	money = {value = nil, text = ""},
	lives = {value = nil, text = ""},
	wave = {value = nil, text = ""},
	prep = {value = nil, text = "", action = nil},
	spawn = {remaining = nil, count = nil, text = ""},
}

local inspectButtons = {}
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

local inspectAnim = 0

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

local GLYPH_X_OFFSET = -5

local function drawHotkeyVisual(action, x, y, textY)
	-- Try glyph first (controller mode)
	local glyph = Hotkeys.getGlyph(action)

	if glyph then
		local gw, gh = Glyphs.getSize(glyph, 1)

		-- Vertically center glyph against text baseline
		Glyphs.draw(glyph, x + GLYPH_X_OFFSET, textY - 1)

		return gw - 10
	end

	-- Fallback to text
	local label = Hotkeys.getDisplay(action)

	if label then
		lg.setColor(colorText)
		Text.printShadow(label, x, textY)

		-- Match the spacing you already assume elsewhere
		return 14
	end

	return 0
end

-- Spacing
local PAD = 8
local PAD2 = PAD * 2
local GAP = PAD

-- Content sizing
local UI_H = Constants.UI_H
local SHOP_BTN_W = 124
local SHOP_BTN_H = 32
local SHOP_COLS = 3
local SHOP_CONTENT_W = (SHOP_BTN_W * SHOP_COLS) + (GAP * (SHOP_COLS - 1))
local SHOP_W = SHOP_CONTENT_W + PAD * 2
local INSPECT_W = 260 -- right panel content width
local COL_W = 120
local HUD_H = 28 -- top strip height

local ACTION_W = 240
local BUTTON_W = (ACTION_W - GAP) / 2
local BUTTON_H = 28

-- Floating panel styling
local PANEL_LIFT = 12 -- lift from bottom of screen
local PANEL_INSET = 12 -- nudge right from left edge

function BottomBar.draw()
	local font = lg.getFont()
	local textH = font:getHeight()
	local sw, sh = lg.getDimensions()
	local hasInspect = State.selectedTower ~= nil or State.selectedEnemy ~= nil

	-- Panel layout
	local OUTER_PAD = 10
	local PANEL_GAP = 10
	local OUTER_R = 12
	local INNER_R = 8

	local INFO_H = HUD_H
	local SHOP_PANEL_W = SHOP_W
	local INSPECT_PANEL_W = INSPECT_W + PAD * 2

	local baseW = OUTER_PAD * 2 + SHOP_PANEL_W
	local outerW = baseW
	local outerH = UI_H
	local outerX = PANEL_INSET
	local outerY = sh - outerH - PANEL_LIFT

	-- Outer backdrop
	lg.setColor(colorPanel)
	lg.rectangle("fill", outerX, outerY, outerW, outerH, OUTER_R, OUTER_R)

	-- Info panel
	local infoX = outerX + OUTER_PAD
	local infoY = outerY + OUTER_PAD
	local infoW = outerW - OUTER_PAD * 2
	local infoH = INFO_H

	lg.setColor(colorPanel2)
	lg.rectangle("fill", infoX, infoY, infoW, infoH, INNER_R, INNER_R)

	-- Shop panel
	local shopPanelX = outerX + OUTER_PAD
	local shopPanelY = infoY + infoH + PANEL_GAP
	local shopPanelW = SHOP_PANEL_W
	local shopPanelH = outerH - (shopPanelY - outerY) - OUTER_PAD

	lg.setColor(colorPanel2)
	lg.rectangle("fill", shopPanelX, shopPanelY, shopPanelW, shopPanelH, INNER_R, INNER_R)

	-- Info strip content
	local y = infoY + floor((INFO_H - textH) * 0.5 + 0.5)

	State.moneyLerp = State.moneyLerp + (State.money - State.moneyLerp) * 0.25
	local moneyRounded = floor(State.moneyLerp + 0.5)
	local moneyCache = hudCache.money

	if moneyCache.value ~= moneyRounded then
		moneyCache.value = moneyRounded
		moneyCache.text = "$" .. formatNum(moneyRounded)
	end

	lg.setColor(colorMoney)
	Text.printShadow(moneyCache.text, infoX + 12, y)

	local livesCache = hudCache.lives

	if livesCache.value ~= State.lives then
		livesCache.value = State.lives
		livesCache.text = L("hud.lives", State.lives)
	end

	lg.setColor(colorLives)
	Text.printShadow(livesCache.text, infoX + 90, y)

	local waveCache = hudCache.wave

	if waveCache.value ~= State.wave then
		waveCache.value = State.wave
		waveCache.text = L("hud.wave", State.wave)
	end

	lg.setColor(colorText)
	Text.printShadow(waveCache.text, infoX + 170, y)

	if State.inPrep then
		local t = floor(State.prepTimer * 10 + 0.5) / 10
		local prepCache = hudCache.prep
		local skipKey = Hotkeys.getDisplay("skipPrep")

		if prepCache.value ~= t or prepCache.action ~= skipKey then
			prepCache.value = t
			prepCache.action = skipKey
			prepCache.text = L("hud.prep", t, skipKey)
		end

		lg.setColor(colorGood)
		Text.printShadow(prepCache.text, infoX + 260, y)
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
		Text.printShadow(spawnCache.text, infoX + 260, y)
	end

	-- Shop content
	local shopX = shopPanelX + PAD
	local shopY = shopPanelY + PAD

	for i = #shopButtons, 1, -1 do
		shopButtons[i] = nil
	end

	local i = 0

	for _, key in ipairs(Towers.shopOrder) do
		local def = Towers.TowerDefs[key]
		local hotkeyLabel = Hotkeys.getDisplay(key)

		local col = i % SHOP_COLS
		local row = floor(i / SHOP_COLS)

		local x = shopX + col * (SHOP_BTN_W + GAP)
		local yb = shopY + row * (SHOP_BTN_H + GAP)

		local selected = State.placing == key
		local canAfford = State.money >= def.cost
		local pulse = selected and (0.9 + sin(getTime() * 6) * 0.1) or 1

		shopButtons[#shopButtons + 1] = {
			kind = key,
			x = x,
			y = yb,
			w = SHOP_BTN_W,
			h = SHOP_BTN_H,
			canAfford = canAfford,
		}

		local bump = shopBumps[key]
		local bumpPad = 0

		if not bump then
			bump = {t = 0, active = false, wasAffordable = canAfford}
			shopBumps[key] = bump
		end

		if canAfford and not bump.wasAffordable then
			bump.t = 0
			bump.active = true
		end

		bump.wasAffordable = canAfford

		if bump.active then
			bump.t = bump.t + getDelta() * 8

			if bump.t >= 1 then
				bump.t = 1
				bump.active = false
			end

			local p = bump.t
			local ease = p * p * (3 - 2 * p)

			bumpPad = ease
		end

		local mx, my = Cursor.x, Cursor.y
		local hovered = mx >= x and mx <= x + SHOP_BTN_W and my >= yb and my <= yb + SHOP_BTN_H

		local anim = ensureShopAnim(key)

		if hovered ~= anim.hovered then
			anim.active = true
		end

		anim.hovered = hovered

		if anim.active then
			local speed = getDelta() * 10

			anim.t = hovered and min(1, anim.t + speed) or max(0, anim.t - speed)

			if anim.t == 0 or anim.t == 1 then
				anim.active = false
			end
		end

		local ease = anim.t * anim.t * (3 - 2 * anim.t)
		local bg = lerpColor(colorButton, colorButtonHover, ease)

		lg.setColor(bg[1] * pulse, bg[2] * pulse, bg[3] * pulse, 1)
		lg.rectangle("fill", x - bumpPad, yb - bumpPad, SHOP_BTN_W + bumpPad * 2, SHOP_BTN_H + bumpPad * 2, 6, 6)

		if not canAfford then
			lg.setColor(colorDisabled)
			lg.rectangle("fill", x, yb, SHOP_BTN_W, SHOP_BTN_H, 6, 6)
		end

		local HOTKEY_PAD = 14
		local nameX = x + PAD

		local ty = yb + (SHOP_BTN_H - textH) * 0.5
		local colorAfford = canAfford and colorText or colorBad
		local nameAlpha = canAfford and 1 or 0.55

		if hotkeyLabel then
			local used = drawHotkeyVisual(key, x + PAD + GLYPH_X_OFFSET, yb, ty)

			nameX = nameX + used
		end

		lg.setColor(colorText[1], colorText[2], colorText[3], nameAlpha)
		Text.printShadow(L(def.nameKey), nameX, ty)

		lg.setColor(colorAfford)
		Text.printfShadow("$" .. def.cost, x + PAD, ty, SHOP_BTN_W - PAD2, "right")

		i = i + 1
	end

	if hasInspect then
		inspectAnim = inspectAnim + ((hasInspect and 1 or 0) - inspectAnim) * getDelta() * 10
		local slide = (1 - inspectAnim) * 16

		--local inspectPanelX = outerX + outerW + PANEL_GAP
		local inspectPanelX = outerX + outerW + PANEL_GAP + slide
		local inspectPanelY = outerY
		local inspectPanelW = INSPECT_PANEL_W
		local inspectPanelH = outerH

		-- Outer panel
		lg.setColor(colorPanel)
		lg.rectangle("fill", inspectPanelX, inspectPanelY, inspectPanelW, inspectPanelH, OUTER_R, OUTER_R)

		-- Inspect top strip
		local inspectInfoX = inspectPanelX + OUTER_PAD
		local inspectInfoY = inspectPanelY + OUTER_PAD
		local inspectInfoW = inspectPanelW - OUTER_PAD * 2
		local inspectInfoH = HUD_H

		lg.setColor(colorPanel2)
		lg.rectangle("fill", inspectInfoX, inspectInfoY, inspectInfoW, inspectInfoH, INNER_R, INNER_R)

		-- Inspect content panel
		local inspectContentX = inspectPanelX + OUTER_PAD
		local inspectContentY = inspectInfoY + inspectInfoH + PANEL_GAP
		local inspectContentW = inspectPanelW - OUTER_PAD * 2
		local inspectContentH = shopPanelH

		lg.setColor(colorPanel2)
		lg.rectangle("fill", inspectContentX, inspectContentY, inspectContentW, inspectContentH, INNER_R, INNER_R)

		-- Inspect text anchors
		local inspectTitleX = inspectInfoX + PAD
		local inspectTitleY = inspectInfoY + floor((inspectInfoH - textH) * 0.5 + 0.5)

		local inspectBodyX = inspectContentX + PAD
		local inspectBodyY = inspectContentY + PAD - 1

		local lineH = 16

		lg.setColor(colorText)

		if State.selectedTower then
			for i = #inspectButtons, 1, -1 do
				inspectButtons[i] = nil
			end

			local t = State.selectedTower

			-- Title (top strip)
			Text.printShadow(L("inspect.towerTitle", L(t.def.nameKey), t.level), inspectTitleX, inspectTitleY)

			-- Body
			Text.printShadow(L("inspect.damage", formatNum(t.damageDealt)), inspectBodyX, inspectBodyY)

			Text.printShadow(L("inspect.kills", t.kills), inspectBodyX, inspectBodyY + 16)

			-- Action buttons (upgrade / sell)
			local actionY = inspectContentY + inspectContentH - BUTTON_H - PAD
			local actionX = inspectContentX + PAD

			-- Upgrade cost
			local upgradeCost = Towers.towerUpgradeCost(t)
			local canUpgrade = upgradeCost and State.money >= upgradeCost

			-- Sell value
			local sellValue = t.sellValue

			-- Upgrade button
			inspectButtons[#inspectButtons + 1] = {
				id = "upgrade",
				x = actionX,
				y = actionY,
				w = BUTTON_W,
				h = BUTTON_H,
				canAfford = canUpgrade,
				value = nil,
				cost = upgradeCost,
				onClick = function()
					Towers.upgradeTower(t)
				end,
				hotkey = Hotkeys.getDisplay("upgrade"),
				label = L("actions.upgrade"),
			}

			-- Sell button
			inspectButtons[#inspectButtons + 1] = {
				id = "sell",
				x = actionX + BUTTON_W + GAP,
				y = actionY,
				w = BUTTON_W,
				h = BUTTON_H,
				canAfford = true,
				cost = nil,
				value = sellValue,
				onClick = function()
					Towers.sellTower(t)
				end,
				hotkey = Hotkeys.getDisplay("sell"),
				label = L("actions.sell"),
			}

			-- Draw inspect action buttons (upgrade / sell)
			for _, btn in ipairs(inspectButtons) do
				local x, y = btn.x, btn.y
				local w, h = btn.w, btn.h
				local canAfford = btn.canAfford
				local hotkeyLabel = btn.hotkey
				local label = btn.label

				local mx, my = Cursor.x, Cursor.y
				local hovered = mx >= x and mx <= x + w and my >= y and my <= y + h

				local anim = ensureShopAnim(btn.id)

				if hovered ~= anim.hovered then
					anim.active = true
				end

				anim.hovered = hovered

				if anim.active then
					local speed = getDelta() * 10
					anim.t = hovered and min(1, anim.t + speed) or max(0, anim.t - speed)

					if anim.t == 0 or anim.t == 1 then
						anim.active = false
					end
				end

				local ease = anim.t * anim.t * (3 - 2 * anim.t)
				local bg = lerpColor(colorButton, colorButtonHover, ease)

				lg.setColor(bg)
				lg.rectangle("fill", x, y, w, h, 6, 6)

				if not canAfford then
					lg.setColor(colorDisabled)
					lg.rectangle("fill", x, y, w, h, 6, 6)
				end

				local ty = y + (h - textH) * 0.5
				local nameX = x + PAD

				-- Hotkey (left)
				if hotkeyLabel then
					local used = drawHotkeyVisual(btn.id, nameX + GLYPH_X_OFFSET, y, ty)

					nameX = nameX + used
				end

				-- Label
				local labelAlpha = canAfford and 1 or 0.55
				lg.setColor(colorText[1], colorText[2], colorText[3], labelAlpha)
				Text.printShadow(label, nameX, ty)

				-- Cost / value (right-aligned, shop-style)
				if btn.cost then
					-- Upgrade cost
					local costColor = canAfford and colorGood or colorBad

					lg.setColor(costColor)

					Text.printfShadow("$" .. formatNum(btn.cost), x + PAD, ty, w - PAD2, "right")
				elseif btn.value then
					-- Sell value (always positive, usually green)
					lg.setColor(colorGood)
					Text.printfShadow( "+$" .. formatNum(btn.value), x + PAD, ty, w - PAD2, "right")
				end
			end
		elseif State.selectedEnemy then
			local e = State.selectedEnemy

			Text.printShadow(L(e.def.nameKey), inspectTitleX, inspectTitleY)

			Text.printShadow(L("inspect.hp", formatNum(e.hp), formatNum(e.maxHp)), inspectBodyX, inspectBodyY)
		end
	end
end

function BottomBar.getShopButtons()
	return shopButtons
end

function BottomBar.getInspectButtons()
	return inspectButtons
end

return BottomBar