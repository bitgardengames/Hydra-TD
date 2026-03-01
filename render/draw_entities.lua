local Constants = require("core.constants")
local Theme = require("core.theme")
local State = require("core.state")
local Enemies = require("world.enemies")
local Towers = require("world.towers")
local MapMod = require("world.map")

local lg = love.graphics
local getTime = love.timer.getTime
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

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function prepareEnemyRenderData()
	local enemies = Enemies.enemies
	local a = max(0, min(1, State.renderAlpha or 0))

	for i = 1, #enemies do
		local e = enemies[i]

		-- Interpolate distance
		local d = lerp(e.prevDist or e.dist, e.dist, a)
		local segHint = e.prevSeg or e.seg or 1

		local x, y = MapMod.sampleAtDist(d, segHint)

		-- Interpolate animation time
		local animT = lerp(e.prevAnimT or e.animT, e.animT, a)

		-- Store render-only values
		e.rx = x
		e.ry = y
		e.rAnimT = animT
	end
end

-- Draw a single enemy
local function drawEnemy(e)
	local ix = e.rx or 0
	local iy = e.ry or 0
	local animT = e.rAnimT or 0
    local enemyAlpha = e.alpha

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

	-- Fill
	lg.setColor(eR, eG, eB, enemyAlpha)
	lg.circle("fill", ix, iy, e.radius)

    -- Hit flash
    if e.hitFlash > 0 then
        local a = min(1, e.hitFlash / 0.05)

        lg.setColor(1.0, 0.95, 0.9, a * 0.35)
        lg.circle("fill", ix, iy, e.radius + 1)
    end

	-- Slow (frost shell + shards)
	if e.slowTimer > 0 then
		local pulse = 0.6 + sin(animT * 3.5) * 0.4
		local alpha = (0.35 + pulse * 0.25) * enemyAlpha

		-- Outer frost shell
		lg.setLineWidth(2)
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

		lg.setLineWidth(2)
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
    else
        local dx = sin(animT * 1.3) * 0.6
        local dy = cos(animT * 1.1) * 0.4

        lg.circle("fill", ix - eyeSep + dx, eyeY + dy, eyeSize)
        lg.circle("fill", ix + eyeSep + dx, eyeY + dy, eyeSize)
    end

	-- Selection Ring
	if State.selectedEnemy == e then
		lg.setColor(selR, selG, selB, 0.25)
		lg.circle("fill", ix, iy, e.radius + 4)

		lg.setColor(colorSelected)
		lg.circle("line", ix, iy, e.radius + 4)
	end
end

local function drawEnemyHealth(e)
	if e.hp <= 0 then
		return
	end

	local w = e.boss and 44 or 28
	local h = e.boss and 7 or 5
	local ix = e.rx
	local iy = e.ry
	local bx = ix - w / 2
	local by = iy - e.radius - (e.boss and 18 or 12)

	local t = max(0, e.hp / e.maxHp)

	local r, g

	if t > 0.5 then
		local p = (t - 0.5) / 0.5

		r, g = 1 - p, 1
	else
		local p = t / 0.5

		r, g = 1, p
	end

	-- Background
	lg.setColor(0, 0, 0, 0.5)
	lg.rectangle("fill", bx, by, w, h, 3, 3)

	-- Fill
	local fillW = w * t

	if fillW > 0 then
		-- Keep a minimum width so it never collapses visually
		local minW = 4
		local visibleW = max(fillW, minW)

		-- Fade out near zero instead of shrinking into a square
		local alphaScale = 1

		if t < 0.10 then
			alphaScale = t / 0.10
		end

		local radius = min(3, visibleW * 0.5, h * 0.5)

		lg.setColor(r * 0.9 + 0.05, g * 0.9 + 0.05, 0.15, 0.9 * alphaScale)

		lg.rectangle("fill", bx, by, visibleW, h, radius, radius)
	end
end

-- Draw all enemies + death FX
local function drawEnemies()
	local enemies = Enemies.enemies

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

	local deathFX = Enemies.deathFX

	for i = 1, #deathFX do
		local fx = deathFX[i]
		local p = fx.t / 0.14
		local a = (1 - p) * 0.6
		local scale = 1 + p * 0.25

		lg.setColor(1, 1, 1, a)
		lg.circle("line", fx.x, fx.y, fx.r * scale)

		lg.setColor(1, 1, 1, a * 0.2)
		lg.circle("fill", fx.x, fx.y, fx.r * scale)
	end
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
	local tipX = size * 0.42

	local mx, my = getBarrelTip(t, tipX)

	local p = 1 - a
	local radius = 3 + p * 10
	local alpha = 0.9 * (a * a)

	lg.setLineWidth(2 + a * 1.5)
	--lg.setColor(sr, sg, sb, alpha)
	lg.setColor(0.92, 0.92, 0.96, alpha)
	lg.circle("line", mx, my, radius)

	lg.setColor(sr * 0.8, sg * 0.9, sb, alpha * 0.35)
	lg.circle("fill", mx, my, radius * 0.6)
