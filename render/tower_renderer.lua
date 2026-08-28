local Constants = require("core.constants")
local Theme = require("core.theme")
local State = require("core.state")
local Towers = require("world.towers")
local MapMod = require("world.map")
local Save = require("core.save")
local TowerVictoryDance = require("render.tower_victory_dance")
local random, lg = love.math.random, love.graphics
local sqrt, sin, min, max, abs, cos = math.sqrt, math.sin, math.min, math.max, math.abs, math.cos
local pi, HALF_PI = math.pi, math.pi / 2
local TILE, towerDefs = Constants.TILE, Towers.TowerDefs
local outlineColor, colorGood, colorBad = Theme.outline.color, Theme.ui.good, Theme.ui.bad
local colorSelected, colorPoison, colorSlow, towerShadow = Theme.ui.selected, Theme.projectiles.poison, Theme.projectiles.slow, Theme.towerShadow
local outR, outG, outB = outlineColor[1], outlineColor[2], outlineColor[3]
local selR, selG, selB = colorSelected[1], colorSelected[2], colorSelected[3]
local pr, pg, pb = colorPoison[1], colorPoison[2], colorPoison[3]
local sr, sg, sb = colorSlow[1], colorSlow[2], colorSlow[3]
local goodR, goodG, goodB = colorGood[1], colorGood[2], colorGood[3]
local badR, badG, badB = colorBad[1], colorBad[2], colorBad[3]
local tsR, tsG, tsB, tsA = towerShadow[1], towerShadow[2], towerShadow[3], towerShadow[4]
local outlineWidth = Theme.outline.width
local darkMul = Theme.lighting.shadowMul
local highlightOffset = Theme.lighting.highlightOffset
local highlightScale = Theme.lighting.highlightScale
local UPGRADE_FLASH_DURATION = 0.3
local function getBarrelTip(t, localTipX)
	-- apply recoil in local barrel space
	local localX = (localTipX or 0) - (t.recoil or 0)
	local localY = 0

	local ca = cos(t.angle)
	local sa = sin(t.angle)

	local worldX = t.x + (localX * ca - localY * sa)
	local worldY = t.renderY + (localX * sa + localY * ca)

	return worldX, worldY
end

local function drawLancerFX(t)
	local a = t.fireAnim

	if a <= 0 then
		return
	end

	local size = TILE * 0.42
	local tipX = size * 0.90

	local mx, my = getBarrelTip(t, tipX)

	lg.setColor(1, 1, 1, 0.75 * a)
	lg.circle("fill", mx, my, 2)
end

local function drawSlowFX(t)
	local a = t.fireAnim

	if not a or a <= 0 then
		return
	end

	local size = TILE * 0.42
	local tipX = size * 0.64

	local mx, my = getBarrelTip(t, tipX)

	local p = 1 - a
	local radius = 4 + p * 14
	local alpha = 0.9 * (a * a)

	lg.setLineWidth(2)

	lg.setColor(0.92, 0.92, 0.96, alpha)
	lg.circle("line", mx, my, radius)

	lg.setColor(sr * 0.8, sg * 0.9, sb, alpha * 0.35)
	lg.circle("fill", mx, my, radius * 0.5)

	lg.setLineWidth(1)
end

local function drawShockFX(t)
	local a = t.fireAnim

	if a <= 0 then
		return
	end

	local size = TILE * 0.42
	local barrelLen = size * 0.52
	local offset = size * 0.12

	local tipX = size * 0.28 + barrelLen

	local ca = cos(t.angle)
	local sa = sin(t.angle)

	lg.setLineWidth(2)

	for i = -1, 1, 2 do
		local oy = offset * i

		local localX = tipX - (t.recoil or 0)
		local localY = oy

		local mx = t.x + (localX * ca - localY * sa)
		local my = t.renderY + (localX * sa + localY * ca)

		local p = 1 - a

		local r = 2 + p * 4
		local alpha = 0.7 * a

		lg.setColor(0.6, 0.9, 1.0, alpha)
		lg.circle("line", mx, my, r)
	end

	lg.setLineWidth(1)
