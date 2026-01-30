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
local colorButton = Theme.ui.button
local colorButtonHover = Theme.ui.buttonHover

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

-- Floating panel styling
local PANEL_LIFT = 12     -- lift from bottom of screen
local PANEL_INSET = 12    -- nudge right from left edge

function BottomBar.draw()
	local font = lg.getFont()
	local textH = font:getHeight()
	local sw, sh = lg.getDimensions()
	local UI_H = Constants.UI_H

	-- PANEL METRICS (authoritative layout)
	local OUTER_PAD = 10
	local PANEL_GAP = 10
	local OUTER_R  = 12
	local INNER_R  = 8

	local INFO_H = HUD_H
	local SHOP_PANEL_W = SHOP_W
	local INSPECT_PANEL_W = INSPECT_W + PAD * 2

	local outerW =
		OUTER_PAD * 2 +
		SHOP_PANEL_W +
		PANEL_GAP +
		INSPECT_PANEL_W

	local outerH = UI_H
	local outerX = PANEL_INSET
	local outerY = sh - outerH - PANEL_LIFT

	-- OUTER PANEL
	lg.setColor(colorPanel)
	lg.rectangle("fill", outerX, outerY, outerW, outerH, OUTER_R, OUTER_R)

	-- INFO PANEL
	local infoX = outerX + OUTER_PAD
	local infoY = outerY + OUTER_PAD
	local infoW = outerW - OUTER_PAD * 2
	local infoH = INFO_H

	lg.setColor(colorPanel2)
	lg.rectangle("fill", infoX, infoY, infoW, infoH, INNER_R, INNER_R)
	
	-- SHOP PANEL
	local shopPanelX = outerX + OUTER_PAD
	local shopPanelY = infoY + infoH + PANEL_GAP
	local shopPanelW = SHOP_PANEL_W
	local shopPanelH = outerH - (shopPanelY - outerY) - OUTER_PAD

	lg.setColor(colorPanel2)
	lg.rectangle("fill", shopPanelX, shopPanelY, shopPanelW, shopPanelH, INNER_R, INNER_R)

	-- INSPECT PANEL
	local inspectPanelX = shopPanelX + shopPanelW + PANEL_GAP
	local inspectPanelY = shopPanelY
	local inspectPanelW = INSPECT_PANEL_W
	local inspectPanelH = shopPanelH

	lg.setColor(colorPanel2)
	lg.rectangle("fill", inspectPanelX, inspectPanelY, inspectPanelW, inspectPanelH, INNER_R, INNER_R)

	-- INFO CONTENT
	local y = infoY + floor((INFO_H - textH) * 0.5 + 0.5)

	State.moneyLerp = State.moneyLerp + (State.money - State.moneyLerp) * 0.25
	local moneyRounded = floor(State.moneyLerp + 0.5)
	local moneyCache = hudCache.money

	if moneyCache.value ~= moneyRounded then
		moneyCache.value = moneyRounded
		moneyCache.text = "$" .. formatNum(moneyRounded)
	end

	lg.setColor(colorText)
	Text.printShadow(moneyCache.text, infoX + 12, y)

	local livesCache = hudCache.lives
	if livesCache.value ~= State.lives then
		livesCache.value = State.lives
		livesCache.text = L("hud.lives", State.lives)
	end

	Text.printShadow(livesCache.text, infoX + 90, y)

	local waveCache = hudCache.wave
	if waveCache.value ~= State.wave then
		waveCache.value = State.wave
		waveCache.text = L("hud.wave", State.wave)
	end

	Text.printShadow(waveCache.text, infoX + 170, y)

	if State.inPrep then
		local t = floor(State.prepTimer * 10 + 0.5) / 10
		local prepCache = hudCache.prep

		if prepCache.value ~= t then
			prepCache.value = t
			prepCache.text = L("hud.prep", t)
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

	-- SHOP CONTENT
	local shopX = shopPanelX + PAD
	local shopY = shopPanelY + PAD

	for i = #shopButtons, 1, -1 do
		shopButtons[i] = nil
	end

	local i = 0
	for _, key in ipairs(Towers.shopOrder) do
		local def = Towers.TowerDefs[key]
		local hotkey = Hotkeys.getShopKey(key)

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
		if hovered ~= anim.hovered then anim.active = true end
		anim.hovered = hovered

		if anim.active then
			local speed = getDelta() * 10
			anim.t = hovered and min(1, anim.t + speed) or max(0, anim.t - speed)
			if anim.t == 0 or anim.t == 1 then anim.active = false end
		end

		local ease = anim.t * anim.t * (3 - 2 * anim.t)
		local bg = lerpColor(colorButton, colorButtonHover, ease)

		lg.setColor(bg[1] * pulse, bg[2] * pulse, bg[3] * pulse, 1)
		lg.rectangle("fill", x - bumpPad, yb - bumpPad,
			SHOP_BTN_W + bumpPad * 2, SHOP_BTN_H + bumpPad * 2, 6, 6)

		if not canAfford then
			lg.setColor(0, 0, 0, 0.35)
			lg.rectangle("fill", x, yb, SHOP_BTN_W, SHOP_BTN_H, 6, 6)
		end

		local ty = yb + (SHOP_BTN_H - textH) * 0.5
		local colorAfford = canAfford and colorText or colorBad
		lg.setColor(colorAfford)
		Text.printShadow(L(def.nameKey), x + PAD, ty)
		Text.printfShadow("$" .. def.cost, x + PAD, ty, SHOP_BTN_W - PAD2, "right")

		i = i + 1
	end

	-- INSPECT CONTENT
	local inspectX = inspectPanelX + PAD
	local inspectY = inspectPanelY + PAD
	local rightColX = inspectX + COL_W + 32
	local lineH = 16

	bottomBarButtons.upgrade = nil
	bottomBarButtons.sell = nil

	if State.selectedTower then
		local t = State.selectedTower

		lg.setColor(colorText)
		Text.printShadow(L("inspect.towerTitle", L(t.def.nameKey), t.level), inspectX, inspectY)

		local statsY = inspectY + 18
		Text.printShadow(L("inspect.damage", formatNum(t.damageDealt)), inspectX, statsY)
		Text.printShadow(L("inspect.kills", t.kills), inspectX, statsY + lineH)

	elseif State.selectedEnemy then
		local e = State.selectedEnemy
		lg.setColor(colorText)
		Text.printShadow(L(e.def.nameKey), inspectX, inspectY)
		Text.printShadow(L("inspect.hp", formatNum(e.hp), formatNum(e.maxHp)), inspectX, inspectY + 18)
	end
end

function BottomBar.getShopButtons()
	return shopButtons
end

function BottomBar.getBottomBarButtons()
	return bottomBarButtons
end

return BottomBar