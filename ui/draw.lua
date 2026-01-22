local Constants = require("core.constants")
local Cursor = require("core.cursor")
local Theme = require("core.theme")
local Hotkeys = require("core.hotkeys")
local Util = require("core.util")
local State = require("core.state")
local MapMod = require("world.map")
local Enemies = require("world.enemies")
local Towers = require("world.towers")
local Projectiles = require("world.projectiles")
local Floaters = require("ui.floaters")
local Waves = require("systems.waves")
local Fonts = require("core.fonts")
local Text = require("ui.text")
local L = require("core.localization")

local lg = love.graphics
local lmr = love.math.random
local pi = math.pi
local min = math.min
local max = math.max
local sin = math.sin
local cos = math.cos
local ceil = math.ceil
local floor = math.floor
local atan2 = math.atan2
local format = string.format
local tinsert = table.insert
local tsort = table.sort
local ipairs = ipairs

local outlineColor = Theme.outline.color
local outlineWidth = Theme.outline.width

local enemyShadow = Theme.enemy.shadow
local enemyBody = Theme.enemy.body
local enemyFace = Theme.enemy.face

local colorGrass = Theme.terrain.grass
local colorPath = Theme.terrain.path
local colorText = Theme.ui.text
local colorGrid = Theme.grid
local colorSlow = Theme.tower.slow
local colorGood = Theme.ui.good
local colorBad = Theme.ui.bad
local colorPanel = Theme.ui.panel
local colorPanel2 = Theme.ui.panel2
local colorSelected = Theme.ui.selected

local zapJitter = 2 -- jitter strength

local tile = Constants.TILE
local gridW = Constants.GRID_W
local gridH = Constants.GRID_H

local shopBumps = {} -- Tower shop affordability animations

local function jitter(amount)
	return (lmr() * 2 - 1) * amount
end

local function wobble(t, amp)
	return sin(t * 6.0) * amp, cos(t * 4.5) * amp
end

