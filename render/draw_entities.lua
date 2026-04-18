local Constants = require("core.constants")
local Theme = require("core.theme")
local State = require("core.state")
local Enemies = require("world.enemies")
local Towers = require("world.towers")
local MapMod = require("world.map")

local random = love.math.random
local lg = love.graphics
local sqrt = math.sqrt
local sin = math.sin
local min = math.min
local max = math.max
local cos = math.cos
local pi = math.pi

-- Theme aliases
local outlineColor = Theme.outline.color
local enemyShadow = Theme.enemy.shadow
local enemyBody = Theme.enemy.body
local enemyFace = Theme.enemy.face
local colorSelected = Theme.ui.selected
local colorGood = Theme.ui.good
local colorBad = Theme.ui.bad
local colorPoison = Theme.projectiles.poison -- Can use Theme.tower.poison alternatively. Test and see
local colorSlow = Theme.projectiles.slow
local towerShadow = Theme.towerShadow

local lighting = Theme.lighting
local darkMul = lighting.shadowMul
local highlightOffset = lighting.highlightOffset
local highlightScale = lighting.highlightScale

local outR, outG, outB = outlineColor[1], outlineColor[2], outlineColor[3]
local eR, eG, eB = enemyBody[1], enemyBody[2], enemyBody[3]
local esR, esG, esB, esA = enemyShadow[1], enemyShadow[2], enemyShadow[3], enemyShadow[4]
local efR, efG, efB = enemyFace[1], enemyFace[2], enemyFace[3]
local selR, selG, selB = colorSelected[1], colorSelected[2], colorSelected[3]
local pr, pg, pb = colorPoison[1], colorPoison[2], colorPoison[3]
local sr, sg, sb = colorSlow[1], colorSlow[2], colorSlow[3]
local goodR, goodG, goodB = colorGood[1], colorGood[2], colorGood[3]
local badR, badG, badB = colorBad[1], colorBad[2], colorBad[3]
local tsR, tsG, tsB, tsA = towerShadow[1], towerShadow[2], towerShadow[3], towerShadow[4]

local outlineWidth = Theme.outline.width

local TILE = Constants.TILE
local HALF_PI = pi / 2

local towerDefs = Towers.TowerDefs

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function prepareEnemyRenderData()
	local enemies = Enemies.enemies
	local a = max(0, min(1, State.renderAlpha or 0))
	local totalLen = MapMod.map and MapMod.map.totalWorldLength or 0

	for i = 1, #enemies do
		local e = enemies[i]
		local oldRX = e.rx or e.x
		local oldRY = e.ry or e.y

		-- Interpolate along the already-simulated path segment.
		-- Using dist + speed * step * alpha can over/undershoot around corners
		-- (speed direction is piecewise, not globally linear), which shows up as
		-- jitter most noticeably on slower enemies like tanks.
		local prevDist = e.prevDist or e.dist or 0
		local currDist = e.dist or prevDist
		local d = min(totalLen, lerp(prevDist, currDist, a))
		local baseX, baseY = MapMod.sampleFast(d)

		local nudgeX = lerp(e.prevNudgeX or e.nudgeX or 0, e.nudgeX or 0, a)
		local nudgeY = lerp(e.prevNudgeY or e.nudgeY or 0, e.nudgeY or 0, a)

		-- Target position from fixed-step interpolation.
		local targetX = baseX + nudgeX
		local targetY = baseY + nudgeY

		-- Write interpolated position directly.
		-- We already interpolate between fixed simulation ticks via State.renderAlpha.
		-- Adding a second frame-delta smoother can introduce micro-pauses/jitter.
		e.rx = targetX
		e.ry = targetY

		-- Keep these for eye tracking / effects
		e.prevRX = oldRX
		e.prevRY = oldRY

		e.rAnimT = lerp(e.prevAnimT or e.animT, e.animT, a)
	end
end