end

local function drawCannonFX(t)
	local a = t.fireAnim

	if a <= 0 then
		return
	end

	local size = TILE * 0.42
	local tipX = size * 0.95

	local mx, my = getBarrelTip(t, tipX)

	local p = 1 - a

	-- Expand outward
	local r = 4 + p * 10

	-- Stronger early, softer late
	local alpha = 0.85 * (a * a)

	lg.setLineWidth(2)

	-- Main ring
	lg.setColor(1.0, 0.9, 0.7, alpha)
	lg.circle("line", mx, my, r)

	-- Optional inner glow (very subtle, helps impact feel)
	lg.setColor(1.0, 0.8, 0.6, alpha * 0.25)
	lg.circle("fill", mx, my, r * 0.5)

	lg.setLineWidth(1)
end

local function drawPlasmaFX(t)
	local a = t.fireAnim
	if a <= 0 then return end

	local size = TILE * 0.48
	local tipX = size * 0.86

	local mx, my = getBarrelTip(t, tipX)

	local p = 1 - a
	local w = 4 + p * 12
	local h = 2 + p * 4

	local alpha = 0.8 * a * a
	local angle = pi / 4

	lg.push()
	lg.translate(mx, my)

	lg.rotate(t.angle)

	lg.setLineWidth(2)

	lg.push()
	lg.rotate(angle)
	lg.setColor(0.96, 0.82, 1.0, alpha)
	lg.ellipse("line", 0, 0, w, h)
	lg.pop()

	lg.push()
	lg.rotate(-angle)
	lg.setColor(0.96, 0.82, 1.0, alpha)
	lg.ellipse("line", 0, 0, w, h)
	lg.pop()

	lg.setLineWidth(1)

	lg.pop()
end

local function drawPoisonFX(t)
	local a = t.fireAnim
	if not a or a <= 0 then return end

	local size = TILE * 0.42
	local tipX = size * 0.6
	local mx, my = getBarrelTip(t, tipX)

	local p = 1 - a
	local count = 5

	for i = 1, count do
		-- Wide spray cone
		local spread = 3
		local ang = t.angle + (i / count - 0.5) * spread

		local dx = cos(ang)
		local dy = sin(ang)

		local dist = (7 + i * 3) * p

		local x = mx + dx * dist
		local y = my + dy * dist

		local r = (2 + (i % 3)) * (1 - p * 0.4)

		local alpha = (a * 1.2) * (1 - p * 0.1)

		lg.setColor(0.35, 0.9, 0.45, alpha)
		lg.circle("fill", x, y, r)
	end
end

local function drawTowerFX(t)
	local kind = t.kind

	if kind == "shock" then
		drawShockFX(t)
	elseif kind == "cannon" then
		drawCannonFX(t)
	elseif kind == "lancer" then
		drawLancerFX(t)
	elseif kind == "slow" then
		drawSlowFX(t)
	elseif kind == "poison" then
		drawPoisonFX(t)
	elseif kind == "plasma" then
		drawPlasmaFX(t)
	end
end

local size = TILE * 0.42
local pad = 2

local function drawTowerBase(kind, cx, cy, alpha, tintR, tintG, tintB, height)
	local def = towerDefs[kind]

	if not def then
		return
	end

	alpha = alpha or 1
	tintR = tintR or 1
	tintG = tintG or 1
	tintB = tintB or 1
	height = height or 0

	local color = def.color
	local outlineW = outlineWidth

	local baseOuter = size * 0.6 + outlineW * 0.5
	local baseInner = baseOuter - outlineW

	local outerRadius = 6 + outlineW * 0.5
	local innerRadius = 6 - outlineW * 0.25

	local h = baseOuter * 2 + height

	-- Outline
	lg.setColor(outR, outG, outB, alpha)
	lg.rectangle("fill", cx - baseOuter, cy - baseOuter - height, baseOuter * 2, h, outerRadius, outerRadius)

	-- Fill
	lg.setColor(color[1] * tintR, color[2] * tintG, color[3] * tintB, alpha)
	lg.rectangle("fill", cx - baseInner, cy - baseInner - height, baseInner * 2, h - outlineW * 2, innerRadius, innerRadius)