local function formatNum(n)
    return tostring(floor(n + 0.5)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

local BAR_W = 64
local BAR_H = 8
local LABEL_W = 44

local function drawStatusBar(label, color, timeLeft, duration, x, y)
	if not timeLeft or timeLeft <= 0 then
		return
	end

	if not duration or duration <= 0 then
		return
	end

	local t = max(0, min(1, timeLeft / duration))

	-- Subtle pulse near expiration
	local pulse = 1

	if t < 0.25 then
		pulse = 0.85 + sin(love.timer.getTime() * 10) * 0.15
	end

	-- Label
	lg.setColor(colorText)
	Text.printShadow(label, x, y)

	-- Bar background
	lg.setColor(0, 0, 0, 0.35)
	lg.rectangle("fill", x + LABEL_W, y + 4, BAR_W, BAR_H, 4, 4)

	-- Bar fill
	lg.setColor(color[1] * pulse, color[2] * pulse, color[3] * pulse, 1)
	lg.rectangle("fill", x + LABEL_W, y + 4, BAR_W * t, BAR_H, 4, 4)

	-- Timer
	lg.setColor(1, 1, 1, 0.85)
	Text.printShadow(L("ui.seconds", timeLeft), x + LABEL_W + BAR_W + 6, y)
end

local function formatModifier(label, value, suffix)
    if not value or value == 1 then return nil end

    local delta = (value - 1) * 100
    local sign = delta > 0 and "+" or "-"
    local pct = math.abs(math.floor(delta + 0.5))

    return ("%s%d%% %s %s"):format(sign, pct, label, suffix)
end

local colorScatterDark = {colorGrass[1] * 0.78, colorGrass[2] * 0.78, colorGrass[3] * 0.78, 0.2}
local colorScatterLight = {colorGrass[1] * 1.12, colorGrass[2] * 1.12, colorGrass[3] * 1.12, 0.2}

local function drawGrassScatter()
	for y = 1, gridH do
		for x = 1, gridW do
			local k = MapMod.makeKey(x, y)

			if not MapMod.map.isPath[k] then
				-- Deterministic hash
				local seed = (x * 127 + y * 331) % 997
				local r = seed % 4

				if r == 0 then
					-- Choose light or dark deterministically
					local useLight = (seed % 7) < 3
					lg.setColor(useLight and colorScatterLight or colorScatterDark)

					for i = 1, 2 do
						local ox = (seed * (13 + i * 17)) % (tile - 8) + 4
						local oy = (seed * (29 + i * 23)) % (tile - 8) + 4

						lg.rectangle(
							"fill",
							(x - 1) * tile + ox,
							(y - 1) * tile + oy,
							6,
							6,
							2
						)
					end
				end
			end
		end
	end
end
local function drawGrid()
	lg.setColor(colorGrass)
	lg.rectangle("fill", 0, 0, gridW * tile, gridH * tile)

	drawGrassScatter()

	-- Path tiles
	for y = 1, gridH do
		for x = 1, gridW do
			local k = MapMod.makeKey(x, y)

			if MapMod.map.isPath[k] then
				lg.setColor(colorPath)
				lg.rectangle("fill", (x - 1) * tile, (y - 1) * tile, tile, tile)
			end
		end
	end

	-- Could add context awareness, animate the grid up when we're in placement mode, fade it out after

	lg.setColor(colorGrid)

	for x = 0, gridW do
		lg.line(x * tile, 0, x * tile, gridH * tile)
	end

	for y = 0, gridH do
		lg.line(0, y * tile, gridW * tile, y * tile)
	end
end

local function drawEnemy(e)
	--local bounce = sin(e.animT) * (e.slowTimer > 0 and 1 or 2)
	--local y = e.y + bounce
	local y = e.y

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

	local enemyAlpha = e.alpha
	local shadowAlpha = enemyShadow[4] * (enemyAlpha ^ 1.3)

	-- Shadow
	lg.setColor(enemyShadow[1], enemyShadow[2], enemyShadow[3], shadowAlpha)
	lg.ellipse("fill", e.x, e.y + e.radius, e.radius * 1.1, e.radius * 0.4)

	-- Outline ring (outer)
	lg.setColor(outlineColor[1], outlineColor[2], outlineColor[3], enemyAlpha)
	lg.circle("fill", e.x, y, e.radius + 3)

	-- Body (inner cutout)
	lg.setColor(enemyBody[1], enemyBody[2], enemyBody[3], enemyAlpha)
	lg.circle("fill", e.x, y, e.radius)

	-- Hit flash
	if e.hitFlash > 0 then
		local a = min(1, e.hitFlash / 0.05)
		lg.setColor(1.0, 0.95, 0.9, a * 0.35)
		lg.circle("fill", e.x, e.y, e.radius + 1)
	end

	-- Slow
	if e.slowTimer > 0 then
		local pulse = 0.5 + sin(e.animT * 5) * 0.5
		local slowAlpha = (0.18 + pulse * 0.08) * enemyAlpha

		lg.setColor(colorSlow[1], colorSlow[2], colorSlow[3], slowAlpha)
		lg.circle("fill", e.x, y, e.radius - 2)

		lg.setLineWidth(1)
		lg.setColor(colorSlow[1], colorSlow[2], colorSlow[3], 0.35)
		lg.circle("line", e.x, y, e.radius - 1)
	end

	-- Poison
	if e.poisonStacks and e.poisonStacks > 0 then
		local wobble = sin(e.animT * 3 + e.poisonStacks) * 0.5
		local intensity = min(0.35, 0.15 + e.poisonStacks * 0.05)
		local poisonAlpha = intensity * (enemyAlpha ^ 0.75)

		lg.setColor(0.35, 0.85, 0.35, poisonAlpha)
		lg.circle("fill", e.x, y + wobble, e.radius - 3)
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
	else
		local eyeDriftX = sin(e.animT * 1.3) * 0.6
		local eyeDriftY = cos(e.animT * 1.1) * 0.4

		lg.circle("fill", e.x - eyeSep + eyeDriftX, eyeY + eyeDriftY, eyeSize)
		lg.circle("fill", e.x + eyeSep + eyeDriftX, eyeY + eyeDriftY, eyeSize)
	end

	-- Selection
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
		local x = e.x - w / 2
		local y = e.y - e.radius - (e.boss and 18 or 12)

		lg.setColor(0, 0, 0, 0.5)
		lg.rectangle("fill", x, y, w, h, 3, 3)

		local t = max(0, e.hp / e.maxHp)

		local r, g

		if t > 0.5 then
			-- Green to Yellow
			local p = (t - 0.5) / 0.5
			r = 1 - p
			g = 1
		else
			-- Yellow to Red
			local p = t / 0.5
			r = 1
			g = p
		end

		lg.setColor(r, g, 0.15, 0.9)
		lg.rectangle("fill", x, y, w * t, h, 3, 3)
	end
end

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

    local fx, fy = forwardOffset(t, tile * 0.34)

    -- Muzzle flash
    lg.setColor(1, 1, 1, 0.9 * a)
    lg.circle("fill", t.x + fx, t.y + fy, 2)
end

local function drawSlowFX(t)
    local time = love.timer.getTime()
    local pulse = 0.5 + sin(time * 2) * 0.5

    local r = tile * (0.45 + pulse * 0.08)

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
    local time = love.timer.getTime()
    local wobble = sin(time * 4 + t.x) * 3

    lg.setColor(
        Theme.tower.poison[1],
        Theme.tower.poison[2],
        Theme.tower.poison[3],
        0.65
    )
    lg.circle("fill", t.x + wobble, t.y, tile * 0.22)

    lg.setColor(0, 0, 0, 0.25)
    lg.circle("line", t.x + wobble, t.y, tile * 0.22)
end

local function drawShockFX(t)
    local w = t.windUp
    if not w or w <= 0 then return end

    -- This MUST match drawTowerCore
    local size = tile * 0.42
    local bodyR = size * 0.36

    -- Wind-up normalization (0 → 1)
    local windDur = 0.08
    local p = 1 - (w / windDur)

    if p < 0 then p = 0 end
    if p > 1 then p = 1 end

    -- Ring geometry
    local stroke = 2 -- 1–2px
    local startR = bodyR - stroke -- inside edge of body
    local endR = 1 -- collapse to center dot

    local r = startR + (endR - startR) * p

    lg.setColor(
        Theme.tower.shock[1],
        Theme.tower.shock[2],
        Theme.tower.shock[3],
        1
    )

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
    if a <= 0 then return end

    local size = tile * 0.6
    local fx, fy = forwardOffset(t, size)

    local r = 8 + (1 - a) * 6

    lg.setColor(0.9, 0.9, 0.9, 0.75 * a)
    lg.circle(
        "fill",
        t.x + fx,
        t.y + fy,
        r
    )
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

local function drawTowerCore(kind, cx, cy, opts)
	opts = opts or {}

	local def = Towers.towerDefs[kind]

	if not def then
		return
	end

	local size = tile * 0.42
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

local function drawTowerGhost()
	if not State.placing or not State.hoverGX or not State.hoverGY then
		return
	end

	local def = Towers.towerDefs[State.placing]

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

	-- Tower ghost
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
		local size = tile * 0.42
		local pad = 2 -- outward expansion

		-- Range highlight
		lg.setColor(colorSelected[1], colorSelected[2], colorSelected[3], 0.18)
		lg.circle("fill", selected.x, selected.y, selected.range)

		lg.setColor(colorSelected)
		lg.circle("line", selected.x, selected.y, selected.range)

		-- Base outline
		lg.setLineWidth(2)
		lg.rectangle("line", selected.x - size * 0.6 - pad, selected.y - size * 0.6 - pad, size * 1.2 + pad * 2, size * 1.2 + pad * 2, 6 + pad, 6 + pad)

		lg.setLineWidth(1)
	end

	-- Towers
	for _, t in ipairs(Towers.towers) do
		local cx = t.x
		local cy = t.y
		local size = tile * 0.42
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

		-- Upgrade pips
		local pips = min(8, t.level)
		lg.setColor(0.92, 0.92, 0.92, 1)

		for i = 1, pips do
			lg.rectangle("fill", (t.gx - 1) * tile + 10 + (i - 1) * 4, (t.gy - 1) * tile + tile - 11, 3, 4)
		end

		-- Level-up pulse
		if t.levelUpAnim and t.levelUpAnim > 0 then
			local a = t.levelUpAnim

			lg.setColor(1, 1, 1, a * 0.4)
			lg.circle("line", cx, cy, size * (1 + (1 - a)))
		end
	end
end

local function drawProjectiles()
	for _, p in ipairs(Projectiles.projectiles) do
		local rotation = 0
		local a = min(1, p.t * 10)

		-- Homing: aim at target (or last known)
		if p.mode == "homing" then
			local dx = (p.lastTX or p.x) - p.x
			local dy = (p.lastTY or p.y) - p.y

			rotation = atan2(dy, dx)
		-- Ground (Cannon): aim at targetted impact point
		elseif p.mode == "ground" then
			local dx = (p.tx or p.x) - p.x
			local dy = (p.ty or p.y) - p.y

			rotation = atan2(dy, dx)
		end

		if p.splash then
			lg.setColor(1, 0.8, 0.4, a)

			lg.push()
			lg.translate(p.x, p.y)
			lg.rotate(rotation)
			lg.rectangle("fill", -8, -4, 16, 8, 4, 4)
			lg.pop()
		elseif p.slow then
			--local speedStretch = min(1.25, 1 + (p.speed or 300) / 600)

			lg.setColor(0.7, 0.85, 1, a)
			lg.push()
			lg.translate(p.x, p.y)
			lg.rotate(rotation + pi / 4)
			lg.rectangle("fill", -4, -4, 8, 8, 2, 2)
			lg.pop()
		elseif p.poison then
			local wx, wy = wobble(p.t or 0, 1.5)

			lg.setColor(0.6, 0.9, 0.5, a)
			lg.circle("fill", p.x + wx, p.y + wy, p.r + 1.5)
		else
			--local speedStretch = min(1.25, 1 + (p.speed or 300) / 600)

			lg.setColor(1, 1, 1, a)
			lg.circle("fill", p.x, p.y, 4)
		end
	end

	-- Cannon splash rings
	for _, s in ipairs(Projectiles.splashes) do
		local t = s.t / s.life

		-- Faster initial expansion, slower fade
		local ease = t * (2 - t)
		local radius = s.r * ease
		local wobble = sin(s.t * 40) * (1 - t) * 1.5

		radius = radius + wobble

		-- Hold brightness briefly, then drop
		local alpha = (1 - t) * 0.85

		if t < 0.15 then
			alpha = 0.9
		end

		-- Faint inner body (adds presence)
		lg.setColor(1, 0.75, 0.45, alpha * 0.25)
		lg.circle("fill", s.x, s.y, radius * 0.92)

		-- Main shock ring
		lg.setLineWidth(3 * (1 - t) + 1)
		lg.setColor(1.0, 0.85, 0.55, alpha)
		lg.circle("line", s.x, s.y, radius)

		-- White flash, Note: add wobble to the explosions for more variable flavor
		if t < 0.05 then
			lg.setColor(1, 1, 1, 0.8)
			lg.circle("fill", s.x, s.y, radius * 0.4)
		end
	end

	lg.setLineWidth(1)

	for _, z in ipairs(Projectiles.zaps) do
		local px, py = z.x, z.y
		local count = #z.chain

		for i, seg in ipairs(z.chain) do
			local t = (i - 1) / count
			local radius = 2 * (1 - t) + 1

			lg.setColor(0.97, 0.97, 0.97, 0.8)
			lg.circle("fill", seg.to.x, seg.to.y, radius) -- Note: Should I jitter this too?

			lg.setLineWidth(2 * (1 - t) + 1)

			local x1 = px + jitter(zapJitter)
			local y1 = py + jitter(zapJitter)
			local x2 = seg.to.x + jitter(zapJitter)
			local y2 = seg.to.y + jitter(zapJitter)

			lg.setColor(0.6, 0.9, 1, 0.9)
			lg.line(x1, y1, x2, y2)

			px, py = seg.to.x, seg.to.y
		end
	end

	lg.setLineWidth(1)
end

local function drawFloaters()
	for _, f in ipairs(Floaters.floaters) do
		local p = f.t / f.life

		-- Ease out upward motion
		local rise = (1 - p) * 10

		-- Alpha curve
		local alpha = (p < 0.2) and 1 or (1 - (p - 0.2) / 0.8)

		-- Pixel snap
		local x = floor(f.x + 0.5)
		local y = floor(f.y - rise + 0.5)

		local text = f.text
		local textW = lg.getFont():getWidth(text)
		local tx = x - textW / 2

		-- Main text
		lg.setColor(f.r, f.g, f.b, alpha)
		Text.printShadow(text, tx, y)
	end
end

local function drawExplosions()
    for _, e in ipairs(Projectiles.explosions) do
        local t = e.t / e.life

        if e.type == "particle" then
            local a = 1 - t
            lg.setColor(1, 0.85, 0.55, a)
            lg.circle("fill", e.x, e.y, e.r * (1 - t * 0.4))

        elseif e.type == "ring" then
            local rr = e.r * (1.2 + t * 1.4)
            lg.setLineWidth(3 * (1 - t) + 1)
            lg.setColor(1, 0.9, 0.6, 0.7 * (1 - t))
            lg.circle("line", e.x, e.y, rr)
        end
    end

    lg.setLineWidth(1)
end

local function drawDamageMeter()
    if not State.stats or not State.stats.showDamageMeter then
        return
    end

    local stats = State.stats
    local isBossView = (stats.damageView == 1)

    local dmgTable = isBossView and stats.bossDamageByTower or stats.damageByTower
    local total = isBossView and stats.bossTotalDamage  or stats.totalDamage

    if not dmgTable then
        return
    end

	-- Sort list
    local list = {}

    for kind, dmg in pairs(dmgTable) do
        if dmg > 0 then
            tinsert(list, {kind = kind, dmg = dmg})
        end
    end

    if #list == 0 then
        return
    end

    tsort(list, function(a, b)
        return a.dmg > b.dmg
    end)

	-- Layout
    local panelW = 200
    local barH = 16
    local lineH = 22
    local padX = 8
    local panelPad = 8

	local sw = Constants.SCREEN_W
    local x = sw - panelW - 12
    local y = 12

    local panelH = 32 + (#list * lineH)

    -- Bar width is constrained by panel width
    local maxBarW = panelW - (padX * 2)

	-- Panel background
    lg.setColor(0, 0, 0, 0.6)
    lg.rectangle("fill", x - panelPad, y - panelPad, panelW + panelPad * 2, panelH, 8, 8)

    -- Header
    lg.setColor(colorText)
    Text.printShadow(isBossView and L("damage.boss") or L("damage.normal"), x, y)

    y = y + 20

    -- Bars
    local font  = lg.getFont()
    local textH = font:getHeight()

    for _, entry in ipairs(list) do
        local def = Towers.towerDefs[entry.kind]

        if def then
			local name = L(def.nameKey)
            local pct = (total > 0) and (entry.dmg / total) or 0
            local text = format("%s  %s (%.0f%%)", name, formatNum(entry.dmg), pct * 100)

            -- Bar background (full width inside panel)
            lg.setColor(def.color[1], def.color[2], def.color[3], 0.25)
            lg.rectangle("fill", x, y, maxBarW, barH, 6, 6)

            -- Filled portion
            lg.setColor(def.color[1], def.color[2], def.color[3], 0.6)
            lg.rectangle("fill", x, y, maxBarW * pct, barH, 6, 6)

            -- Text centered inside bar
            lg.setColor(1, 1, 1, 0.95)
            Text.printShadow(text, x + padX, y + (barH - textH) * 0.5)

            y = y + lineH
        end
    end

    -- Empty boss damage
    if isBossView and total <= 0 then
        lg.setColor(1, 1, 1, 0.6)
        Text.printShadow(L("damage.noneBoss"), x, y + 4)
    end
end

local function drawBossHPBar()
    local boss = State.activeBoss

    if not boss or boss.hp <= 0 then
        return
    end

    -- Layout
    local barW = 340
    local barH = 22

	local sw = Constants.SCREEN_W
    local x = (sw - barW) * 0.5
    local y = 14

    local pad = 4
    local radius = 8

    local hpFrac = max(0, boss.hp / boss.maxHp)

    -- Background frame
    lg.setColor(0, 0, 0, 0.75)
    lg.rectangle("fill", x - pad, y - pad, barW + pad * 2, barH + pad * 2, radius, radius)

    -- HP fill
    lg.setColor(0.75, 0.15, 0.15, 0.9)
    lg.rectangle("fill", x, y, barW * hpFrac, barH, radius - 4, radius - 4)

    --[[ Border
    lg.setColor(1, 1, 1, 0.35)
    lg.rectangle("line", x, y, barW, barH, radius, radius)]]

    -- Text
	local hpText = format("%s / %s", formatNum(ceil(boss.hp)), formatNum(boss.maxHp))

    local font = lg.getFont()
    local textW = font:getWidth(hpText)
    local textH = font:getHeight()

    lg.setColor(1, 1, 1, 0.95)
    Text.printShadow(hpText, x + (barW - textW) * 0.5, y + (barH - textH) * 0.5)
end

local SHOP_W = 520 -- left panel
local COL_W = 120
local HUD_H = 28 -- top strip height
local PAD = 8
local PAD2 = PAD * 2
local GAP = PAD

local ACTION_W = 220 -- matches divider width
local BUTTON_W = (ACTION_W - GAP) / 2
local BUTTON_H = 28

local function drawBottomBar()
	local font = lg.getFont()
	local textH = font:getHeight()
	local sw = Constants.SCREEN_W
	local sh = Constants.SCREEN_H
	local UI_H = Constants.UI_H
	local UI_Y = sh - UI_H

	-- Background panels
	lg.setColor(colorPanel)
	lg.rectangle("fill", 0, UI_Y, sw, UI_H)

	lg.setColor(colorPanel2)
	lg.rectangle("fill", 0, UI_Y, sw, HUD_H)

	lg.setColor(colorPanel)
	lg.rectangle("fill", 0, UI_Y + HUD_H, SHOP_W, UI_H - HUD_H)

	lg.setColor(colorPanel)
	lg.rectangle("fill", SHOP_W, UI_Y + HUD_H, sw - SHOP_W, UI_H - HUD_H)

	lg.setColor(colorPanel2)
	lg.rectangle("line", SHOP_W + 0.5, UI_Y + HUD_H + 0.5, sw - SHOP_W - 1, UI_H - HUD_H - 1)

	-- Top HUD
	local y = UI_Y + floor((HUD_H - textH) * 0.5 + 0.5)

	-- Animation math
	local livesAnim = State.livesAnim or 0
	local livesFlash = livesAnim
	local lp = 1 - (1 - livesAnim) * (1 - livesAnim)
	local livesDrop = floor(lp * 3 + 0.5)

	local waveAnim = State.waveAnim or 0
	local waveFlash = waveAnim
	local wp = 1 - (1 - waveAnim) * (1 - waveAnim)
	local waveLift = floor(wp * 3 + 0.5)

	State.moneyLerp = State.moneyLerp + (State.money - State.moneyLerp) * 0.25

	-- Money text
	lg.setColor(colorText)
	Text.printShadow("$" .. formatNum(floor(State.moneyLerp + 0.5)), 12, y)

	-- Lives text
	local livesX = 90

	lg.setColor(1, 1 - livesFlash * 0.6, 1 - livesFlash * 0.6, 1)
	Text.printShadow(L("hud.lives", State.lives), livesX, y + livesDrop)

	-- Wave text
	local base = 0.85
	local boost = waveFlash * 0.25
	local waveColor = min(1, base + boost) -- Bass boosted wub wub

	lg.setColor(waveColor, waveColor, waveColor, 0.85)
	Text.printShadow(L("hud.wave", State.wave), 170, y - waveLift)

	if State.inPrep then
		lg.setColor(colorGood)
		Text.printShadow(L("hud.prep", State.prepTimer), 260, y)
	else
		local spawner = Waves.getSpawner()

		lg.setColor(0.85, 0.85, 0.85, 0.85)
		Text.printShadow(L("hud.spawning", spawner.remaining, #Enemies.enemies), 260, y)
	end

	-- Tower shop
	local shopX = PAD
	local shopY = UI_Y + HUD_H + PAD

	local btnW, btnH = 124, 32
	local cols = floor((SHOP_W - PAD * 2) / (btnW + GAP))
	local i = 0

	for _, key in ipairs(Towers.shopOrder) do
		local def = Towers.towerDefs[key]
		local hotkey = Hotkeys.getShopKey(key)

		local col = i % cols
		local row = floor(i / cols)

		local x = shopX + col * (btnW + GAP)
		local y = shopY + row * (btnH + GAP)

		local selected = State.placing == key
		local canAfford = State.money >= def.cost
		local pulse = selected and (0.9 + sin(love.timer.getTime() * 6) * 0.1) or 1
		local base = selected and colorSelected or colorGrid

		-- Detect transition: unaffordable -> affordable
		local bump = shopBumps[key]
		local bumpPad = 0

		if not bump then
			bump = {t = 0, active = false, wasAffordable = canAfford}
			shopBumps[key] = bump
		end

		-- Trigger bump
		if canAfford and not bump.wasAffordable then
			bump.t = 0
			bump.active = true
		end

		bump.wasAffordable = canAfford

		if bump.active then
			bump.t = bump.t + love.timer.getDelta() * 8 -- speed

			if bump.t >= 1 then
				bump.t = 1
				bump.active = false
			end

			-- Ease out (quick expand, gentle settle)
			local p = bump.t
			local ease = p * p * (3 - 2 * p)

			bumpPad = ease * 1 -- 1px per edge
		end

		lg.setColor(base[1] * pulse, base[2] * pulse, base[3] * pulse, 1)
		lg.rectangle("fill", x - bumpPad, y - bumpPad, btnW + bumpPad * 2, btnH + bumpPad * 2, 6 + bumpPad, 6 + bumpPad)

		-- Disabled overlay if unaffordable
		if not canAfford then
			lg.setColor(0, 0, 0, 0.35)
			lg.rectangle("fill", x, y, btnW, btnH, 6, 6)
		end

		local ty = y + (btnH - textH) * 0.5

		-- Name
		local towerName = L(def.nameKey)
		local textX = x + PAD
		local colorAfford = canAfford and colorText or colorBad

		if hotkey then
			-- Hotkey
			local hkText = "[" .. hotkey:upper() .. "] "

			lg.setColor(colorAfford[1], colorAfford[2], colorAfford[3], 0.85)
			Text.printShadow(hkText, textX, ty)

			-- Name
			local hkW = lg.getFont():getWidth(hkText .. " ")

			lg.setColor(colorAfford)
			Text.printShadow(towerName, textX + hkW, ty)
		else
			-- Name only
			lg.setColor(colorAfford)
			Text.printShadow(towerName, textX, ty)
		end

		-- Cost
		lg.setColor(colorAfford)
		Text.printfShadow("$" .. def.cost, x + PAD, ty, btnW - PAD2, "right")

		i = i + 1
	end

	-- Inspect panel
	local inspectX = SHOP_W + PAD
	local inspectY = UI_Y + HUD_H + PAD
	local rightColX = inspectX + COL_W + 32
	local statsY = inspectY + 18
	local lineH = 16
	local actionX = inspectX
	local actionY = statsY + lineH * 2 + 14
	local sellX = actionX + BUTTON_W + GAP

	if State.selectedTower then
		local t = State.selectedTower
		local towerName = L(t.def.nameKey)

		-- Name and level
		lg.setColor(colorText)
		Text.printShadow(L("inspect.towerTitle", towerName, t.level), inspectX, inspectY)

		-- Divider
		lg.setColor(1, 1, 1, 0.15)
		lg.line(inspectX, inspectY + 16, inspectX + 220, inspectY + 16)

		-- Stats
		lg.setColor(colorText)
		Text.printShadow(L("inspect.damage", formatNum(t.damageDealt)), inspectX, statsY)
		Text.printShadow(L("inspect.kills", t.kills), inspectX, statsY + lineH)

		-- Upgrade Button
		local upgradeCost = Towers.towerUpgradeCost(t)
		local canUpgrade = State.money >= upgradeCost
		local upgradeKey = Hotkeys.getActionKey("upgrade")
		local colorUpgrade = canUpgrade and colorText or colorBad
		local tyBtn = actionY + (BUTTON_H - textH) * 0.5

		-- Background
		lg.setColor(colorGrid)
		lg.rectangle("fill", actionX, actionY, BUTTON_W, BUTTON_H, 6, 6)

		-- Text
		local ux = actionX + PAD

		if upgradeKey then
			local hkText = L("ui.hotkey", upgradeKey:upper())

			-- Hotkey
			lg.setColor(colorUpgrade[1], colorUpgrade[2], colorUpgrade[3], 0.85)
			Text.printShadow(hkText, ux, tyBtn)

			-- Label
			local hkW = lg.getFont():getWidth(hkText .. " ")
			lg.setColor(colorUpgrade)
			Text.printShadow(L("actions.upgrade"), ux + hkW, tyBtn)
		else
			lg.setColor(colorUpgrade)
			Text.printShadow(L("actions.upgrade"), ux, tyBtn)
		end

		-- Cost
		lg.setColor(colorUpgrade)
		Text.printfShadow("$" .. upgradeCost, actionX + PAD, tyBtn, BUTTON_W - PAD2, "right")

		-- Sell Button
		local sellKey = Hotkeys.getActionKey("sell")
		local sellValue = t.sellValue or 0
		local sx = sellX + PAD

		-- Background
		lg.setColor(colorGrid)
		lg.rectangle("fill", sellX, actionY, BUTTON_W, BUTTON_H, 6, 6)

		-- Text
		if sellKey then
			local hkText = "[" .. sellKey:upper() .. "] "

			-- Hotkey
			lg.setColor(colorGood[1], colorGood[2], colorGood[3], 0.85)
			Text.printShadow(hkText, sx, tyBtn)

			-- Label
			local hkW = lg.getFont():getWidth(hkText .. " ")
			lg.setColor(colorGood)
			Text.printShadow(L("actions.sell"), sx + hkW, tyBtn)
		else
			lg.setColor(colorGood)
			Text.printShadow(L("actions.sell"), sx, tyBtn)
		end

		-- Value
		lg.setColor(colorGood)
		Text.printfShadow("+$" .. sellValue, sellX + PAD, tyBtn, BUTTON_W - PAD2, "right")
	elseif State.selectedEnemy then
		local e = State.selectedEnemy

		local hpY = inspectY + 18
		local statusY = inspectY + 38

		-- Name
		lg.setColor(colorText)
		Text.printShadow(L(e.def.nameKey), inspectX, inspectY)

		-- Divider
		lg.setColor(1, 1, 1, 0.15)
		lg.line(inspectX, inspectY + 16, inspectX + 220, inspectY + 16)

		lg.setColor(colorText)
		Text.printShadow(L("inspect.hp", formatNum(e.hp), formatNum(e.maxHp)), inspectX, hpY)

		-- Status effects
		local statusY = hpY + 16

		if e.slowTimer and e.slowTimer > 0 then
			drawStatusBar(L("status.slow"), Theme.tower.slow, e.slowTimer, e.slowDuration, inspectX, statusY)
			statusY = statusY + 16
		end

		if e.poisonStacks and e.poisonStacks > 0 then
			drawStatusBar(L("status.poison"), Theme.tower.poison, e.poisonTimer, e.poisonDuration, inspectX, statusY)
			statusY = statusY + 16
		end

		-- Modifiers (resistances / vulnerabilities)
		if e.modifiers then
			local modLines = {}
			local slowLine = formatModifier(L("status.slow"), e.modifiers.slow, L("modifier.effect"))
			local poisonLine = formatModifier(L("status.poison"), e.modifiers.poison, L("modifier.damage"))

			if slowLine then
				tinsert(modLines, slowLine)
			end

			if poisonLine then
				tinsert(modLines, poisonLine)
			end

			lg.setColor(colorText)

			if #modLines > 0 then
				Text.printShadow(L("inspect.modifiers"), rightColX, hpY)

				for i, line in ipairs(modLines) do
					Text.printShadow(line, rightColX, hpY + i * 16)
				end
			end
		end
	end
end

local function drawWorld()
	drawGrid()
	drawTowerGhost()
	drawTowers()
	drawEnemies()
	drawProjectiles()
	drawExplosions()

	Fonts.set("floaters")

	drawFloaters()
end

local function drawUI()
	Fonts.set("ui")

	drawBottomBar()
	drawBossHPBar()
	drawDamageMeter()
end

return {
	drawWorld = drawWorld,
	drawUI = drawUI,

	-- Only exposed for art export
	drawTowerCore = drawTowerCore,
	drawEnemy = drawEnemy,
}