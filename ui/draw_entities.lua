local Constants = require("core.constants")
local Theme = require("core.theme")
local State = require("core.state")
local Util = require("core.util")
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
local colorSlow = Theme.tower.slow
local colorSelected = Theme.ui.selected
local colorGood = Theme.ui.good
local colorBad = Theme.ui.bad

local outlineWidth = Theme.outline.width

local TILE = Constants.TILE

-- Draw a single enemy
local function drawEnemy(e)
	local bounce = sin(e.animT) * (e.slowTimer > 0 and 1 or 2)
	local y = e.y + bounce

	-- Boss horns
	if e.boss then
		lg.setColor(outlineColor)

		local hornW = e.radius * 0.55
		local hornH = e.radius * 0.75
		local hornY = y - e.radius * 1.05
		local hornWob = sin(e.animT * 2.5) * 0.06

		lg.push()
		lg.translate(e.x - e.radius * 0.46, hornY)
		lg.rotate(-0.26 + hornWob)
		lg.polygon("fill", 0, 0, -hornW,  hornH * 0.5, -hornW, -hornH * 0.5)
		lg.pop()

		lg.push()
		lg.translate(e.x + e.radius * 0.46, hornY)
		lg.rotate(0.26 - hornWob)
		lg.polygon("fill", 0, 0, hornW, -hornH * 0.5, hornW,  hornH * 0.5)
		lg.pop()
	end

	local enemyAlpha  = e.alpha
	local shadowAlpha = enemyShadow[4] * (enemyAlpha ^ 1.3)

	-- Shadow
	lg.setColor(enemyShadow[1], enemyShadow[2], enemyShadow[3], shadowAlpha)
	lg.ellipse("fill", e.x, e.y + e.radius, e.radius * 1.1, e.radius * 0.4)

	-- Outline
	lg.setColor(outlineColor[1], outlineColor[2], outlineColor[3], enemyAlpha)
	lg.circle("fill", e.x, y, e.radius + 3)

	-- Body
	lg.setColor(enemyBody[1], enemyBody[2], enemyBody[3], enemyAlpha)
	lg.circle("fill", e.x, y, e.radius)

	-- Hit flash
	if e.hitFlash > 0 then
		local a = min(1, e.hitFlash / 0.05)

		lg.setColor(1.0, 0.95, 0.9, a * 0.35)
		lg.circle("fill", e.x, e.y, e.radius + 1)
	end

	-- Slow overlay
	if e.slowTimer > 0 then
		local pulse = 0.5 + sin(e.animT * 5) * 0.5
		local slowAlpha = (0.18 + pulse * 0.08) * enemyAlpha

		lg.setColor(colorSlow[1], colorSlow[2], colorSlow[3], slowAlpha)
		lg.circle("fill", e.x, y, e.radius - 2)

		lg.setLineWidth(1)
		lg.setColor(colorSlow[1], colorSlow[2], colorSlow[3], 0.35)
		lg.circle("line", e.x, y, e.radius - 1)
	end

	-- Poison overlay
	if e.poisonStacks and e.poisonStacks > 0 then
		local wob = sin(e.animT * 3 + e.poisonStacks) * 0.5
		local intensity = min(0.35, 0.15 + e.poisonStacks * 0.05)
		local poisonAlpha = intensity * (enemyAlpha ^ 0.75)

		lg.setColor(0.35, 0.85, 0.35, poisonAlpha)
		lg.circle("fill", e.x, y + wob, e.radius - 3)
	end

	-- Eyes
	local eyeSep  = e.radius * 0.38
	local eyeSize = max(1.6, e.radius * 0.16)
	local eyeY = y - e.radius * 0.22

	lg.setColor(enemyFace[1], enemyFace[2], enemyFace[3], enemyAlpha)

	if e.boss and e.dying then
		local bigR = eyeSize + 1
		local smallR = max(2, eyeSize - 1)

		local p = 1 - (e.deathT / e.deathDur)
		local pop = 1 + (1 - (p * p)) * 0.15

		lg.push()
		lg.translate(e.x, eyeY)
		lg.scale(pop, pop)

		-- Big shocked eye (outline)
		lg.setLineWidth(3)
		lg.circle("line", -eyeSep, 0, bigR)

		-- Small collapsed eye (fill)
		lg.circle("fill", eyeSep, 0, smallR)

		lg.setLineWidth(1)
		lg.pop()
	elseif e.boss then
		-- Normal boss face
		local browLen = eyeSize * 2.5
		local browDrop = eyeSize * 0.85
		local browTension = sin(e.animT * 1.8) * 0.8
		local browLift = eyeSize * 0.35 -- <-- move brows upward (tune this)
		local browIn = eyeSize * 0.35 -- inward shift (tune 0.15–0.35)

		lg.circle("fill", e.x - eyeSep, eyeY, eyeSize)
		lg.circle("fill", e.x + eyeSep, eyeY, eyeSize)

		lg.setLineWidth(2)
		lg.line(
			e.x - eyeSep - browLen * 0.65 + browIn,
			eyeY - browDrop - browLift,
			e.x - eyeSep + browLen * 0.35 + browIn,
			eyeY - browDrop * 0.15 + browTension - browLift
		)

		lg.line(
			e.x + eyeSep - browLen * 0.35 - browIn,
			eyeY - browDrop * 0.15 + browTension - browLift,
			e.x + eyeSep + browLen * 0.65 - browIn,
			eyeY - browDrop - browLift
		)

		--[[ Boss mouth: grin ↔ laugh animation
		local t = 0.5 + sin(e.animT * 1.2) * 0.5

		local mouthYThin = e.y + e.radius * 0.36
		local mouthYThick = e.y + e.radius * 0.28
		local mouthY = mouthYThin + (mouthYThick - mouthYThin) * t
		local thin = 1 - t
		local thinBias = e.radius * 0.035 * thin * thin
		local outerR = e.radius * 0.56
		local lipOffset = e.radius * 0.10
		local squashY = 0.45 + (0.85 - 0.45) * t

		mouthY = mouthY + thinBias

		lg.push()
		lg.translate(e.x, mouthY - lipOffset)
		lg.scale(1.0, squashY)
		lg.arc("fill", 0, 0, outerR, -pi * 0.02, pi * 1.02)
		lg.pop()]]
	else
		local dx = sin(e.animT * 1.3) * 0.6
		local dy = cos(e.animT * 1.1) * 0.4

		lg.circle("fill", e.x - eyeSep + dx, eyeY + dy, eyeSize)
		lg.circle("fill", e.x + eyeSep + dx, eyeY + dy, eyeSize)
	end

	-- Selection ring
	if State.selectedEnemy == e then
		lg.setColor(colorSelected[1], colorSelected[2], colorSelected[3], 0.25)
		lg.circle("fill", e.x, y, e.radius + 4)

		lg.setColor(colorSelected)
		lg.circle("line", e.x, y, e.radius + 4)
	end

	-- Health bar
	if e.hp > 0 then
		local w = e.boss and 44 or 28
		local h = e.boss and 7 or 5
		local bx = e.x - w / 2
		local by = e.y - e.radius - (e.boss and 18 or 12)

		lg.setColor(0, 0, 0, 0.5)
		lg.rectangle("fill", bx, by, w, h, 3, 3)

		local t = max(0, e.hp / e.maxHp)

		local r, g

		if t > 0.5 then
			local p = (t - 0.5) / 0.5

			r, g = 1 - p, 1
		else
			local p = t / 0.5

			r, g = 1, p
		end

		lg.setColor(r * 0.9 + 0.05, g * 0.9 + 0.05, 0.15, 0.9)
		lg.rectangle("fill", bx, by, w * t, h, 3, 3)
	end