end

-- Draw tower core shape
local function drawTowerCore(kind, cx, cy, angle, recoil, alpha, tintR, tintG, tintB, fireAnim)
	local def = towerDefs[kind]

	if not def then
		return
	end

	angle = angle or -HALF_PI
	recoil = recoil or 0
	alpha = alpha or 1
	tintR = tintR or 1
	tintG = tintG or 1
	tintB = tintB or 1
	fireAnim = fireAnim or 0

	local color = def.color
	local outlineW = outlineWidth
	local outlineA = alpha
	local bodyA = alpha

	-- Track shapes
	local rInner = nil
	local rectInner = nil
	local rectRadius = 0
	local rectRotation = 0

	-- Base
	lg.push()
	lg.translate(cx, cy)

	if def.canRotate then
		lg.rotate(angle)
	end

	lg.translate(-recoil, 0)

	if kind == "cannon" then
		local rOuter = size * 0.42 + outlineW * 0.5
		rInner = rOuter - outlineW

		lg.setColor(outR, outG, outB, outlineA)
		lg.circle("fill", 0, 0, rOuter)

		lg.setColor(color[1] * tintR * darkMul, color[2] * tintG * darkMul, color[3] * tintB * darkMul, bodyA)
		lg.circle("fill", 0, 0, rInner)
	elseif kind == "shock" then
		local rOuter = size * 0.36 + outlineW * 0.5
		rInner = rOuter - outlineW

		lg.setColor(outR, outG, outB, outlineA)
		lg.circle("fill", 0, 0, rOuter)

		lg.setColor(color[1] * tintR * darkMul, color[2] * tintG * darkMul, color[3] * tintB * darkMul, bodyA)
		lg.circle("fill", 0, 0, rInner)
	elseif kind == "poison" then
		local rOuter = size * 0.38 + outlineW * 0.5
		rInner = rOuter - outlineW

		lg.setColor(outR, outG, outB, outlineA)
		lg.circle("fill", 0, 0, rOuter)

		lg.setColor(color[1] * tintR * darkMul, color[2] * tintG * darkMul, color[3] * tintB * darkMul, bodyA)
		lg.circle("fill", 0, 0, rInner)
	elseif kind == "slow" then
		rectRotation = pi / 4

		lg.rotate(rectRotation)

		local o = size * 0.34 + outlineW * 0.5
		local i = o - outlineW

		rectInner = i
		rectRadius = 3

		lg.setColor(outR, outG, outB, outlineA)
		lg.rectangle("fill", -o, -o, o * 2, o * 2, 3 + outlineW * 0.5, 3 + outlineW * 0.5)

		lg.setColor(color[1] * tintR * darkMul, color[2] * tintG * darkMul, color[3] * tintB * darkMul, bodyA)
		lg.rectangle("fill", -i, -i, i * 2, i * 2, 3)
	elseif kind == "lancer" then
		local o = size * 0.35 + outlineW * 0.5
		local i = o - outlineW

		rectInner = i
		rectRadius = 5 - outlineW * 0.25

		lg.setColor(outR, outG, outB, outlineA)
		lg.rectangle("fill", -o, -o, o * 2, o * 2, 5 + outlineW * 0.5, 5 + outlineW * 0.5)

		lg.setColor(color[1] * tintR * darkMul, color[2] * tintG * darkMul, color[3] * tintB * darkMul, bodyA)
		lg.rectangle("fill", -i, -i, i * 2, i * 2, rectRadius)
	elseif kind == "plasma" then
		local o = size * 0.38 + outlineW * 0.5
		local i = o - outlineW

		rectInner = i
		rectRadius = 4 - outlineW * 0.25

		lg.setColor(outR, outG, outB, outlineA)
		lg.rectangle("fill", -o, -o, o * 2, o * 2, 5 + outlineW * 0.5, 5 + outlineW * 0.5)

		lg.setColor(color[1] * tintR * darkMul, color[2] * tintG * darkMul, color[3] * tintB * darkMul, bodyA)
		lg.rectangle("fill", -i, -i, i * 2, i * 2, rectRadius)
	end

	lg.pop()

	-- Highlight
	local ca = cos(angle)
	local sa = sin(angle)

	local baseX = cx - recoil * ca
	local baseY = cy - recoil * sa

	-- Round highlights (Cannon, Shock, Poison)
	if rInner then
		local hx = baseX
		local hy = baseY - rInner * highlightOffset
		local hr = rInner * highlightScale

		lg.setColor(color[1] * tintR, color[2] * tintG, color[3] * tintB, bodyA)
		lg.circle("fill", hx, hy, hr)
	end

	-- Lancer/Slow/Plasma highlights
	if rectInner then
		local topX = 0
		local topY = -1

		local offset = rectInner * highlightOffset

		local hx = baseX + topX * offset
		local hy = baseY + topY * offset
		local hr = rectRadius * highlightScale

		local hw = rectInner * 2 * highlightScale
		local hh = rectInner * 2 * highlightScale

		lg.push()
		lg.translate(hx, hy)

		-- Match tower rotation
		if def.canRotate then
			lg.rotate(angle)
		end

		-- Apply slow's internal rotation
		if rectRotation ~= 0 then
			lg.rotate(rectRotation)
		end

		lg.setColor(color[1] * tintR, color[2] * tintG, color[3] * tintB, bodyA)
		lg.rectangle("fill", -hw * 0.5, -hh * 0.5, hw, hh, hr)

		lg.pop()
	end

	-- Details
	lg.push()
	lg.translate(cx, cy)

	if def.canRotate then
		lg.rotate(angle)
	end

	lg.translate(-recoil, 0)

	if kind == "cannon" then
		local barrelH = size * 0.28

		lg.setColor(outR, outG, outB, outlineA)
		lg.rectangle("fill", size * 0.26, -barrelH * 0.5, size * 0.54, barrelH, 4, 4)
	elseif kind == "shock" then
		local barrelLen = size * 0.52
		local barrelW = size * 0.12
		local offset = size * 0.12

		for i = -1, 1, 2 do
			local oy = offset * i

			lg.setColor(outR, outG, outB, outlineA)
			lg.rectangle("fill", size * 0.28, oy - barrelW * 0.5, barrelLen, barrelW, 2, 2)
		end
	elseif kind == "poison" then
		local pulse = fireAnim * (1 - fireAnim) * 4
		local sacRadius = size * 0.16 + pulse

		lg.setColor(outR, outG, outB, outlineA)
		lg.circle("fill", size * 0.26, 0, sacRadius)
	elseif kind == "lancer" then
		lg.setColor(outR, outG, outB, outlineA)
		lg.rectangle("fill", size * 0.32, -size * 0.08, size * 0.58, size * 0.16, 2, 2)
	elseif kind == "slow" then
		local ex = rectInner
		local ey = 0

		local s = rectInner * 0.5

		lg.push()
		lg.translate(ex, ey)
		lg.rotate(pi / 4)

		lg.setColor(outR, outG, outB, outlineA)
		lg.rectangle("fill", -s, -s, s * 2, s * 2, 2)

		lg.pop()
	elseif kind == "plasma" then
		local barrelH = size * 0.24

		lg.setColor(outR, outG, outB, outlineA)
		lg.rectangle("fill", size * 0.26, -barrelH * 0.5, size * 0.58, barrelH, 3, 3)
	end

	lg.pop()
