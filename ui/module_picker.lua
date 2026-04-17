local Theme = require("core.theme")
local Fonts = require("core.fonts")
local State = require("core.state")
local Modules = require("systems.modules")
local Towers = require("world.towers")
local L = require("core.localization")

local lg = love.graphics
local lm = love.mouse

local ModulePicker = {}

local cards = {}
local openedAt = 0

local max = math.max

local function clamp(x, a, b)
	if x < a then return a end
	if x > b then return b end
	return x
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function smoothstep(t)
	t = clamp(t, 0, 1)

	return t * t * (3 - 2 * t)
end

local function easeOutBack(t)
	t = clamp(t, 0, 1)

	local c1 = 1.70158
	local c3 = c1 + 1

	return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
end

local function easeInOutSine(t)
	t = clamp(t, 0, 1)

	return -(math.cos(math.pi * t) - 1) * 0.5
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

local function colorMul(c, mul, a)
	return c[1] * mul, c[2] * mul, c[3] * mul, a or 1
end

local function colorLerp(a, b, t, alpha)
	return lerp(a[1], b[1], t), lerp(a[2], b[2], t), lerp(a[3], b[3], t), alpha or 1
end

local function drawRoundedPanel(x, y, w, h, r, faceColor, borderColor, alpha)
	local fa = alpha or 1

	lg.setColor(borderColor[1], borderColor[2], borderColor[3], fa)
	lg.rectangle("fill", x, y, w, h, r, r)

	lg.setColor(faceColor[1], faceColor[2], faceColor[3], fa)
	lg.rectangle("fill", x + 2, y + 2, w - 4, h - 4, r - 2, r - 2)

	lg.setColor(1, 1, 1, 0.05 * fa)
	lg.rectangle("line", x + 2, y + 2, w - 4, h - 4, r - 2, r - 2)
end

local function drawKeyBadge(keyText, x, y, alpha)
	local fill = {0.14, 0.14, 0.18}

	lg.setColor(0, 0, 0, 0.28 * alpha)
	lg.rectangle("fill", x, y + 2, 28, 28, 9, 9)

	lg.setColor(fill[1], fill[2], fill[3], 1 * alpha)
	lg.rectangle("fill", x, y, 28, 28, 9, 9)

	lg.setColor(1, 1, 1, 0.10 * alpha)
	lg.rectangle("line", x, y, 28, 28, 9, 9)

	Fonts.set("menu")
	lg.setColor(1, 1, 1, alpha)
	lg.printf(keyText, x, y + 3, 28, "center")
end

local function rebuildLayout()
	cards = {}

	if not State.modulePicker.choices then
		return
	end

	local sw, sh = lg.getDimensions()
	local count = #State.modulePicker.choices

	local gap = clamp(sw * 0.022, 18, 30)
	local cardW = clamp((sw - 180 - gap * (count - 1)) / max(count, 1), 232, 300)
	local cardH = clamp(sh * 0.40, 224, 264)
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

local function drawBackdropEffects(sw, sh, alpha)
	local bandY = sh * 0.55

	lg.setColor(1, 1, 1, 0.024 * alpha)
	lg.ellipse("fill", sw * 0.5, bandY, sw * 0.30, sh * 0.16)
	lg.ellipse("fill", sw * 0.5, bandY + 18, sw * 0.38, sh * 0.11)

	lg.setColor(0, 0, 0, 0.22 * alpha)
	lg.rectangle("fill", 0, 0, sw, sh * 0.19)
	lg.rectangle("fill", 0, sh * 0.81, sw, sh * 0.19)
end

function ModulePicker.open(options)
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

function ModulePicker.openTowerUpgrade(tower)
	if not tower then
		return false
	end

	local choices = Modules.rollTowerUpgradeChoices(tower)
	local cost = Towers.getUpgradeCost(tower)

	if not cost or State.money < cost then
		return false
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
	State.modulePicker.active = false
	State.modulePicker.choices = nil
	State.modulePicker.mode = "wave_reward"
	State.modulePicker.title = nil
	State.modulePicker.subtitle = nil
	State.modulePicker.hint = nil
	State.modulePicker.tower = nil
	cards = {}
end

function ModulePicker.isActive()
	return State.modulePicker.active == true
end

