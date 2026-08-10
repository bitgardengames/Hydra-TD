local Theme = require("core.theme")
local Fonts = require("core.fonts")
local State = require("core.state")
local Modules = require("systems.modules")
local Towers = require("world.towers")
local L = require("core.localization")
local Util = require("core.util")

local lg = love.graphics
local lm = love.mouse

local ModulePicker = {}

local cards = {}
local openedAt = 0
local layoutWidth, layoutHeight

local max = math.max

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function smoothstep(t)
	t = Util.clamp(t, 0, 1)

	return t * t * (3 - 2 * t)
end

local function easeOutBack(t)
	t = Util.clamp(t, 0, 1)

	local c1 = 1.70158
	local c3 = c1 + 1

	return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
end

local function getModuleName(mod)
	if mod and mod.nameKey then
		return L(mod.nameKey)
	end

	return "Unknown Module"
end

local function getModuleDesc(mod)
	if mod and mod.descKey then
		return L(mod.descKey)
	end

	return ""
end

local function colorLerp(a, b, t, alpha)
	return lerp(a[1], b[1], t), lerp(a[2], b[2], t), lerp(a[3], b[3], t), alpha or 1
end

local outlineW = Theme.outline.width
local baseRadius = 6 * 3
local outerRadius = baseRadius + outlineW * 0.5
local innerRadius = baseRadius - outlineW * 0.25
local outerSmallRadius = 6 + outlineW * 0.5
local innerSmallRadius = 6 - outlineW * 0.25

local function drawPanelCard(x, y, w, h, bodyColor, panelColor, edgeColor, alpha)
	local fa = alpha or 1
	local pad = 12
	local panelH = 28

	lg.setColor(edgeColor[1], edgeColor[2], edgeColor[3], fa)
	lg.rectangle("fill", x - outlineW, y - outlineW, w + outlineW * 2, h + outlineW * 2, outerRadius)

	lg.setColor(bodyColor[1], bodyColor[2], bodyColor[3], fa)
	lg.rectangle("fill", x, y, w, h, innerRadius)

	local panelX = x + pad
	local panelY = y + pad
	local panelW = w - pad * 2

	lg.setColor(edgeColor[1], edgeColor[2], edgeColor[3], fa)
	lg.rectangle("fill", panelX - outlineW, panelY - outlineW, panelW + outlineW * 2, panelH + outlineW * 2, outerSmallRadius)

	lg.setColor(panelColor[1], panelColor[2], panelColor[3], fa)
	lg.rectangle("fill", panelX, panelY, panelW, panelH, innerSmallRadius)

	return panelX, panelY, panelW, panelH
end

local function rebuildLayout()
	cards = {}
	layoutWidth, layoutHeight = lg.getDimensions()

	if not State.modulePicker.choices then
		return
	end

	local sw, sh = layoutWidth, layoutHeight
	local count = #State.modulePicker.choices

	local gap = Util.clamp(sw * 0.022, 18, 30)
	local cardW = Util.clamp((sw - 180 - gap * (count - 1)) / max(count, 1), 232, 300)
	local cardH = Util.clamp(sh * 0.40, 224, 264)
	local totalW = count * cardW + (count - 1) * gap
	local startX = (sw - totalW) * 0.5
	local y = sh * 0.5 - cardH * 0.24

	for i = 1, count do
		local x = startX + (i - 1) * (cardW + gap)

		cards[i] = {
			x = x,
			y = y,
			w = cardW,
			h = cardH,
			delay = (i - 1) * 0.06,
			drawX = x,
			drawY = y,
			drawW = cardW,
			drawH = cardH,
			hover = 0,
		}
	end
end

local function ensureLayout()
	local width, height = lg.getDimensions()
	if width ~= layoutWidth or height ~= layoutHeight then
		rebuildLayout()
	end
end

local function drawBackdropEffects(sw, sh, alpha)
	lg.setColor(0, 0, 0, 0.22 * alpha)
	lg.rectangle("fill", 0, 0, sw, sh * 0.19)
	lg.rectangle("fill", 0, sh * 0.81, sw, sh * 0.19)