end

local function drawTowerBaseHighlight(kind, cx, cy, alpha)
	local def = towerDefs[kind]

	if not def then
		return
	end

	alpha = alpha or 1

	local c = def.color

	local baseOuter = size * 0.6 + outlineWidth * 0.5
	local baseInner = baseOuter - outlineWidth
	local innerRadius = 6 - outlineWidth * 0.25

	local hx = cx
	local hy = cy - baseInner * highlightOffset
	local hw = baseInner * 2 * highlightScale
	local hh = baseInner * 2 * highlightScale

	lg.setColor(c[1], c[2], c[3], alpha)
	lg.rectangle("fill", hx - hw * 0.5, hy - hh * 0.5, hw, hh, innerRadius)
end

local function drawTowerVisual(kind, cx, cy, angle, recoil, alpha)
	angle = angle or -HALF_PI
	recoil = recoil or 0
	alpha = alpha or 1

	-- Base
	drawTowerBase(kind, cx, cy, alpha, darkMul, darkMul, darkMul)

	-- Highlight
	drawTowerBaseHighlight(kind, cx, cy, alpha)

	-- Core
	drawTowerCore(kind, cx, cy, angle, recoil, alpha, 1, 1, 1, 0)
end

local function drawTowerInstance(t, cx, renderY, index)
	local headX = cx
	local headY = renderY
	local headAngle = t.angle
	if State.victory then
		local sway, bob, turn = TowerVictoryDance.pose(State.victoryDanceClock, t.kind, index)
		headX = headX + sway
		headY = headY + bob
		headAngle = headAngle + turn
	end

	-- Keep the tower body planted while only its turret receives either pose.
	drawTowerBase(t.kind, cx, renderY, 1, darkMul, darkMul, darkMul)
	drawTowerBaseHighlight(t.kind, cx, renderY, 1)
	drawTowerCore(t.kind, headX, headY, headAngle, t.recoil, 1, 1, 1, 1,
		0)