end

local function drawShockFX(t)
	local size = TILE * 0.42
	local outerR = size * 0.36
	local coreR  = size * 0.08

	if t.windUp and t.windUp > 0 then
		local tNorm = 1 - (t.windUp / 0.08)
		local charge = tNorm * tNorm

		local ringR = outerR + (coreR - outerR) * charge
		local alpha = 0.25 + charge * 0.75

		lg.setLineWidth(2)
		lg.setColor(1, 1, 1, alpha)
		lg.circle("line", t.x, t.renderY, ringR)

		lg.setColor(1, 1, 1, charge * 0.4)
		lg.circle("fill", t.x, t.renderY, coreR * (1 + charge * 0.4))
	end
end

local function drawCannonFX(t)
	local a = t.fireAnim

	if a <= 0 then
		return
	end

	local size = TILE * 0.42
	local tipX = size * 0.80

	local mx, my = getBarrelTip(t, tipX)

	local r = 4 + (1 - a) * 4

	lg.setColor(0.9, 0.9, 0.9, 0.75 * a)
	lg.circle("fill", mx, my, r)
end

local function drawTowerFX(t)
	if t.kind == "shock" then
		drawShockFX(t)
	elseif t.kind == "cannon" then
		drawCannonFX(t)
	elseif t.kind == "lancer" then
		drawLancerFX(t)
	elseif t.kind == "slow" then
		drawSlowFX(t)
	end
end

local size = TILE * 0.42
local pad = 2

local function drawTowerBase(kind, cx, cy, alpha, tintR, tintG, tintB)
	local def = Towers.TowerDefs[kind]

	if not def then
		return
	end

	alpha = alpha or 1
	tintR = tintR or 1
	tintG = tintG or 1
	tintB = tintB or 1

	local color = def.color
	local outlineW = outlineWidth

	local baseOuter = size * 0.6 + outlineW * 0.5
	local baseInner = baseOuter - outlineW

	local outerRadius = 6 + outlineW * 0.5
	local innerRadius = 6 - outlineW * 0.25

	-- Outline
	lg.setColor(outR, outG, outB, alpha)
	lg.rectangle("fill", cx - baseOuter, cy - baseOuter, baseOuter * 2, baseOuter * 2, outerRadius, outerRadius)

	-- Fill
	lg.setColor(color[1] * tintR, color[2] * tintG, color[3] * tintB, alpha)
	lg.rectangle("fill", cx - baseInner, cy - baseInner, baseInner * 2, baseInner * 2, innerRadius, innerRadius)
end