end

-- Draw all enemies + death FX
local function drawEnemies()
	for _, e in ipairs(Enemies.enemies) do
		drawEnemy(e)
	end

	for _, d in ipairs(Enemies.deathFX) do
		local p = d.t / 0.14
		local alpha = (1 - p) * 0.6
		local scale = 1 + p * 0.25

		lg.setColor(1, 1, 1, alpha)
		lg.circle("line", d.x, d.y, d.r * scale)

		lg.setColor(1, 1, 1, alpha * 0.2)
		lg.circle("fill", d.x, d.y, d.r * scale)
	end
end

local function forwardOffset(t, dist)
    return cos(t.angle) * dist, sin(t.angle) * dist
end

local function drawLancerFX(t)
    local a = t.fireAnim
    if a <= 0 then return end

    local fx, fy = forwardOffset(t, TILE * 0.34)

    -- Muzzle flash
    lg.setColor(1, 1, 1, 0.9 * a)
    lg.circle("fill", t.x + fx, t.y + fy, 2)
end

local function drawSlowFX(t)
    local time = getTime()
    local pulse = 0.5 + sin(time * 2) * 0.5

    local r = TILE * (0.45 + pulse * 0.08)

    lg.setLineWidth(3)
    lg.setColor(
        Theme.tower.slow[1],
        Theme.tower.slow[2],
        Theme.tower.slow[3],
        0.6
    )
    lg.circle("line", t.x, t.y, r)

    lg.setLineWidth(1)
end

