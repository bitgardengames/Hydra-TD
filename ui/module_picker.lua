local Theme = require("core.theme")
local Fonts = require("core.fonts")
local State = require("core.state")
local Modules = require("systems.modules")
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

local function drawBadge(text, x, y, fill, alpha, padX, w, h)
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

	lg.setColor(1, 1, 1, alpha)
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

local function drawTowerSigil(kind, cx, cy, size, color, alpha, pulse)
	local r, g, b = color[1], color[2], color[3]
	local outline = Theme.outline.color
	local darkMul = Theme.lighting.shadowMul
	local highlightOffset = Theme.lighting.highlightOffset
	local highlightScale = Theme.lighting.highlightScale
	local s = size * pulse

	lg.setColor(0, 0, 0, 0.18 * alpha)
	lg.ellipse("fill", cx, cy + s * 0.42, s * 0.95, s * 0.28)

	if kind == "cannon" then
		lg.setColor(outline[1], outline[2], outline[3], alpha)
		lg.circle("fill", cx, cy, s * 0.52)

		lg.setColor(r * darkMul, g * darkMul, b * darkMul, alpha)
		lg.circle("fill", cx, cy, s * 0.42)

		lg.setColor(r, g, b, alpha)
		lg.circle("fill", cx, cy - s * highlightOffset * 0.42, s * 0.42 * highlightScale)

		lg.push()
		lg.translate(cx, cy)
		lg.rotate(-0.35)
		lg.setColor(outline[1], outline[2], outline[3], alpha)
		lg.rectangle("fill", s * 0.08, -s * 0.10, s * 0.52, s * 0.20, 6, 6)

		lg.setColor(r * 0.82, g * 0.82, b * 0.82, alpha)
		lg.rectangle("fill", s * 0.12, -s * 0.06, s * 0.44, s * 0.12, 5, 5)
		lg.pop()
	elseif kind == "shock" then
		lg.setColor(outline[1], outline[2], outline[3], alpha)
		lg.circle("fill", cx, cy, s * 0.48)

		lg.setColor(r * darkMul, g * darkMul, b * darkMul, alpha)
		lg.circle("fill", cx, cy, s * 0.38)

		lg.setColor(r, g, b, alpha)
		lg.circle("fill", cx, cy - s * highlightOffset * 0.38, s * 0.38 * highlightScale)

		lg.setLineWidth(6)
		lg.setColor(outline[1], outline[2], outline[3], alpha)
		lg.line(cx + s * 0.08, cy - s * 0.12, cx + s * 0.34, cy - s * 0.26)
		lg.line(cx + s * 0.08, cy + s * 0.12, cx + s * 0.34, cy + s * 0.26)

		lg.setLineWidth(3)
		lg.setColor(1, 1, 1, 0.75 * alpha)
		lg.line(cx + s * 0.10, cy - s * 0.12, cx + s * 0.33, cy - s * 0.25)
		lg.line(cx + s * 0.10, cy + s * 0.12, cx + s * 0.33, cy + s * 0.25)
		lg.setLineWidth(1)
	elseif kind == "poison" then
		lg.setColor(outline[1], outline[2], outline[3], alpha)
		lg.circle("fill", cx, cy, s * 0.48)

		lg.setColor(r * darkMul, g * darkMul, b * darkMul, alpha)
		lg.circle("fill", cx, cy, s * 0.38)

		lg.setColor(r, g, b, alpha)
		lg.circle("fill", cx, cy - s * highlightOffset * 0.38, s * 0.38 * highlightScale)

		lg.setColor(1, 1, 1, 0.20 * alpha)
		lg.circle("fill", cx + s * 0.24, cy - s * 0.22, s * 0.10)
		lg.circle("fill", cx + s * 0.36, cy - s * 0.04, s * 0.07)
	elseif kind == "slow" then
		local o = s * 0.42

		lg.push()
		lg.translate(cx, cy)
		lg.rotate(math.pi / 4)

		lg.setColor(outline[1], outline[2], outline[3], alpha)
		lg.rectangle("fill", -o, -o, o * 2, o * 2, 8, 8)

		lg.setColor(r * darkMul, g * darkMul, b * darkMul, alpha)
		lg.rectangle("fill", -o + 4, -o + 4, o * 2 - 8, o * 2 - 8, 7, 7)

		lg.setColor(r, g, b, alpha)
		lg.rectangle("fill", -o + 6, -o + 2, o * 2 - 12, o * 1.15, 6, 6)

		lg.pop()
	elseif kind == "lancer" then
		local o = s * 0.44

		lg.setColor(outline[1], outline[2], outline[3], alpha)
		lg.rectangle("fill", cx - o, cy - o, o * 2, o * 2, 10, 10)

		lg.setColor(r * darkMul, g * darkMul, b * darkMul, alpha)
		lg.rectangle("fill", cx - o + 4, cy - o + 4, o * 2 - 8, o * 2 - 8, 8, 8)

		lg.setColor(r, g, b, alpha)
		lg.rectangle("fill", cx - o + 5, cy - o + 2, o * 2 - 10, o * 1.1, 7, 7)

		lg.setColor(1, 1, 1, 0.85 * alpha)
		lg.polygon("fill", cx + s * 0.18, cy, cx + s * 0.42, cy - s * 0.12, cx + s * 0.42, cy + s * 0.12)
	elseif kind == "plasma" then
		local o = s * 0.44

		lg.setColor(outline[1], outline[2], outline[3], alpha)
		lg.rectangle("fill", cx - o, cy - o, o * 2, o * 2, 10, 10)

		lg.setColor(r * darkMul, g * darkMul, b * darkMul, alpha)
		lg.rectangle("fill", cx - o + 4, cy - o + 4, o * 2 - 8, o * 2 - 8, 8, 8)

		lg.setColor(r, g, b, alpha)
		lg.rectangle("fill", cx - o + 5, cy - o + 2, o * 2 - 10, o * 1.1, 7, 7)

		lg.setLineWidth(3)
		lg.setColor(1, 0.92, 1, 0.9 * alpha)
		lg.ellipse("line", cx, cy, s * 0.40, s * 0.16)
		lg.ellipse("line", cx, cy, s * 0.16, s * 0.40)
		lg.setLineWidth(1)
	else
		lg.setColor(outline[1], outline[2], outline[3], alpha)
		lg.circle("fill", cx, cy, s * 0.50)

		lg.setColor(r * darkMul, g * darkMul, b * darkMul, alpha)
		lg.circle("fill", cx, cy, s * 0.40)

		lg.setColor(r, g, b, alpha)
		lg.circle("fill", cx, cy - s * highlightOffset * 0.40, s * 0.40 * highlightScale)
	end
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
	local bandY = sh * 0.52

	lg.setColor(1, 1, 1, 0.035 * alpha)
	lg.ellipse("fill", sw * 0.5, bandY, sw * 0.32, sh * 0.19)

	lg.setColor(0, 0, 0, 0.18 * alpha)
	lg.rectangle("fill", 0, 0, sw, sh * 0.17)
	lg.rectangle("fill", 0, sh * 0.83, sw, sh * 0.17)

	lg.setColor(1, 1, 1, 0.015 * alpha)
	for i = 0, 12 do
		local x = i * (sw / 12)
		lg.rectangle("fill", x, bandY - 58, 2, 116)
	end
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

			local radius = 18
			local artH = drawH * 0.42
			local bodyY = drawY + artH - 10
			local bodyH = drawH - artH + 10

			local faceR, faceG, faceB = colorLerp({0.10, 0.10, 0.12}, {0.13, 0.13, 0.16}, hoverT, alpha)
			local borderR, borderG, borderB = colorLerp(outline, towerColor, hoverT * 0.65, alpha)

			lg.setColor(0, 0, 0, 0.22 * alpha)
			lg.rectangle("fill", drawX + 4, drawY + 12, drawW, drawH, radius, radius)
			lg.setColor(towerColor[1], towerColor[2], towerColor[3], (0.05 + 0.10 * hoverT) * alpha)
			lg.rectangle("fill", drawX - 2, drawY - 2, drawW + 4, drawH + 4, radius + 2, radius + 2)

			drawRoundedPanel(
				drawX,
				drawY,
				drawW,
				drawH,
				radius,
				{faceR, faceG, faceB},
				{borderR, borderG, borderB},
				alpha
			)

			local topR, topG, topB = colorMul(towerColor, lerp(0.72, 0.90, hoverT), alpha)
			local topR2, topG2, topB2 = colorMul(towerColor, lerp(0.44, 0.58, hoverT), alpha)

			lg.setColor(topR2, topG2, topB2, 0.98 * alpha)
			lg.rectangle("fill", drawX + 10, drawY + 10, drawW - 20, artH, 14, 14)

			lg.setColor(topR, topG, topB, 0.92 * alpha)
			lg.rectangle("fill", drawX + 10, drawY + 10, drawW - 20, artH * 0.72, 14, 14)

			lg.setColor(1, 1, 1, (0.06 + 0.04 * hoverT) * alpha)
			lg.rectangle("fill", drawX + 10, drawY + 10, drawW - 20, artH * 0.26, 14, 14)

			lg.setColor(0, 0, 0, 0.16 * alpha)
			lg.rectangle("fill", drawX + 10, drawY + artH * 0.70, drawW - 20, artH * 0.30, 0, 0, 14, 14)

			drawKeyBadge(tostring(i), drawX + drawW - 42, drawY + 18, alpha)
			drawCategoryGlyph(category, drawX + 42, drawY + 42, {1, 1, 1}, alpha)

			local pulse = 1 + sin(now * 4 + i * 0.7) * 0.03 + hoverT * 0.04
			drawTowerSigil(choice.target, drawX + drawW * 0.5, drawY + artH * 0.58, 42 + hoverT * 3, towerColor, alpha, pulse)

			lg.setColor(0.08, 0.08, 0.10, 0.98 * alpha)
			lg.rectangle("fill", drawX + 10, bodyY, drawW - 20, bodyH - 10, 14, 14)

			lg.setColor(1, 1, 1, 0.04 * alpha)
			lg.rectangle("line", drawX + 10, bodyY, drawW - 20, bodyH - 10, 14, 14)

			local catFill = towerColor
			local badgeY = bodyY + 12
			local leftPad = drawX + 22

			local catW = drawBadge(getCategoryLabel(mod), leftPad, badgeY, catFill, alpha)
			drawBadge(prettyTowerName(choice.target):upper(), leftPad + catW + 8, badgeY, {0.14, 0.14, 0.18}, alpha, 12)

			Fonts.set("ui")
			lg.setColor(towerColor[1], towerColor[2], towerColor[3], 0.95 * alpha)
			lg.print(prettyTowerName(choice.target), drawX + 22, bodyY + 44)

			Fonts.set("menu")
			lg.setColor(1, 1, 1, alpha)
			lg.printf(getModuleName(mod), drawX + 20, bodyY + 64, drawW - 40, "left")

			lg.setColor(towerColor[1], towerColor[2], towerColor[3], 0.65 * alpha)
			lg.rectangle("fill", drawX + 22, bodyY + 102, drawW - 44, 3, 3, 3)

			Fonts.set("ui")
			lg.setColor(1, 1, 1, 0.82 * alpha)
			lg.printf(getModuleDesc(mod), drawX + 22, bodyY + 116, drawW - 44, "left")

			if hovered then
				lg.setColor(towerColor[1], towerColor[2], towerColor[3], 0.10 * alpha)
				lg.rectangle("fill", drawX + 6, drawY + 6, drawW - 12, drawH - 12, radius, radius)

				lg.setColor(1, 1, 1, 0.08 * alpha)
				lg.rectangle("line", drawX + 6, drawY + 6, drawW - 12, drawH - 12, radius, radius)

				lg.setColor(1, 1, 1, 0.85 * alpha)
				Fonts.set("ui")
				lg.printf("Click to Claim", drawX + 18, drawY + drawH - 32, drawW - 36, "right")
			end
		end
	end
end

return ModulePicker