-- Draw tower core shape
local function drawTowerCore(kind, cx, cy, angle, recoil, alpha, tintR, tintG, tintB, fireAnim)
	local def = Towers.TowerDefs[kind]

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

	lg.push()
	lg.translate(cx, cy)

	if def.canRotate then
		lg.rotate(angle)
	end

	lg.translate(-recoil, 0)

	-- Cannon
	if kind == "cannon" then
		local rOuter = size * 0.42 + outlineW * 0.5
		local rInner = rOuter - outlineW
		local barrelH = size * 0.28

		lg.setColor(outR, outG, outB, outlineA)
		lg.circle("fill", 0, 0, rOuter)

		lg.setColor(color[1] * tintR, color[2] * tintG, color[3] * tintB, bodyA)
		lg.circle("fill", 0, 0, rInner)

		lg.setColor(outR, outG, outB, outlineA)
		lg.rectangle("fill", size * 0.26, -barrelH * 0.5, size * 0.54, barrelH, 4, 4)
	elseif kind == "slow" then
		lg.rotate(pi / 4)

		local o = size * 0.34 + outlineW * 0.5
		local i = o - outlineW

		lg.setColor(outR, outG, outB, outlineA)
		lg.rectangle("fill", -o, -o, o * 2, o * 2, 3 + outlineW * 0.5, 3 + outlineW * 0.5)

		lg.setColor(color[1] * tintR, color[2] * tintG, color[3] * tintB, bodyA)
		lg.rectangle("fill", -i, -i, i * 2, i * 2, 3 - outlineW * 0.25, 3 - outlineW * 0.25)
	elseif kind == "shock" then
		local rOuter = size * 0.36 + outlineW * 0.5
		local rInner = rOuter - outlineW

		lg.setColor(outR, outG, outB, outlineA)
		lg.circle("fill", 0, 0, rOuter)

		lg.setColor(color[1] * tintR, color[2] * tintG, color[3] * tintB, bodyA)
		lg.circle("fill", 0, 0, rInner)
	elseif kind == "poison" then
		local rOuter = size * 0.38 + outlineW * 0.5
		local rInner = rOuter - outlineW

		lg.setColor(outR, outG, outB, outlineA)
		lg.circle("fill", 0, 0, rOuter)

		lg.setColor(color[1] * tintR, color[2] * tintG, color[3] * tintB, bodyA)
		lg.circle("fill", 0, 0, rInner)

		local pulse = fireAnim * (1 - fireAnim) * 4
		local sacRadius = size * 0.16 + pulse

		lg.setColor(outR, outG, outB, outlineA)
		lg.circle("fill", size * 0.26, 0, sacRadius)
	else -- Lancer
		local o = size * 0.35 + outlineW * 0.5
		local i = o - outlineW

		lg.setColor(outR, outG, outB, outlineA)
		lg.rectangle("fill", -o, -o, o * 2, o * 2, 5 + outlineW * 0.5, 5 + outlineW * 0.5)

		lg.setColor(color[1]*tintR, color[2]*tintG, color[3]*tintB, bodyA)
		lg.rectangle("fill", -i, -i, i * 2, i * 2, 5 - outlineW * 0.25, 5 - outlineW * 0.25)

		lg.setColor(outR, outG, outB, outlineA)
		lg.rectangle("fill", size * 0.32, -size * 0.08, size * 0.58, size * 0.16, 2, 2)
	end

	lg.pop()
end

-- Draw tower placement ghost
local function drawTowerGhost()
	if not State.placing or not State.hoverGX or not State.hoverGY then
		return
	end

	local def = Towers.TowerDefs[State.placing]

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

	drawTowerCore(State.placing, cx, cy, 0, 0, (ok and 0.45 or 0.25) * fade, 1, ok and 1 or 0.4, ok and 1 or 0.4, 0)
end

local function drawTowers()
	local selected = State.selectedTower

	if selected then
		lg.setColor(selR, selG, selB, 0.18)
		lg.circle("fill", selected.x, selected.y, selected.range)

		lg.setColor(colorSelected)
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
		local bodyY = groundY

		-- Spawn drop (unchanged)
		local spawn = t.spawnAnim or 0
		local pSpawn = 1 - spawn
		local easeSpawn = pSpawn * pSpawn * (3 - 2 * pSpawn)

		if spawn > 0 then
			bodyY = bodyY - ((1 - easeSpawn) * 8)
		end

		-- Shadow
		local widthMult = 1 + (1 - easeSpawn) * 0.4
		local alphaMult = easeSpawn

		lg.setColor(tsR, tsG, tsB, tsA * alphaMult)
		lg.ellipse("fill", cx, t.y + size * 0.4, size * 0.85 * widthMult, size * 0.30)

		-- Permanent height from levels
		local levelHeight = (t.level - 1) * 4

		-- Animation progress
		local riseAnim = t.levelUpAnim or 0
		local p = 1 - riseAnim
		local ease = p * p * (3 - 2 * p)

		local animatedHeight = levelHeight * ease
		local renderY = bodyY - animatedHeight

		t.renderY = renderY

		-- Only draw ground base after spawn completes
		if spawn <= 0 then
			drawTowerBase(t.kind, cx, groundY, 1, 0.2, 0.2, 0.2)
		end

		-- Base (moving)
		drawTowerBase(t.kind, cx, renderY, 1, 1, 1, 1)

		-- Colored body
		drawTowerCore(t.kind, cx, renderY, t.angle, t.recoil, 1, 1, 1, 1, t.fireAnim)

		drawTowerFX(t)

		-- Pulse ring
		if riseAnim > 0 then
			lg.setColor(1, 1, 1, riseAnim * 0.4)
			lg.circle("line", cx, groundY - animatedHeight, size * (1 + (1 - riseAnim)))
		end
	end
end

return {
	drawEnemy = drawEnemy,
	drawEnemies = drawEnemies,
	drawTowerBase = drawTowerBase,
	drawTowerCore = drawTowerCore,
	drawTowerGhost = drawTowerGhost,
	drawTowers = drawTowers,
}