end

function ModulePicker.open(options)
	if not Modules.isEnabled() then
		return false
	end
	local choices = options and options.choices or options

	if not choices or #choices == 0 then
		return false
	end

	State.modulePicker.active = true
	State.modulePicker.choices = choices
	State.modulePicker.mode = options and options.mode or "wave_reward"
	State.modulePicker.title = options and options.title or nil
	State.modulePicker.subtitle = options and options.subtitle or nil
	State.modulePicker.hint = options and options.hint or nil
	State.modulePicker.tower = options and options.tower or nil
	openedAt = love.timer.getTime()
	rebuildLayout()

	return true
end

local pickerDefaults = {
	active = false,
	mode = "wave_reward",
}
local pickerKeys = { "active", "choices", "mode", "title", "subtitle", "hint", "tower" }

local function clearPicker()
	for i = 1, #pickerKeys do
		local key = pickerKeys[i]
		State.modulePicker[key] = pickerDefaults[key]
	end
	cards = {}
	openedAt = 0
	layoutWidth, layoutHeight = nil, nil
end

function ModulePicker.reset()
	clearPicker()
	State.modulePicker.waveOffered = 0
end

function ModulePicker.openPurchase(choices)
	return ModulePicker.open({
		mode = "purchase_module",
		choices = choices,
		title = L("modulePicker.purchaseTitle"),
		subtitle = L("modulePicker.purchaseSubtitle"),
		hint = L("modulePicker.hint"),
	})
end

function ModulePicker.openApplyOwned(tower)
	if not tower then
		return false
	end

	local inventory = Modules.getInventory()
	local choices = {}
	for moduleId, count in pairs(inventory) do
		if count > 0 then
			local status = Modules.getApplyStatus(moduleId, tower)
			choices[#choices + 1] = {
				moduleId = moduleId,
				target = tower.kind,
				count = count,
				disabled = not status.ok,
				statusText = status.message,
			}
		end
	end

	table.sort(choices, function(a, b)
		return a.moduleId < b.moduleId
	end)

	return ModulePicker.open({
		mode = "apply_module",
		choices = choices,
		tower = tower,
		title = L("modulePicker.applyTitle", L(tower.def.nameKey)),
		subtitle = L("modulePicker.applySubtitle"),
		hint = L("modulePicker.hint"),
	})
end

function ModulePicker.openTowerUpgrade(tower)
	if not tower then
		return false
	end
	if not Modules.isEnabled() then
		return Towers.upgradeTower(tower)
	end

	local choices = Modules.rollTowerUpgradeChoices(tower)
	local cost = Towers.getUpgradeCost(tower)

	if not cost or State.money < cost then
		return false
	end
	for i = 1, #choices do
		choices[i].preview = Towers.getUpgradePreview(tower, choices[i].moduleId)
	end

	return ModulePicker.open({
		mode = "tower_upgrade",
		choices = choices,
		tower = tower,
		title = L("modulePicker.upgradeTitle", L(tower.def.nameKey)),
		subtitle = L("modulePicker.upgradeSubtitle", cost),
		hint = L("modulePicker.hint"),
	})
end

function ModulePicker.close()
	clearPicker()
end

function ModulePicker.isActive()
	return State.modulePicker.active == true
end

local modeActions = {
	tower_upgrade = function(choice, picker)
		return Towers.upgradeTower(picker.tower, choice.moduleId)
	end,
	apply_module = function(choice, picker)
		return Modules.applyToTower(choice.moduleId, picker.tower)
	end,
	purchase_module = function(choice)
		return Modules.purchase(choice.moduleId)
	end,
	wave_reward = function(choice)
		return Modules.add(choice.moduleId, choice.target)
	end,
}

local modeCtas = {
	tower_upgrade = "modulePicker.selectCta",
	apply_module = "modulePicker.applyCta",
	purchase_module = "modulePicker.purchaseCta",
}