local function drawPoisonFX(t)
    local time = getTime()
    local wobble = sin(time * 4 + t.x) * 3

    lg.setColor(Theme.tower.poison[1], Theme.tower.poison[2], Theme.tower.poison[3], 0.65)
    lg.circle("fill", t.x + wobble, t.y, TILE * 0.22)

    lg.setColor(0, 0, 0, 0.25)
    lg.circle("line", t.x + wobble, t.y, TILE * 0.22)
end

local function drawShockFX(t)
    local w = t.windUp
    if not w or w <= 0 then return end

    -- This must match drawTowerCore
    local size = TILE * 0.42
    local bodyR = size * 0.36

    -- Wind-up normalization (0 > 1)
    local windDur = 0.08
    local p = 1 - (w / windDur)

    if p < 0 then p = 0 end
    if p > 1 then p = 1 end

    -- Ring geometry
    local stroke = 2 -- 1–2px
    local startR = bodyR - stroke -- inside edge of body
    local endR = 1 -- collapse to center dot

    local r = startR + (endR - startR) * p

    lg.setColor(Theme.tower.shock[1], Theme.tower.shock[2], Theme.tower.shock[3], 1)

    if r > endR + 0.5 then
        lg.setLineWidth(stroke)
        lg.circle("line", t.x, t.y, r)
        lg.setLineWidth(1)
    else
        -- Final collapse
        lg.circle("fill", t.x, t.y, 2)
    end
end

local function drawCannonFX(t)
	local a = t.fireAnim

	if a <= 0 then
		return
	end

	local size = TILE * 0.6
	local fx, fy = forwardOffset(t, size)

	local r = 8 + (1 - a) * 6

	lg.setColor(0.9, 0.9, 0.9, 0.75 * a)
	lg.circle("fill", t.x + fx, t.y + fy, r)
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
    elseif t.kind == "poison" then
        drawPoisonFX(t)
    end
end

-- Draw tower core shape
local function drawTowerCore(kind, cx, cy, opts)
	opts = opts or {}

	local def = Towers.TowerDefs[kind]

	if not def then
		return
	end

	local size = TILE * 0.42
	local color = def.color
	local angle = opts.angle or -math.pi / 2
	local rx = opts.rx or 0
	local ry = opts.ry or 0
	local alpha = opts.alpha or 1
	local tintR = opts.tintR or 1
	local tintG = opts.tintG or 1
	local tintB = opts.tintB or 1
	local shadow = opts.shadow ~= false
	local outlineW = outlineWidth
	local outlineA = alpha
	local bodyA = alpha

	-- Shadow
	if shadow then
		lg.setColor(0, 0, 0, 0.35 * alpha)
		lg.ellipse("fill", cx, cy + size * 0.42, size * 0.85, size * 0.30)
	end

	-- Base
	local baseOuter = size * 0.6 + outlineW * 0.5
	local baseInner = baseOuter - outlineW

	local outerRadius = 6 + outlineW * 0.5
	local innerRadius = 6 - outlineW * 0.25

	lg.setColor(outlineColor[1], outlineColor[2], outlineColor[3], outlineA)
	lg.rectangle("fill", cx - baseOuter, cy - baseOuter, baseOuter * 2, baseOuter * 2, outerRadius, outerRadius)

	lg.setColor(color[1] * tintR, color[2] * tintG, color[3] * tintB, bodyA)
	lg.rectangle("fill", cx - baseInner, cy - baseInner, baseInner * 2, baseInner * 2, innerRadius, innerRadius)

	-- Body + Barrel
	lg.push()
	lg.translate(cx + rx, cy + ry)
	lg.rotate(angle)

	-- Cannon
	if kind == "cannon" then
		local rOuter = size * 0.42 + outlineW * 0.5
		local rInner = rOuter - outlineW
		local barrelH = size * 0.28

		lg.setColor(outlineColor[1], outlineColor[2], outlineColor[3], outlineA)
		lg.circle("fill", 0, 0, rOuter)

		lg.setColor(color[1] * tintR, color[2] * tintG, color[3] * tintB, bodyA)
		lg.circle("fill", 0, 0, rInner)

		lg.setColor(outlineColor[1], outlineColor[2], outlineColor[3], outlineA)
		lg.rectangle("fill", size * 0.26, -barrelH * 0.5, size * 0.54, barrelH, 4, 4)
	-- Slow
	elseif kind == "slow" then
		lg.rotate(math.pi / 4)

		local o = size * 0.34 + outlineW * 0.5
		local i = o - outlineW

		lg.setColor(outlineColor[1], outlineColor[2], outlineColor[3], outlineA)
		lg.rectangle("fill", -o, -o, o * 2, o * 2, 3 + outlineW * 0.5, 3 + outlineW * 0.5)

		lg.setColor(color[1] * tintR, color[2] * tintG, color[3] * tintB, bodyA)
		lg.rectangle("fill", -i, -i, i * 2, i * 2, 3 - outlineW * 0.25, 3 - outlineW * 0.25)
	-- Shock
	elseif kind == "shock" then
		local rOuter = size * 0.36 + outlineW * 0.5
		local rInner = rOuter - outlineW

		lg.setColor(outlineColor[1], outlineColor[2], outlineColor[3], outlineA)
		lg.circle("fill", 0, 0, rOuter)

		lg.setColor(color[1] * tintR, color[2] * tintG, color[3] * tintB, bodyA)
		lg.circle("fill", 0, 0, rInner)
	-- Poison
	elseif kind == "poison" then
		local rOuter = size * 0.38 + outlineW * 0.5
		local rInner = rOuter - outlineW

		lg.setColor(outlineColor[1], outlineColor[2], outlineColor[3], outlineA)
		lg.circle("fill", 0, 0, rOuter)

		lg.setColor(color[1] * tintR, color[2] * tintG, color[3] * tintB, bodyA)
		lg.circle("fill", 0, 0, rInner)

		lg.setColor(outlineColor[1], outlineColor[2], outlineColor[3], outlineA)
		lg.circle("fill", size * 0.26, 0, size * 0.16)
	-- Lancer
	else
		local o = size * 0.35 + outlineW * 0.5
		local i = o - outlineW

		lg.setColor(outlineColor[1], outlineColor[2], outlineColor[3], outlineA)
		lg.rectangle("fill", -o, -o, o * 2, o * 2, 5 + outlineW * 0.5, 5 + outlineW * 0.5)

		lg.setColor(color[1] * tintR, color[2] * tintG, color[3] * tintB, bodyA)
		lg.rectangle("fill", -i, -i, i * 2, i * 2, 5 - outlineW * 0.25, 5 - outlineW * 0.25)

		lg.setColor(outlineColor[1], outlineColor[2], outlineColor[3], outlineA)
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

	lg.setColor(ok and colorGood[1] or colorBad[1], ok and colorGood[2] or colorBad[2], ok and colorGood[3] or colorBad[3], 0.45 * fade)
	lg.circle("line", cx, cy, def.range)

	drawTowerCore(State.placing, cx, cy, {
		alpha = (ok and 0.45 or 0.25) * fade,
		tintR = 1,
		tintG = ok and 1 or 0.4,
		tintB = ok and 1 or 0.4,
		shadow = false,
	})
