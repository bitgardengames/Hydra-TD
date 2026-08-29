local State = require("core.state")
local Towers = require("world.towers")
local Text = require("ui.text")
local Button = require("ui.button")
local HotkeyVisual = require("ui.hotkey_visual")
local Tooltip = require("ui.tooltip")
local Theme = require("core.theme")
local L = require("core.localization")
local CampaignUnlocks = require("systems.campaign_unlocks")
local Constants = require("core.constants")
local TowerStatDisplay = require("core.tower_stat_display")

local lg = love.graphics
local sin = math.sin
local floor = math.floor
local tostring = tostring

local Shop = {}

local colorBad = Theme.ui.bad
local colorText = Theme.ui.text
local colorDisabled = Theme.ui.buttonDisabled
local colorOutline = Theme.outline.color

local ct1, ct2, ct3 = colorText[1], colorText[2], colorText[3]

local cd1, cd2, cd3 = colorDisabled[1], colorDisabled[2], colorDisabled[3]

local outlineW = Theme.outline.width
local outerRadius = 6 + outlineW * 0.5
local innerRadius = 6 - outlineW * 0.25

local shopButtons = {}
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
		}

		shopButtons[i] = b
	end

	return b
end

local function ensureShopAnim(kind)
	if not shopAnims[kind] then
		shopAnims[kind] = Button.newAnimation()
	end

	return shopAnims[kind]
end

local GAP_X = 15
local GAP_Y = 18
local PAD = 8
local SHOP_BTN_W = 126
local SHOP_BTN_H = 32
local SHOP_COLS = 3
local IDLE_LIFT = 6
local HOTKEY_LABEL_GAP = 7

local totalRowWidth = SHOP_BTN_W * SHOP_COLS + GAP_X * (SHOP_COLS - 1)

function Shop.draw(panelX, panelY, panelW, panelH, dt, now, mx, my)
	local towerList = Constants.TOWER_LIST
	local totalRows = math.ceil(#towerList / SHOP_COLS)
	local totalHeight = totalRows * SHOP_BTN_H + (totalRows - 1) * GAP_Y

	local font = lg.getFont()
	local textH = font:getHeight()

	local hoveredAnything = false

	local startX = floor(panelX + (panelW - totalRowWidth) * 0.5)
	local startY = floor(panelY + (panelH - totalHeight) * 0.5 + 3)

	for i = #towerList + 1, #shopButtons do
		shopButtons[i].kind = nil
		shopButtons[i].w = 0
		shopButtons[i].h = 0
	end

	for i, key in ipairs(towerList) do
		local def = Towers.TowerDefs[key]
		local lockMessage

		local index = i - 1
		local col = index % SHOP_COLS
		local row = (index - col) / SHOP_COLS

		local x = startX + col * (SHOP_BTN_W + GAP_X)
		local yb = startY + row * (SHOP_BTN_H + GAP_Y)

		local unlocked = CampaignUnlocks.isTowerUnlocked(key)
		local selected = unlocked and State.placing == key
		local canAfford = unlocked and State.money >= def.cost
		local pulse = selected and (0.9 + sin(now * 6) * 0.1) or 1

		local btn = getShopButton(i)

		btn.kind = key
		btn.x = x
		btn.y = yb
		btn.w = SHOP_BTN_W
		btn.h = SHOP_BTN_H
		btn.unlocked = unlocked
		btn.canAfford = canAfford

		if btn.cost ~= def.cost then
			btn.cost = def.cost
			btn.costText = "$" .. formatNum(def.cost)
		end

		if btn.nameKey ~= def.nameKey then
			btn.nameKey = def.nameKey
			btn.nameText = L(def.nameKey)
		end

		local hovered = mx >= x and mx <= x + SHOP_BTN_W and my >= yb and my <= yb + SHOP_BTN_H
		local anim = ensureShopAnim(key)

		btn.anim = anim
		Button.updateAnimation(anim, hovered, dt)
		local r, g, b = Button.getHoverColor(anim)

		if hovered then
			hoveredAnything = true

			-- Only rebuild tooltip contents when the hovered key changes
			if lastTooltipKey ~= key then
				lastTooltipKey = key

				local rows = shopTooltip.rows

				shopTooltip.title = L(def.nameKey)

				if unlocked then
					rows[1].kind = nil
					rows[1].label = L("stats.damage")
					rows[1].value = def.damage

					rows[2].kind = nil
					rows[2].label = L("stats.fireRate")
					rows[2].value = TowerStatDisplay.attackSpeed(def.fireRate)

					rows[3].kind = nil
					rows[3].label = L("stats.range")
					rows[3].value = TowerStatDisplay.range(def.range)

					rows[4].kind = "text"
					rows[4].text = L(def.descKey)
				else
					lockMessage = CampaignUnlocks.getLockMessage(key) or L("campaign.locked")

					rows[1].kind = "text"
					rows[1].text = lockMessage
					rows[2].kind = "text"
					rows[2].text = L(def.descKey)
					rows[3].kind = "text"
					rows[3].text = ""
					rows[4].kind = "text"
					rows[4].text = ""
				end
			end

			Tooltip.show(shopTooltip)
		end

		local pressEase = anim.pressT
		local lift = IDLE_LIFT * (1 - pressEase)

		local faceR = r * pulse
		local faceG = g * pulse
		local faceB = b * pulse

		-- If locked or unaffordable, override face color
		if not unlocked then
			faceR, faceG, faceB = cd1 * 0.7, cd2 * 0.7, cd3 * 0.7
		elseif not canAfford then
			faceR, faceG, faceB = cd1, cd2, cd3
		end

		-- Base
		lg.setColor(colorOutline)
		lg.rectangle("fill", x - outlineW, yb - outlineW, SHOP_BTN_W + outlineW * 2, SHOP_BTN_H + outlineW * 2, outerRadius)

		lg.setColor(faceR * 0.4, faceG * 0.4, faceB * 0.4, 1)
		lg.rectangle("fill", x, yb, SHOP_BTN_W, SHOP_BTN_H, innerRadius)

		-- Face (lifted)
		local fy = yb - lift

		lg.setColor(colorOutline)
		lg.rectangle("fill", x - outlineW, fy - outlineW, SHOP_BTN_W + outlineW * 2, SHOP_BTN_H + outlineW * 2, outerRadius)

		lg.setColor(faceR, faceG, faceB, 1)
		lg.rectangle("fill", x, fy, SHOP_BTN_W, SHOP_BTN_H, innerRadius)

		local nameX = x + PAD
		local ty = fy + (SHOP_BTN_H - textH) * 0.5

		if unlocked then
			local used = HotkeyVisual.draw(key, x + PAD, ty)

			if used > 0 then
				nameX = nameX + used + HOTKEY_LABEL_GAP
			end

			lg.setColor(ct1, ct2, ct3, canAfford and 1 or 0.55)
			Text.printShadow(btn.nameText, nameX, ty)

			lg.setColor(canAfford and colorText or colorBad)
			Text.printfShadow(btn.costText, x + PAD, ty, SHOP_BTN_W - PAD * 2, "right")
		else
			lg.setColor(ct1, ct2, ct3, 0.65)
			Text.printfShadow(L("campaign.locked"), x, ty, SHOP_BTN_W, "center")
		end

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