function ModulePicker.choose(index)
	local picker = State.modulePicker
	local choice = picker.choices and picker.choices[index]

	if not choice then
		return false
	end

	if choice.disabled then
		return false
	end

	local action = modeActions[picker.mode]
	if not action or not action(choice, picker) then
		return false
	end

	ModulePicker.close()

	return true
end

local function pointInCard(mx, my, c)
	local x = c.drawX or c.x
	local y = c.drawY or c.y
	local w = c.drawW or c.w
	local h = c.drawH or c.h

	return mx >= x and mx <= x + w and my >= y and my <= y + h
end

function ModulePicker.update(dt)
	if not ModulePicker.isActive() then return end
	ensureLayout()
	local now = love.timer.getTime()
	local mx, my = lm.getPosition()
	local response = -60 * math.log(0.8)
	local factor = 1 - math.exp(-response * dt)

	for i, c in ipairs(cards) do
		local alpha = Util.clamp((now - openedAt - c.delay) * 5.0, 0, 1)
		local hovered = alpha > 0 and pointInCard(mx, my, c)
		c.hover = lerp(c.hover or 0, hovered and 1 or 0, factor)
		local intro = easeOutBack((now - openedAt - c.delay) * 6.0)
		local baseY = c.y + (1 - smoothstep(alpha)) * 34 - c.hover * 4
		c.drawW = c.w * lerp(0.95, 1.0, intro)
		c.drawH = c.h * lerp(0.95, 1.0, intro)
		c.drawX = c.x - (c.drawW - c.w) * 0.5
		c.drawY = baseY - (c.drawH - c.h) * 0.5
	end
end

function ModulePicker.mousepressed(x, y, button)
	if not ModulePicker.isActive() or button ~= 1 then
		return false
	end

	for i = 1, #cards do
		if pointInCard(x, y, cards[i]) then
			return ModulePicker.choose(i)
		end
	end

	return true
end

function ModulePicker.keypressed(key)
	if not ModulePicker.isActive() then
		return false
	end

	local index = tonumber(key)
	if index and index >= 1 and index <= #cards then
		return ModulePicker.choose(index)
	end

	return true
end