-- Draw a single enemy
local function drawEnemy(e)
	local a = max(0, min(1, State.renderAlpha or 0))

	local ix = e.rx
	local iy = e.ry
	local animT = e.rAnimT or 0
	local enemyAlpha = e.alpha

	e.drawX = ix
	e.drawY = iy

    -- Boss Horns
    if e.boss then
        lg.setColor(outlineColor)

        local hornW = e.radius * 0.60
        local hornH = e.radius * 0.82
        local hornY = iy - e.radius * 1.02

        lg.push()
        lg.translate(ix - e.radius * 0.46, hornY)
        lg.rotate(-0.26)
        lg.polygon("fill", 0, 0, -hornW, hornH * 0.5, -hornW, -hornH * 0.5)
        lg.pop()

        lg.push()
        lg.translate(ix + e.radius * 0.46, hornY)
        lg.rotate(0.26)
        lg.polygon("fill", 0, 0, hornW, -hornH * 0.5, hornW, hornH * 0.5)
        lg.pop()
    end

    -- Shadow
	if e.shadow then
		local shadowAlpha = esA * (enemyAlpha * enemyAlpha)

		lg.setColor(esR, esG, esB, shadowAlpha)
		lg.ellipse("fill", ix, iy + e.radius, e.radius * 1.4, e.radius * 0.4)
	end

	-- Body outline
	lg.setColor(outR, outG, outB, enemyAlpha)
	lg.circle("fill", ix, iy, e.radius + 3)

	-- Body lighting (canonical system)
	local r = e.radius

	-- Base (shadowed)
	lg.setColor(eR * darkMul, eG * darkMul, eB * darkMul)
	lg.circle("fill", ix, iy, r)

	-- Top highlight
	local hx = ix
	local hy = iy - r * highlightOffset
	local hr = r * highlightScale

	lg.setColor(eR, eG, eB, enemyAlpha)
	lg.circle("fill", hx, hy, hr)

    -- Hit flash
    if e.hitFlash > 0 then
        local a = min(1, e.hitFlash / 0.05)

        lg.setColor(0.92, 0.96, 1.0, a * 0.55)
        lg.circle("fill", ix, iy, e.radius)
    end

	-- Slow (frost shell + shards)
	if e.slowTimer > 0 then
		local pulse = 0.6 + sin(animT * 3.5) * 0.4
		local alpha = (0.35 + pulse * 0.25) * enemyAlpha

		-- Outer frost shell
		lg.setColor(sr, sg, sb, alpha)
		lg.circle("line", ix, iy, e.radius + 3)

		-- Subtle frost tint (desaturating feel)
		lg.setColor(sr * 0.7, sg * 0.85, sb, 0.10 * enemyAlpha)
		lg.circle("fill", ix, iy, e.radius - 3)
	end

	-- Poison inner rim (clean green accent)
	if e.poisonStacks and e.poisonStacks > 0 then
		local stacks = e.poisonStacks
		local intensity = min(1.0, 0.3 + stacks * 0.12)

		-- Slightly desaturated green (less neon)
		local pr = 0.35
		local pg = 0.85
		local pb = 0.40

		lg.setColor(pr, pg, pb, 0.6 * intensity * enemyAlpha)
		lg.circle("line", ix, iy, e.radius - 1)
	end

	-- Eyes
	local eyeSep = e.radius * 0.38
	local eyeSize = max(1.6, e.radius * 0.16)
	local eyeY = iy - e.radius * 0.22

	lg.setColor(efR, efG, efB, enemyAlpha)

	if e.boss and e.dying then
		local bigR = eyeSize + 1
		local smallR = max(2, eyeSize - 1)
		local p = 1 - (e.deathT / e.deathDur)
		local pop = 1 + (1 - (p * p)) * 0.15

		lg.push()
		lg.translate(ix, eyeY)
		lg.scale(pop, pop)

		lg.setLineWidth(3)

		lg.setColor(0.9, 0.9, 0.9, enemyAlpha)
		lg.circle("fill", -eyeSep, 0, bigR + 1)

		lg.setColor(efR, efG, efB, enemyAlpha)

		lg.circle("line", -eyeSep, 0, bigR)
		lg.circle("fill", eyeSep, 0, smallR)

		lg.setLineWidth(1)
		lg.pop()
	elseif e.boss then
		local browLen = eyeSize * 2.5
		local browDrop = eyeSize * 0.85
		local browTension = sin(animT * 1.6) * 0.6
		local browLift = eyeSize * 0.35
		local browIn = eyeSize * 0.35

		lg.circle("fill", ix - eyeSep, eyeY, eyeSize)
		lg.circle("fill", ix + eyeSep, eyeY, eyeSize)

		lg.setLineWidth(2)

		lg.line(ix - eyeSep - browLen * 0.65 + browIn, eyeY - browDrop - browLift, ix - eyeSep + browLen * 0.35 + browIn, eyeY - browDrop * 0.15 + browTension - browLift)
		lg.line(ix + eyeSep - browLen * 0.35 - browIn, eyeY - browDrop * 0.15 + browTension - browLift, ix + eyeSep + browLen * 0.65 - browIn, eyeY - browDrop - browLift)
	elseif e.face == "shock" then
		local bigR = eyeSize + 1
		local smallR = max(2, eyeSize - 1)
		local p = 1 - (e.faceT / e.faceDur)
		local pop = 1 + (1 - (p * p)) * 0.15

		lg.push()
		lg.translate(ix, eyeY)
		lg.scale(pop, pop)

		lg.setLineWidth(2)

		lg.setColor(0.9, 0.9, 0.9, enemyAlpha)
		lg.circle("fill", -eyeSep, 0, bigR + 1)

		lg.setColor(efR, efG, efB, enemyAlpha)

		lg.circle("line", -eyeSep, 0, bigR)
		lg.circle("fill", eyeSep, 0, smallR)

		lg.setLineWidth(1)
		lg.pop()
	else
		-- Eye direction follows movement
		local dx = e.rx - (e.prevRX or e.rx)
		local dy = e.ry - (e.prevRY or e.ry)

		local m = 1.2 -- max

		if dx > m then dx = m end
		if dx < -m then dx = -m end
		if dy > m then dy = m end
		if dy < -m then dy = -m end

		lg.circle("fill", ix - eyeSep + dx, eyeY + dy, eyeSize)
		lg.circle("fill", ix + eyeSep + dx, eyeY + dy, eyeSize)
    end

	-- Selection Ring
	if State.selectedEnemy == e then
		lg.setColor(selR, selG, selB, 0.25)
		lg.circle("fill", ix, iy, e.radius + 4)

		lg.setColor(selR, selG, selB)
		lg.circle("line", ix, iy, e.radius + 4)
	end