end

local function drawTowerUpgradeFlash(t, cx, renderY)
	local remaining = t.upgradeFlash or 0
	if remaining <= 0 then return end

	local elapsed = UPGRADE_FLASH_DURATION - remaining
	-- Reach full brightness in the first few frames, then leave a clean short tail.
	local peak = min(1, elapsed / 0.045)
	local fade = max(0, remaining / (UPGRADE_FLASH_DURATION - 0.045))
	local alpha = peak * fade
	local color = t.color or (t.def and t.def.color) or colorGood
	local dense = not (Save.data and Save.data.settings
		and Save.data.settings.highDensityParticles == false)
	local oldBlend, oldAlphaMode = lg.getBlendMode()

	lg.setBlendMode("add", "alphamultiply")
	-- In reduced-particle mode omit the core pass. The base glow still hugs the
	-- tower silhouette and communicates the upgrade with much less overdraw.
	drawTowerBase(t.kind, cx, renderY, alpha * (dense and 0.32 or 0.18),
		color[1], color[2], color[3])
	if dense then
		drawTowerCore(t.kind, cx, renderY, t.angle, t.recoil, alpha * 0.38,
			color[1], color[2], color[3], 0)
	end
	lg.setBlendMode(oldBlend, oldAlphaMode)
end

-- Draw tower placement ghost
local function drawTowerGhost()
	if not State.placing or not State.hoverGX or not State.hoverGY then
		return
	end

	local def = towerDefs[State.placing]

	if not def then
		return
	end

	local gx, gy = State.hoverGX, State.hoverGY
	local cx, cy = MapMod.gridToCenter(gx, gy)

	local placeOk = MapMod.canPlaceAt(gx, gy)
	local canAfford = State.money >= def.cost
	local ok = placeOk and canAfford
	local fade = State.placingFade or 1

	-- Range indicator
	lg.setColor(ok and 0.2 or 0.6, ok and 1.0 or 0.2, ok and 0.2 or 0.2, 0.14 * fade)
	lg.circle("fill", cx, cy, def.range)

	lg.setColor(ok and goodR or badR, ok and goodG or badG, ok and goodB or badB, 0.45 * fade)
	lg.circle("line", cx, cy, def.range)

	drawTowerBase(State.placing, cx, cy, (ok and 0.45 or 0.25) * fade, 1, ok and 1 or 0.4, ok and 1 or 0.4)

	drawTowerCore(State.placing, cx, cy, -HALF_PI, 0, (ok and 0.45 or 0.25) * fade, 1, ok and 1 or 0.4, ok and 1 or 0.4, 0)