function ModulePicker.draw()
	if not ModulePicker.isActive() then
		return
	end
	local sw, sh = lg.getDimensions()
	local text = Theme.ui.text
	local dim = Theme.ui.screenDim
	local outline = Theme.outline.color
	local now = love.timer.getTime()
	local mx, my = lm.getPosition()

	local overlayT = smoothstep((now - openedAt) * 5.5)

	lg.setColor(dim[1], dim[2], dim[3], 0.84 * overlayT)
	lg.rectangle("fill", 0, 0, sw, sh)
	drawBackdropEffects(sw, sh, overlayT)

	local picker = State.modulePicker
	local title = picker.title or "Wave Reward"
	local subtitle = picker.subtitle or "Choose 1 Module"
	Fonts.set("title")
	local headerY = sh * 0.135
	lg.setColor(text[1], text[2], text[3], overlayT)
	lg.push()
	lg.translate(sw * 0.5, headerY)
	lg.printf(title, -sw * 0.5, 0, sw, "center")
	lg.pop()

	Fonts.set("ui")
	lg.setColor(1, 1, 1, 0.75 * overlayT)
	lg.printf(subtitle, 0, headerY + 40, sw, "center")

	local choices = State.modulePicker.choices or {}

	for i = 1, #choices do
		local choice = choices[i]
		local mod = Modules.getDef(choice.moduleId)
		local c = cards[i]
		local towerColor = choice.disabled and {0.45, 0.45, 0.45} or (Theme.tower[choice.target or (picker.tower and picker.tower.kind)] or text)

		local alpha = Util.clamp((now - openedAt - c.delay) * 5.0, 0, 1)

		if alpha > 0 then
			local hovered = pointInCard(mx, my, c)
			local hoverT = c.hover or 0
			local drawX, drawY = c.drawX, c.drawY
			local drawW, drawH = c.drawW, c.drawH

			local bodyY = drawY + 18

			local faceR, faceG, faceB = colorLerp(Theme.ui.backdrop, Theme.ui.panel, hoverT * 0.3, alpha)
			local panelR, panelG, panelB = colorLerp(Theme.ui.panel2, Theme.ui.panel2, hoverT * 0.3, alpha)
			local borderR, borderG, borderB = colorLerp({outline[1], outline[2], outline[3]}, towerColor, hoverT * 0.2, alpha)

			local panelX, panelY, panelW, panelH = drawPanelCard(
				drawX,
				drawY,
				drawW,
				drawH,
				{faceR, faceG, faceB},
				{panelR, panelG, panelB},
				{borderR, borderG, borderB},
				alpha
			)

			Fonts.set("menu")
			lg.setColor(1, 1, 1, alpha)
			local titleY = panelY + math.floor((panelH - Fonts.get("menu"):getHeight()) * 0.5 + 0.5)
			lg.printf(getModuleName(mod), panelX + 8, titleY, panelW - 42, "left")

			Fonts.set("ui")
			lg.setColor(1, 1, 1, choice.disabled and 0.46 * alpha or 0.84 * alpha)
			lg.printf(getModuleDesc(mod), drawX + 18, bodyY + 56, drawW - 36, "left")

			if picker.mode == "tower_upgrade" and choice.preview then
				local rows = choice.preview.rows or {}
				local rowY = bodyY + 112
				Fonts.set("tooltip")
				lg.setColor(1, 1, 1, 0.58 * alpha)
				lg.print(L("modulePicker.changes"), drawX + 18, rowY)
				rowY = rowY + 17
				-- Values are display-ready snapshots derived by Towers; cards do not
				-- duplicate or reinterpret authored stats.
				for rowIndex = 1, math.min(#rows, 7) do
					local row = rows[rowIndex]
					lg.setColor(1, 1, 1, 0.72 * alpha)
					lg.print(L(row.labelKey), drawX + 18, rowY)
					local currentText = row.current .. "  "
					local nextText = "→ " .. row.next
					local rightX = drawX + drawW - 18
					local nextW = Fonts.get("tooltip"):getWidth(nextText)
					local currentW = Fonts.get("tooltip"):getWidth(currentText)
					lg.setColor(1, 1, 1, 0.72 * alpha)
					lg.print(currentText, rightX - nextW - currentW, rowY)
					local changedColor = row.direction == "bad" and Theme.ui.bad or Theme.ui.good
					lg.setColor(changedColor[1], changedColor[2], changedColor[3], alpha)
					lg.print(nextText, rightX - nextW, rowY)
					rowY = rowY + 14
				end
			end

			if choice.statusText then
				lg.setColor(choice.disabled and 1 or towerColor[1], choice.disabled and 0.5 or towerColor[2], choice.disabled and 0.35 or towerColor[3], 0.86 * alpha)
				lg.printf(choice.statusText, drawX + 18, drawY + drawH - 54, drawW - 36, "left")
			end

			if hovered then
				local pulse = 0.5 + 0.5 * math.sin(now * 8 + i)
				lg.setColor(towerColor[1], towerColor[2], towerColor[3], (0.14 + 0.08 * pulse) * alpha)
				lg.rectangle("line", drawX - 2, drawY - 2, drawW + 4, drawH + 4, innerRadius + 2, innerRadius + 2)

				local ctaKey = modeCtas[picker.mode]
				local cta = choice.disabled and (choice.statusText or "Unavailable")
					or (ctaKey and L(ctaKey) or "Click to Claim")
				lg.setColor(1, 1, 1, (0.72 + 0.20 * pulse) * alpha)
				Fonts.set("ui")
				lg.printf(cta, drawX + 18, drawY + drawH - 30, drawW - 36, "right")
			end
		end
	end
end

return ModulePicker