end

local function drawEnemyHealth(e)
	if e.hp <= 0 then
		return
	end

	local w = e.boss and 44 or 28
	local h = e.boss and 7 or 5

	local ix = e.drawX or e.rx
	local iy = e.drawY or e.ry

	local bx = ix - w / 2
	local by = iy - e.radius - (e.boss and 18 or 12)

	local t = max(0, e.hp / e.maxHp)

	-- Muted health color
	local r, g, b

	if t > 0.5 then
		local p = (t - 0.5) / 0.5

		r = 0.85 - p * 0.55
		g = 0.75 + p * 0.20
		b = 0.20
	else
		local p = t / 0.5

		r = 0.85
		g = 0.45 + p * 0.30
		b = 0.20
	end

	-- Background
	lg.setColor(0, 0, 0, 0.5)
	lg.rectangle("fill", bx, by, w, h, 3, 3)

	local fillW = w * t

	if fillW > 0 then
		local minW = 4
		local visibleW = max(fillW, minW)

		local alphaScale = 1

		if t < 0.10 then
			alphaScale = t / 0.10
		end

		local radius = min(3, visibleW * 0.5, h * 0.5)

		-- Base
		lg.setColor(r * darkMul, g * darkMul, b * darkMul, 0.9 * alphaScale)
		lg.rectangle("fill", bx, by, visibleW, h, radius, radius)

		-- Highlight
		local hw = visibleW * 0.92
		local hh = h * highlightScale
		local hx = bx + visibleW * 0.5
		local hy = by + (hh * 0.5)

		-- Clamp height so it never spills out the bar
		if hh > h then
			hh = h
		end

		lg.setColor(r, g, b, 0.9 * alphaScale)
		lg.rectangle("fill", hx - hw * 0.5, hy - hh * 0.5, hw, hh, radius)
	end
end

-- Draw all enemies
local function drawEnemies()
	local enemies = Enemies.enemies

	lg.setLineWidth(2)

	-- Interpolate enemy positions
	prepareEnemyRenderData()

	-- Draw bodies
	for i = 1, #enemies do
		local e = enemies[i]

		drawEnemy(e)
	end

	-- Draw health bars above bodies
	for i = 1, #enemies do
		local e = enemies[i]

		drawEnemyHealth(e)
	end

	lg.setLineWidth(1)
end

local function getBarrelTip(t, localTipX)
	local size = TILE * 0.42

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

local function drawTowerInstance(t, cx, renderY)
	drawTowerVisual(t.kind, cx, renderY, t.angle, t.recoil, 1)
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

		-- Spawn drop (unchanged)
		local spawn = t.spawnAnim or 0
		local pSpawn = 1 - spawn
		local easeSpawn = pSpawn * pSpawn * (3 - 2 * pSpawn)

		-- Shadow
		local widthMult = 1 + (1 - easeSpawn) * 0.4
		local alphaMult = easeSpawn

		lg.setColor(tsR, tsG, tsB, tsA * alphaMult)
		lg.ellipse("fill", cx, t.y + size * 0.4, size * 0.85 * widthMult, size * 0.30)

		-- Only draw ground base after spawn completes
		if spawn <= 0 then
			drawTowerBase(t.kind, cx, groundY, 1, 0.2, 0.2, 0.2, groundY - renderY)
		end

		-- Top
		drawTowerInstance(t, cx, renderY)

		drawTowerFX(t)

		-- Pulse ring
		if riseAnim > 0 then
			lg.setColor(1, 1, 1, riseAnim * 0.4)
			lg.circle("line", cx, renderY, size * (1 + (1 - riseAnim)))
		end
	end
end

return {
	drawEnemy = drawEnemy,
	drawEnemies = drawEnemies,
	drawTowerBase = drawTowerBase,
	drawTowerCore = drawTowerCore,
	drawTowerGhost = drawTowerGhost,
	drawTowerVisual = drawTowerVisual,
	drawTowerFX = drawTowerFX,
	drawTowers = drawTowers,
}
