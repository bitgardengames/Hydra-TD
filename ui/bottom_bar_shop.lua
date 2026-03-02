local State = require("core.state")
local Towers = require("world.towers")
local Hotkeys = require("core.hotkeys")
local Glyphs = require("ui.glyphs")
local Text = require("ui.text")
local Tooltip = require("ui.tooltip")
local Theme = require("core.theme")
local L = require("core.localization")

local lg = love.graphics
local min = math.min
local max = math.max
local sin = math.sin
local abs = math.abs
local floor = math.floor
local format = string.format
local tostring = tostring

local Shop = {}

local colorBad = Theme.ui.bad
local colorText = Theme.ui.text
local colorButton = Theme.ui.button
local colorButtonHover = Theme.ui.buttonHover
local colorDisabled = Theme.ui.buttonDisabled

local ct1, ct2, ct3 = colorText[1], colorText[2], colorText[3]

local cb1, cb2, cb3 = colorButton[1], colorButton[2], colorButton[3]
local ch1, ch2, ch3 = colorButtonHover[1], colorButtonHover[2], colorButtonHover[3]

local cbd1 = ch1 - cb1
local cbd2 = ch2 - cb2
local cbd3 = ch3 - cb3

local shopButtons = {}
local shopBumps = {}
local shopAnims = {}

local lastTooltipKey = nil

local shopTooltip = {
	title = "",
	rows = {
		{label = "", value = 0},
		{label = "", value = 0},
		{label = "", value = 0},
		{kind = "text", text = ""},
	}
}

local numCache = {}

local function formatNum(n)
	local v = floor(n + 0.5)
	local cached = numCache[v]

	if cached then
		return cached
	end

	local s = tostring(v):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	numCache[v] = s

	return s
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

local function formatInterval(seconds)
	return (("%.2f"):format(seconds):gsub("0+$", ""):gsub("%.$", "")) .. "s"
end

local function getShopButton(i)
	local b = shopButtons[i]

	if not b then
		b = {
			kind = nil,
			x = 0, y = 0, w = 0, h = 0,
			canAfford = false,
			cost = nil,
			costText = "",
			nameText = "",
			hotkeyText = nil
		}

		shopButtons[i] = b
	end

	return b
end

local function ensureShopAnim(kind)
	if not shopAnims[kind] then
		shopAnims[kind] = {hovered = false, active = false, t = 0}
	end

	return shopAnims[kind]
end

local GLYPH_X_OFFSET = -5

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

local PAD = 8
local GAP = PAD
local SHOP_BTN_W = 124
local SHOP_BTN_H = 32
local SHOP_COLS = 3

function Shop.draw(panelX, panelY, panelW, panelH, dt, now, mx, my)
	local font = lg.getFont()
	local textH = font:getHeight()

	local shopCount = 0
	local i = 0
	local hoveredAnything = false

	for _, key in ipairs(Towers.shopOrder) do
		local def = Towers.TowerDefs[key]
		local hotkeyLabel = Hotkeys.getDisplay(key)

		local col = i % SHOP_COLS
		local row = (i - col) / SHOP_COLS

		local x = panelX + col * (SHOP_BTN_W + GAP)
		local yb = panelY + row * (SHOP_BTN_H + GAP)

		local selected = State.placing == key
		local canAfford = State.money >= def.cost
		local pulse = selected and (0.9 + sin(now * 6) * 0.1) or 1

		shopCount = shopCount + 1
		local btn = getShopButton(shopCount)

		btn.kind = key
		btn.x = x
		btn.y = yb
		btn.w = SHOP_BTN_W
		btn.h = SHOP_BTN_H
		btn.canAfford = canAfford

		if btn.cost ~= def.cost then
			btn.cost = def.cost
			btn.costText = "$" .. formatNum(def.cost)
		end

		if btn.nameKey ~= def.nameKey then
			btn.nameKey = def.nameKey
			btn.nameText = L(def.nameKey)
		end

		if btn.hotkeyText ~= hotkeyLabel then
			btn.hotkeyText = hotkeyLabel
		end

		local hovered = mx >= x and mx <= x + SHOP_BTN_W and my >= yb and my <= yb + SHOP_BTN_H
		local anim = ensureShopAnim(key)

		if hovered ~= anim.hovered then
			anim.active = true
		end

		anim.hovered = hovered

		if anim.active then
			local speed = dt * 10
			anim.t = hovered and min(1, anim.t + speed) or max(0, anim.t - speed)

			if anim.t == 0 or anim.t == 1 then
				anim.active = false
			end
		end

		local ease = anim.t * anim.t * (3 - 2 * anim.t)

		local r = cb1 + cbd1 * ease
		local g = cb2 + cbd2 * ease
		local b = cb3 + cbd3 * ease

		lg.setColor(r * pulse, g * pulse, b * pulse, 1)
		lg.rectangle("fill", x, yb, SHOP_BTN_W, SHOP_BTN_H, 6, 6)

		if hovered then
			hoveredAnything = true

			-- Only rebuild tooltip contents when the hovered key changes
			if lastTooltipKey ~= key then
				lastTooltipKey = key

				local rows = shopTooltip.rows

				shopTooltip.title = L(def.nameKey)
				rows[1].label = L("stats.damage")
				rows[1].value = def.damage

				rows[2].label = L("stats.fireRate")
				rows[2].value = formatInterval(1 / def.fireRate)

				rows[3].label = L("stats.range")
				rows[3].value = formatStat(def.range)

				rows[4].text = L(def.descKey)
			end

			Tooltip.show(shopTooltip)
		end

		if not canAfford then
			lg.setColor(colorDisabled)
			lg.rectangle("fill", x, yb, SHOP_BTN_W, SHOP_BTN_H, 6, 6)
		end

		local nameX = x + PAD
		local ty = yb + (SHOP_BTN_H - textH) * 0.5

		if hotkeyLabel then
			local used = drawHotkeyVisual(key, x + PAD, yb, ty)

			nameX = nameX + used
		end

		lg.setColor(ct1, ct2, ct3, canAfford and 1 or 0.55)
		Text.printShadow(btn.nameText, nameX, ty)

		lg.setColor(canAfford and colorText or colorBad)
		Text.printfShadow(btn.costText, x + PAD, ty, SHOP_BTN_W - PAD * 2, "right")

		i = i + 1
	end

	if not hoveredAnything then
		lastTooltipKey = nil
		Tooltip.hide()
	end
end

function Shop.getButtons()
	return shopButtons
end

return Shop