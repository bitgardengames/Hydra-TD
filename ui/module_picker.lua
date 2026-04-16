local Theme = require("core.theme")
local Fonts = require("core.fonts")
local State = require("core.state")
local Modules = require("systems.modules")
local DrawEntities = require("render.draw_entities")
local L = require("core.localization")

local lg = love.graphics
local lm = love.mouse

local ModulePicker = {}

local cards = {}
local openedAt = 0

local sin = math.sin
local cos = math.cos
local min = math.min
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

local function prettyTowerName(kind)
	return L("tower." .. kind)
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

local function getCategoryLabel(mod)
	local category = mod and mod.category

	if category == "movement" then
		return "MOVEMENT"
	elseif category == "damage" then
		return "DAMAGE"
	elseif category == "utility" then
		return "UTILITY"
	elseif category == "targeting" then
		return "TARGETING"
	elseif category == "special" then
		return "SPECIAL"
	end

	return "MODULE"
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

local function drawBadge(text, x, y, fill, alpha, padX, w, h, textColor)
	padX = padX or 10
	h = h or 24

	Fonts.set("ui")

	local tw = Fonts.ui:getWidth(text)
	local bw = w or (tw + padX * 2)

	lg.setColor(0, 0, 0, 0.30 * alpha)
	lg.rectangle("fill", x, y + 2, bw, h, 10, 10)

	lg.setColor(fill[1], fill[2], fill[3], 0.95 * alpha)
	lg.rectangle("fill", x, y, bw, h, 10, 10)

	lg.setColor(0, 0, 0, 0.20 * alpha)
	lg.rectangle("fill", x, y + h * 0.5, bw, h * 0.5, 0, 0, 10, 10)

	local tc = textColor or Theme.ui.text
	lg.setColor(tc[1], tc[2], tc[3], alpha)
	lg.print(text, x + padX, y + 4)

	return bw
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

local function drawCategoryGlyph(category, x, y, color, alpha)
	local r, g, b = color[1], color[2], color[3]

	lg.setColor(r, g, b, 0.22 * alpha)
	lg.circle("fill", x, y, 24)

	if category == "movement" then
		lg.setLineWidth(4)
		lg.setColor(r, g, b, alpha)
		lg.line(x - 12, y + 8, x + 10, y - 8)
		lg.line(x + 10, y - 8, x + 3, y - 8)
		lg.line(x + 10, y - 8, x + 10, y - 1)
		lg.setLineWidth(1)
	elseif category == "damage" then
		lg.setColor(r, g, b, alpha)
		lg.polygon("fill", x, y - 12, x + 8, y - 3, x + 12, y + 8, x, y + 4, x - 12, y + 8, x - 8, y - 3)
	elseif category == "utility" then
		lg.setLineWidth(3)
		lg.setColor(r, g, b, alpha)
		lg.circle("line", x, y, 11)
		lg.line(x - 14, y, x + 14, y)
		lg.line(x, y - 14, x, y + 14)
		lg.setLineWidth(1)
	elseif category == "targeting" then
		lg.setLineWidth(3)
		lg.setColor(r, g, b, alpha)
		lg.circle("line", x, y, 12)
		lg.line(x - 16, y, x - 8, y)
		lg.line(x + 8, y, x + 16, y)
		lg.line(x, y - 16, x, y - 8)
		lg.line(x, y + 8, x, y + 16)
		lg.circle("fill", x, y, 3)
		lg.setLineWidth(1)
	elseif category == "special" then
		lg.setLineWidth(4)
		lg.setColor(r, g, b, alpha)
		lg.line(x - 13, y + 10, x + 13, y - 10)
		lg.setLineWidth(2)
		lg.setColor(1, 1, 1, 0.9 * alpha)
		lg.line(x - 9, y + 8, x + 9, y - 6)
		lg.setLineWidth(1)
	else
		lg.setColor(r, g, b, alpha)
		lg.circle("fill", x, y, 10)
	end
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
		}
	end
end

local function drawBackdropEffects(sw, sh, alpha)
	local bandY = sh * 0.55

	lg.setColor(1, 1, 1, 0.024 * alpha)
	lg.ellipse("fill", sw * 0.5, bandY, sw * 0.30, sh * 0.16)

	lg.setColor(0, 0, 0, 0.22 * alpha)
	lg.rectangle("fill", 0, 0, sw, sh * 0.19)
	lg.rectangle("fill", 0, sh * 0.81, sw, sh * 0.19)
end

function ModulePicker.open(choices)
	State.modulePicker.active = true
	State.modulePicker.choices = choices
	openedAt = love.timer.getTime()
	rebuildLayout()
end