end

local function drawTowers()
	local selected = State.selectedTower

	if selected then
		lg.setColor(selR, selG, selB, 0.18)
		lg.circle("fill", selected.x, selected.y, selected.range)

		lg.setColor(selR, selG, selB)
		lg.circle("line", selected.x, selected.y, selected.range)

		lg.setLineWidth(2)

		lg.rectangle("line", selected.x - size * 0.6 - pad, selected.y - size * 0.6 - pad, size * 1.2 + pad * 2, size * 1.2 + pad * 2, 6 + pad, 6 + pad)

		lg.setLineWidth(1)
	end

	local towers = Towers.towers

	for i = 1, #towers do
		local t = towers[i]

		local cx = t.x
		local groundY = t.y
		local renderY = t.renderY
		local riseAnim = t.levelUpAnim or 0

		-- Shadow
		lg.setColor(tsR, tsG, tsB, tsA)
		lg.ellipse("fill", cx, t.y + size * 0.4, size * 0.85, size * 0.30)

		drawTowerBase(t.kind, cx, groundY, 1, 0.2, 0.2, 0.2, groundY - renderY)

		-- Top
		drawTowerInstance(t, cx, renderY, i)
		drawTowerUpgradeFlash(t, cx, renderY)
		if (t.suppressedTimer or 0) > 0 then
			local clock = State.abilityClock or 0
			local pulse = 0.65 + 0.2 * sin(clock * 8 + i)
			lg.setColor(1, 0.16, 0.28, pulse)
			lg.setLineWidth(3)
			lg.circle("line", cx, groundY, size * (0.78 + 0.07 * sin(clock * 6)))
			lg.setColor(0.75, 0.08, 0.2, 0.18)
			lg.circle("fill", cx, groundY, size * 0.72)
			lg.setLineWidth(1)
		end
		if (t.abilityAttackSpeed or 1) > 1 then
			local pulse = .55 + .3 * sin((State.abilityClock or 0) * 7 + i)
			lg.setColor(1, .7, 1, pulse)
			lg.setLineWidth(2); lg.circle("line", cx, groundY, size * (.72 + .06*sin((State.abilityClock or 0)*5)))
		end

		drawTowerFX(t)

		-- Pulse ring
		if riseAnim > 0 then
			lg.setColor(1, 1, 1, riseAnim * 0.4)
			lg.circle("line", cx, renderY, size * (1 + (1 - riseAnim)))
		end
	end
end

local function drawSuppressionProjectiles()
	local projectiles = Towers.suppressionProjectiles
	local clock = State.abilityClock or 0
	for i = 1, #projectiles do
		local p = projectiles[i]
		local pulse = 1 + 0.16 * sin(clock * 12 + i)
		lg.setColor(0.42, 0.04, 0.12, 0.28)
		lg.circle("fill", p.x, p.y, 10 * pulse)
		lg.setColor(1, 0.12, 0.3, 0.95)
		lg.circle("fill", p.x, p.y, 5 * pulse)
		lg.setColor(1, 0.72, 0.78, 0.9)
		lg.circle("fill", p.x - 1.5, p.y - 1.5, 1.8 * pulse)
	end
end

return { drawTowerBase = drawTowerBase, drawTowerCore = drawTowerCore, drawTowerGhost = drawTowerGhost, drawTowerVisual = drawTowerVisual, drawTowerFX = drawTowerFX, drawTowers = drawTowers, drawSuppressionProjectiles = drawSuppressionProjectiles }