function ModulePicker.choose(index)
	local picker = State.modulePicker
	local choice = picker.choices and picker.choices[index]

	if not choice then
		return false
	end

	if picker.mode == "tower_upgrade" then
		local ok = Towers.upgradeTower(picker.tower, choice.moduleId)
		if not ok then
			return false
		end
	else
		Modules.add(choice.moduleId, choice.target)
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

	if key == "1" then
		return ModulePicker.choose(1)
	elseif key == "2" then
		return ModulePicker.choose(2)
	elseif key == "3" then
		return ModulePicker.choose(3)
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
	local hintText = picker.hint or "Press 1, 2, or 3 • Click a card"

	Fonts.set("menu")
	lg.setColor(text[1], text[2], text[3], overlayT)
	lg.printf(title, 0, sh * 0.135, sw, "center")

	Fonts.set("ui")
	lg.setColor(1, 1, 1, 0.75 * overlayT)
	lg.printf(subtitle, 0, sh * 0.135 + 34, sw, "center")

	local hintW = 276
	local hintH = 26
	local hintX = sw * 0.5 - hintW * 0.5
	local hintY = sh * 0.135 + 58

	lg.setColor(0.14, 0.14, 0.18, 0.6 * overlayT)
	lg.rectangle("fill", hintX, hintY, hintW, hintH, 12, 12)
	lg.setColor(1, 1, 1, 0.08 * overlayT)
	lg.rectangle("line", hintX, hintY, hintW, hintH, 12, 12)

	lg.setColor(1, 1, 1, 0.72 * overlayT)
	lg.printf(hintText, hintX, hintY + 4, hintW, "center")

	local choices = State.modulePicker.choices or {}

	for i = 1, #choices do
		local choice = choices[i]
		local mod = Modules.getDef(choice.moduleId)
		local c = cards[i]
		local towerColor = Theme.tower[choice.target] or text

		local intro = easeOutBack((now - openedAt - c.delay) * 6.0)
		local alpha = clamp((now - openedAt - c.delay) * 5.0, 0, 1)

		if alpha > 0 then
			local hovered = pointInCard(mx, my, c)

			c.hover = lerp(c.hover or 0, hovered and 1 or 0, 0.2)
			local hoverT = c.hover
			local floatY = math.sin(now * 2.4 + i * 0.8) * (2 + 3 * hoverT)
			local lift = 4 + 12 * hoverT
			local scale = 1 + 0.016 * easeInOutSine(hoverT)

			local baseX = c.x
			local baseY = c.y + (1 - smoothstep(alpha)) * 42 + floatY

			local drawW = c.w * scale
			local drawH = c.h * scale
			local drawX = baseX - (drawW - c.w) * 0.5
			local drawY = baseY - lift - (drawH - c.h) * 0.5

			c.drawX = drawX
			c.drawY = drawY
			c.drawW = drawW
			c.drawH = drawH

			local radius = 20
			local bodyY = drawY + 24

			local faceR, faceG, faceB = colorLerp({0.08, 0.09, 0.11}, {0.10, 0.11, 0.13}, hoverT, alpha)
			local borderR, borderG, borderB = colorLerp(outline, towerColor, hoverT * 0.7, alpha)

			lg.setColor(0, 0, 0, (0.20 + 0.10 * hoverT) * alpha)
			lg.rectangle("fill", drawX + 4, drawY + 10, drawW, drawH + 4, radius, radius)

			drawRoundedPanel(drawX, drawY, drawW, drawH, radius, {faceR, faceG, faceB}, {borderR, borderG, borderB}, alpha)

			local accentR, accentG, accentB = colorMul(towerColor, lerp(0.42, 0.82, hoverT), alpha)
			lg.setColor(accentR, accentG, accentB, (0.11 + hoverT * 0.17) * alpha)
			lg.ellipse("fill", drawX + drawW * 0.5, drawY + drawH * 0.84, drawW * 0.44, drawH * 0.24)

			drawKeyBadge(tostring(i), drawX + drawW - 42, drawY + 16, alpha)

			Fonts.set("menu")
			lg.setColor(1, 1, 1, alpha)
			lg.printf(getModuleName(mod), drawX + 20, bodyY + 8, drawW - 40, "left")

			Fonts.set("ui")
			lg.setColor(1, 1, 1, 0.84 * alpha)
			lg.printf(getModuleDesc(mod), drawX + 20, bodyY + 48, drawW - 40, "left")

			if hovered then
				local pulse = 0.5 + 0.5 * math.sin(now * 8 + i)
				lg.setColor(towerColor[1], towerColor[2], towerColor[3], (0.10 + 0.06 * pulse) * alpha)
				lg.rectangle("line", drawX - 4, drawY - 4, drawW + 8, drawH + 8, radius + 4, radius + 4)

				local cta = picker.mode == "tower_upgrade" and L("modulePicker.selectCta") or "Click to Claim"
				lg.setColor(1, 1, 1, (0.72 + 0.20 * pulse) * alpha)
				Fonts.set("ui")
				lg.printf(cta, drawX + 18, drawY + drawH - 30, drawW - 36, "right")
			end
		end
	end
end

return ModulePicker