function ModulePicker.close()
	State.modulePicker.active = false
	State.modulePicker.choices = nil
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

	Modules.add(choice.moduleId, choice.target)
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

	Fonts.set("menu")
	lg.setColor(text[1], text[2], text[3], overlayT)
	lg.printf("Wave Reward", 0, sh * 0.135, sw, "center")

	Fonts.set("ui")
	lg.setColor(1, 1, 1, 0.75 * overlayT)
	lg.printf("Choose 1 Module", 0, sh * 0.135 + 34, sw, "center")

	local hintW = 276
	local hintH = 30
	local hintX = sw * 0.5 - hintW * 0.5
	local hintY = sh * 0.135 + 58

	lg.setColor(0, 0, 0, 0.24 * overlayT)
	lg.rectangle("fill", hintX, hintY + 2, hintW, hintH, 12, 12)
	lg.setColor(0.14, 0.14, 0.18, 0.9 * overlayT)
	lg.rectangle("fill", hintX, hintY, hintW, hintH, 12, 12)
	lg.setColor(1, 1, 1, 0.12 * overlayT)
	lg.rectangle("line", hintX, hintY, hintW, hintH, 12, 12)

	lg.setColor(1, 1, 1, 0.82 * overlayT)
	lg.printf("Press 1, 2, or 3 • Click a card", hintX, hintY + 6, hintW, "center")

	local choices = State.modulePicker.choices or {}

	for i = 1, #choices do
		local choice = choices[i]
		local mod = Modules.getDef(choice.moduleId)
		local c = cards[i]
		local towerColor = Theme.tower[choice.target] or text
		local category = mod and mod.category or "utility"

		local intro = easeOutBack((now - openedAt - c.delay) * 6.0)
		local alpha = clamp((now - openedAt - c.delay) * 5.0, 0, 1)

		if alpha > 0 then
			local hovered = pointInCard(mx, my, c)

			local hoverT = hovered and 1 or 0
			local lift = 10 * hoverT
			local scale = 1 + 0.018 * hoverT

			local baseX = c.x
			local baseY = c.y + (1 - smoothstep(alpha)) * 34

			local drawW = c.w * scale
			local drawH = c.h * scale
			local drawX = baseX - (drawW - c.w) * 0.5
			local drawY = baseY - lift - (drawH - c.h) * 0.5

			c.drawX = drawX
			c.drawY = drawY
			c.drawW = drawW
			c.drawH = drawH

			local radius = 20
			local artH = drawH * 0.36
			local bodyY = drawY + artH

			local faceR, faceG, faceB = colorLerp({0.08, 0.09, 0.11}, {0.10, 0.11, 0.13}, hoverT, alpha)
			local borderR, borderG, borderB = colorLerp(outline, towerColor, hoverT * 0.7, alpha)

			lg.setColor(0, 0, 0, (0.26 + 0.06 * hoverT) * alpha)
			lg.rectangle("fill", drawX + 5, drawY + 14, drawW, drawH, radius, radius)

			lg.setColor(towerColor[1], towerColor[2], towerColor[3], (0.08 + 0.16 * hoverT) * alpha)
			lg.rectangle("line", drawX - 2, drawY - 2, drawW + 4, drawH + 4, radius + 3, radius + 3)

			drawRoundedPanel(drawX, drawY, drawW, drawH, radius, {faceR, faceG, faceB}, {borderR, borderG, borderB}, alpha)

			local accentR, accentG, accentB = colorMul(towerColor, lerp(0.52, 0.72, hoverT), alpha)
			lg.setColor(accentR, accentG, accentB, (0.22 + hoverT * 0.12) * alpha)
			lg.rectangle("fill", drawX + 12, drawY + 12, drawW - 24, artH - 10, 14, 14)

			lg.setColor(1, 1, 1, (0.05 + 0.02 * hoverT) * alpha)
			lg.rectangle("fill", drawX + 12, drawY + 12, drawW - 24, 22, 14, 14)

			drawKeyBadge(tostring(i), drawX + drawW - 42, drawY + 16, alpha)
			drawCategoryGlyph(category, drawX + 36, drawY + 34, towerColor, alpha)

			local pulse = 1 + sin(now * 3.4 + i * 0.8) * 0.02 + hoverT * 0.03
			local towerScale = (1.85 + hoverT * 0.06) * pulse
			local towerX = drawX + drawW * 0.5
			local towerY = drawY + artH * 0.64

			lg.setColor(0, 0, 0, (0.16 + 0.03 * hoverT) * alpha)
			lg.ellipse("fill", towerX, towerY + 26, 44, 12)

			lg.push()
			lg.translate(towerX, towerY)
			lg.scale(towerScale, towerScale)
			DrawEntities.drawTowerVisual(choice.target, 0, 0, -math.pi / 2, 0, alpha)
			lg.pop()

			lg.setColor(1, 1, 1, 0.035 * alpha)
			lg.line(drawX + 16, bodyY + 6, drawX + drawW - 16, bodyY + 6)

			local badgeY = bodyY + 16
			local towerChip = prettyTowerName(choice.target):upper()
			local towerChipW = Fonts.ui:getWidth(towerChip) + 18
			drawBadge(towerChip, drawX + 20, badgeY, towerColor, alpha, 9, towerChipW, 22)

			local moduleChip = getCategoryLabel(mod)
			local moduleChipW = Fonts.ui:getWidth(moduleChip) + 18
			drawBadge(moduleChip, drawX + drawW - moduleChipW - 20, badgeY, {0.95, 0.95, 0.98}, alpha, 9, moduleChipW, 22, {0.10, 0.12, 0.16})

			Fonts.set("menu")
			lg.setColor(1, 1, 1, alpha)
			lg.printf(getModuleName(mod), drawX + 20, bodyY + 46, drawW - 40, "left")

			lg.setColor(towerColor[1], towerColor[2], towerColor[3], 0.70 * alpha)
			lg.rectangle("fill", drawX + 20, bodyY + 82, drawW - 40, 2, 2, 2)

			Fonts.set("ui")
			lg.setColor(1, 1, 1, 0.84 * alpha)
			lg.printf(getModuleDesc(mod), drawX + 20, bodyY + 95, drawW - 40, "left")

			if hovered then
				lg.setColor(towerColor[1], towerColor[2], towerColor[3], 0.08 * alpha)
				lg.rectangle("fill", drawX + 8, drawY + 8, drawW - 16, drawH - 16, radius, radius)

				lg.setColor(1, 1, 1, 0.07 * alpha)
				lg.rectangle("line", drawX + 8, drawY + 8, drawW - 16, drawH - 16, radius, radius)

				lg.setColor(1, 1, 1, 0.85 * alpha)
				Fonts.set("ui")
				lg.printf("Click to Claim", drawX + 18, drawY + drawH - 30, drawW - 36, "right")
			end
		end
	end
end

return ModulePicker