end

local function drawTowers()
	local selected = State.selectedTower

	if selected then
		local size = TILE * 0.42
		local pad = 2

		lg.setColor(colorSelected[1], colorSelected[2], colorSelected[3], 0.18)
		lg.circle("fill", selected.x, selected.y, selected.range)

		lg.setColor(colorSelected)
		lg.circle("line", selected.x, selected.y, selected.range)

		lg.setLineWidth(2)
		lg.rectangle(
			"line",
			selected.x - size * 0.6 - pad,
			selected.y - size * 0.6 - pad,
			size * 1.2 + pad * 2,
			size * 1.2 + pad * 2,
			6 + pad,
			6 + pad
		)
		lg.setLineWidth(1)
	end

	for _, t in ipairs(Towers.towers) do
		-- Upgrade pips
		local pips = min(8, t.level)
		local anim = t.levelUpAnim or 0
		local pipW, pipH = 3, 4
		local baseY = (t.gy - 1) * TILE + TILE - 11

		for i = 1, pips do
			local isNew = (i == pips) and anim > 0
			local a = 1
			local y = baseY

			if isNew then
				local p = 1 - anim
				local ease = p * p * (3 - 2 * p)
				a = ease
				y = baseY + (1 - ease) * pipH
			end

			lg.setColor(0.92, 0.92, 0.92, a)
			lg.rectangle("fill", (t.gx - 1) * TILE + 10 + (i - 1) * 4, y, pipW, pipH)
		end

		local cx, cy = t.x, t.y
		local dx, dy = 0, -1

		if t.target then
			dx = t.target.x - cx
			dy = t.target.y - cy
			dx, dy = Util.norm(dx, dy)
		end

		local rx = -dx * t.recoil
		local ry = -dy * t.recoil

		drawTowerCore(t.kind, cx, cy, {
			angle = t.angle,
			rx = rx,
			ry = ry,
			alpha = 1,
		})

		if anim > 0 then
			local a = anim
			local size = TILE * 0.42

			lg.setColor(1, 1, 1, a * 0.4)
			lg.circle("line", cx, cy, size * (1 + (1 - a)))
		end
	end
end

return {
	drawEnemy = drawEnemy,
	drawEnemies = drawEnemies,
	drawTowerCore = drawTowerCore,
	drawTowerGhost = drawTowerGhost,
	drawTowers = drawTowers,
}