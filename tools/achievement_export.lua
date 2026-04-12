local EnemyDefs = require("world.enemy_defs")
local DrawEntities = require("render.draw_entities")
local Medals = require("ui.medals")
local Theme = require("core.theme")
local Fonts = require("core.fonts")
local Text = require("ui.text")
local Enemies = require("world.enemies")
local Projectiles = require("world.projectiles")
local Effects = require("world.effects")
local Spatial = require("world.spatial_grid")
local Shock = require("world.shock")
local Towers = require("world.towers")
local TowerDefs = require("world.tower_defs")
local Constants = require("core.constants")

--[[
	Art concepts
	pad lock
	tomb stone (RIP)
	shield
	hourglass
--]]

local Export = {}
local lg = love.graphics

local pi = math.pi -- Why am I optimizing a render script
local max = math.max
local rad = math.rad

local SIZE = 256
local REF_ICON_SIZE = 64
local TOWER_SCALE = (SIZE / REF_ICON_SIZE) * 1.5 -- 1.5 scale
local ENEMY_SCALE = (SIZE / REF_ICON_SIZE) * 1.5 -- 1.0 scale
local MEDAL_SCALE = (SIZE / REF_ICON_SIZE) * 1.5 -- 1.0 scale

local EXPORT_DIR = "export"
local ACH_DIR = EXPORT_DIR .. "/achievements"

local colorFace = Theme.enemy.face
local colorBody = Theme.enemy.body
local colorText = Theme.ui.text

local tiers = {
	[1] = "bronze",
	[2] = "silver",
	[3] = "gold",
}

local roman = {
	[1] = "I",
	[2] = "II",
	[3] = "III",
}

local ribbonColors = {
	[1] = {0.18, 0.42, 0.26}, -- bronze (green)
	[2] = {0.22, 0.40, 0.78}, -- silver (blue)
	[3] = {0.62, 0.16, 0.18}, -- gold (red)
}

local function drawMedalRibbons(cx, cy, radius, tier)
	local visualRadius = radius * MEDAL_SCALE

	local ribbonLen = visualRadius * 2.4
	local ribbonW = visualRadius * 0.72 -- thicker (was 0.56)
	local angle = rad(26)

	local attachY = cy - visualRadius * 0.52
	local attachOffsetX = visualRadius * 0.34

	local fillColor = ribbonColors[tier]
	local outlineColor = Theme.outline.color

	local outlineW = Theme.outline.width * MEDAL_SCALE

	local function ribbon(x, y, ang)
		lg.push()
		lg.translate(x, y)
		lg.rotate(ang)

		-- outline
		lg.setColor(outlineColor)
		lg.rectangle("fill", -ribbonW * 0.5 - outlineW, -ribbonLen, ribbonW + outlineW * 2, ribbonLen + outlineW * 2, 4)

		-- fill
		lg.setColor(fillColor)
		lg.rectangle("fill", -ribbonW * 0.5, -ribbonLen + outlineW, ribbonW, ribbonLen, 3)

		-- center stripe (subtle contrast)
		local stripeW = ribbonW * 0.28

		lg.setColor(fillColor[1] * 0.7, fillColor[2] * 0.7, fillColor[3] * 0.7, 1)

		lg.rectangle("fill", -stripeW * 0.5, -ribbonLen + outlineW, stripeW, ribbonLen, 2)

		lg.pop()
	end

	ribbon(cx - attachOffsetX, attachY, -angle)
	ribbon(cx + attachOffsetX, attachY, angle)
end

local function drawCampaignMedal(tier)
	local cx = SIZE * 0.5
	local cy = SIZE * 0.60
	local radius = 12

	lg.push()
	lg.origin()

	-- ribbons
	drawMedalRibbons(cx, cy, radius, tier)

	-- medal
	Medals.drawTier(cx, cy, tier, radius, MEDAL_SCALE)

	lg.pop()
end

local function ensureDirs()
    love.filesystem.createDirectory(EXPORT_DIR)
    love.filesystem.createDirectory(ACH_DIR)
end

local function beginCanvas()
    local canvas = lg.newCanvas(SIZE, SIZE, {msaa = 8})
    lg.setCanvas(canvas)
    lg.clear(0, 0, 0, 0)

    return canvas
end

local function finishCanvas()
    lg.setCanvas()
end

local function savePNG(canvas, path)
    local data = canvas:newImageData()

    data:encode("png", path .. ".png")
end

local function centerAndScale(fn, scale, adjusty)
	adjusty = adjusty or 0

    lg.push()

    lg.translate(SIZE * 0.5, SIZE * 0.5 + adjusty)
    lg.scale(scale, scale)
    fn()

    lg.pop()
end

local function drawDroplet(cx, cy, r, tier)
	local outlineW = Theme.outline.width
	local darkMul = Theme.lighting.shadowMul
	local highlightOffset = Theme.lighting.highlightOffset
	local highlightScale = Theme.lighting.highlightScale

	local fr, fg, fb = 0.72, 0.88, 0.96

	if tier == 1 then
		fr, fg, fb = 0.72, 0.88, 0.96
	else
		fr, fg, fb = 0.96, 0.38, 0.32
	end

	local or_, og, ob = unpack(Theme.outline.color)

	-- Shape
	local bodyR = r * 0.64
	local circleY = cy + r * 0.18
	local baseY = circleY - bodyR * 0.25
	local outerBaseY = baseY - outlineW

	local tipY = cy - r * 1.05
	local halfW = bodyR * 0.80

	-- Triangle points (inner)
	local ax, ay = cx, tipY
	local bx, by = cx - halfW, baseY
	local cx2, cy2 = cx + halfW, baseY

	-- Outer triangle
	local function expandTriangle(ax, ay, bx, by, cx, cy, amount)
		local function perp(x1, y1, x2, y2)
			local dx, dy = x2 - x1, y2 - y1
			local len = math.sqrt(dx*dx + dy*dy)
			if len == 0 then return 0, 0 end
			return -dy / len, dx / len
		end

		local nx1, ny1 = perp(ax, ay, bx, by)
		local nx2, ny2 = perp(bx, by, cx, cy)
		local nx3, ny3 = perp(cx, cy, ax, ay)

		return
			ax + (nx1 + nx3) * amount, ay + (ny1 + ny3) * amount,
			bx + (nx1 + nx2) * amount, by + (ny1 + ny2) * amount,
			cx + (nx2 + nx3) * amount, cy + (ny2 + ny3) * amount
	end

	local outerAx, outerAy, outerBx, outerBy, outerCx, outerCy = expandTriangle(ax, ay, cx - halfW, outerBaseY, cx + halfW, outerBaseY, outlineW * 2)

	local outerR = bodyR + outlineW * 0.5
	local maxHalfW = outerR * 0.98

	local function clampX(x)
		return math.max(cx - maxHalfW, math.min(cx + maxHalfW, x))
	end

	outerBx = clampX(outerBx)
	outerCx = clampX(outerCx)

	local innerR = outerR - outlineW

	-- Outline
	lg.setColor(or_, og, ob)

	lg.circle("fill", cx, circleY, outerR)

	lg.polygon("fill",
		outerAx, outerAy,
		outerBx, outerBy,
		outerCx, outerCy
	)

	-- Inner
	lg.setColor(fr * darkMul, fg * darkMul, fb * darkMul)

	lg.circle("fill", cx, circleY, innerR)

	lg.polygon("fill",
		ax, ay,
		bx, by,
		cx2, cy2
	)

	-- Highlight
	local hy = circleY - innerR * highlightOffset - 1

	lg.setColor(fr, fg, fb)
	lg.circle("fill", cx, hy, innerR * highlightScale)

	lg.push()
	lg.translate(cx, hy)
	lg.scale(highlightScale, highlightScale)

	lg.polygon("fill",
		0, tipY - circleY,
		-halfW, baseY - circleY,
		halfW, baseY - circleY
	)

	lg.pop()
end

local function drawNoSymbol(cx, cy, r)
	local thickness = r * 0.18
	local len = r * 2.2

	lg.setColor(Theme.outline.color)

	lg.push()
	lg.translate(cx, cy)
	lg.rotate(rad(45))

	lg.rectangle("fill",
		-len * 0.5,
		-thickness * 0.5,
		len,
		thickness,
		thickness * 0.5,
		thickness * 0.5
	)

	lg.pop()
end

local function drawNoLeaksIcon(tier)
	local REF_RADIUS = 18

	centerAndScale(function()
		drawDroplet(0, 0, REF_RADIUS, tier)
		drawNoSymbol(0, 0, REF_RADIUS)
	end, TOWER_SCALE, 22)
end

local function drawTower(kind)
	centerAndScale(function()
		DrawEntities.drawTowerVisual(kind, 0, 0, -pi / 4, 0, 1)
	end, TOWER_SCALE)
end

local function getShockOrigin(t)
	local size = Constants.TILE * 0.42
	local tipX = size * 0.40

	local localX = tipX - (t.recoil or 0)
	local localY = 0

	local ca = math.cos(t.angle)
	local sa = math.sin(t.angle)

	local worldX = t.x + (localX * ca - localY * sa)
	local worldY = t.renderY + (localX * sa + localY * ca)

	return worldX, worldY
end

local function drawTowerAction(kind)
	-- === Reset systems ===
	Towers.clear()
	Enemies.enemies = {}
	Projectiles.clear()
	Effects.clear()

	-- === Create enemy ===
	local angle = -math.pi / 4
	local dist = 80

	-- Burning random to get a better shock chain since the game is deterministic
	love.math.random()

	local enemy = {
		x = math.cos(angle) * dist,
		y = math.sin(angle) * dist,
		hp = 100,
		maxHp = 100,
		radius = 10,
		dist = 100,
		speed = 0,
		dying = false,
		alpha = 1,
		prevX = 0,
		prevY = 0,
		hitFlash = 0,
		hitVelX = 0,
		hitVelY = 0,
	}

	enemy.prevX = enemy.x
	enemy.prevY = enemy.y

	Spatial.updateEnemy(enemy)
	Enemies.enemies = {enemy}

	-- === Create REAL tower (important) ===
	local def = Towers.TowerDefs[kind]

	local t = {
		kind = kind,
		def = def,

		x = 0,
		y = 0,
		renderY = 0,

		-- required animation fields
		height = 0,
		prevHeight = 0,
		spawnAnim = 0,
		levelUpAnim = 0,

		range = def.range,
		range2 = def.range * def.range,

		fireRate = def.fireRate,
		fireInterval = 1 / def.fireRate,

		damage = def.damage,
		projSpeed = def.projSpeed,

		fireAnim = 1, -- full flash
		recoil = def.recoilStrength or 0, -- full kickback
		cooldown = def.fireInterval, -- just fired
		recoilStrength = def.recoilStrength or 0,
		recoilDecay = def.recoilDecay or 18,

		windUp = 0,
		charge = 1,

		damageDealt = 0,

		angle = -math.pi / 4,
		target = nil,
		retargetT = 0,

		canRotate = def.canRotate ~= false,
		turnSpeed = def.turnSpeed or 12,

		-- behaviors
		slow   = def.onHitSlow and {factor = def.onHitSlow.factor, dur = def.onHitSlow.dur} or nil,
		splash = def.splash and {radius = def.splash.radius, falloff = def.splash.falloff} or nil,
		chain  = def.chain and {jumps = def.chain.jumps, radius = def.chain.radius, falloff = def.chain.falloff} or nil,
		poison = def.poison and {dps = def.poison.dps, dur = def.poison.dur, maxStacks = def.poison.maxStacks} or nil,
		plasma = def.plasma and {radius = def.plasma.radius, tickRate = def.plasma.tickRate} or nil,
	}

	Towers.towers = {t}

	--[[if not t.chain then
		--Projectiles.spawn(t, enemy)
	else
		local zapOrder = Shock.fire(t, enemy)

		if zapOrder and #zapOrder > 0 then
			local mx, my = getShockOrigin(t)

			Effects.spawnZapEffect(mx, my, zapOrder)
		end
	end]]

	local dt = 1 / 120

	for i = 1, 6 do
		Towers.updateTowers(dt)
		--Projectiles.update(dt)
		Effects.update(dt)
	end

	-- === DRAW ===
	centerAndScale(function()
		DrawEntities.drawTowerVisual(t.kind, 0, 0, t.angle, t.recoil, 1)
		DrawEntities.drawTowerFX(t)
		--Projectiles.draw()

		if t.chain then
			Effects.draw()
		end
	end, TOWER_SCALE)
end

local function drawDeadEyes(radius)
	local cx = 0
	local cy = 0

	local eyeSep = radius * 0.38
	local eyeSize = max(1.6, radius * 0.16)
	local eyeY = cy - radius * 0.19

	local armLen = eyeSize * 2.2
	local armThick = eyeSize * 1.2

	local wipeW = eyeSize * 4.2
	local wipeH = eyeSize * 2.6

	local function wipeEye(x, y)
		lg.setColor(colorBody)
		lg.rectangle("fill", x - wipeW * 0.5, y - wipeH * 0.5, wipeW, wipeH, wipeH * 0.4)
	end

	local function drawX(x, y)
		lg.push()
		lg.translate(x, y)
		lg.rotate(pi / 4)
		lg.rectangle("fill", -armLen, -armThick * 0.5, armLen * 2, armThick, armThick * 0.45)
		lg.pop()

		lg.push()
		lg.translate(x, y)
		lg.rotate(-pi / 4)
		lg.rectangle("fill", -armLen, -armThick * 0.5, armLen * 2, armThick, armThick * 0.45)
		lg.pop()
	end

	-- Wipe original eyes first
	wipeEye(cx - eyeSep, eyeY)
	wipeEye(cx + eyeSep, eyeY)

	-- Then draw X eyes
	lg.setColor(colorFace) -- or outlineColor if that's your eye color
	drawX(cx - eyeSep, eyeY)
	drawX(cx + eyeSep, eyeY)
end

local function drawPoppedEyes(radius, t)
	local cx = 0
	local cy = 0

	local eyeSep = radius * 0.38
	local eyeSize = math.max(1.6, radius * 0.16)
	local eyeY = cy - radius * 0.19

	-- wipe area (same idea as dead eyes)
	local wipeW = eyeSize * 4.2
	local wipeH = eyeSize * 2.6

	local function wipeEye(x, y)
		lg.setColor(colorBody)
		lg.rectangle("fill", x - wipeW * 0.5, y - wipeH * 0.5, wipeW, wipeH, wipeH * 0.4)
	end

	-- 🔥 wipe BOTH original eyes first
	wipeEye(cx - eyeSep, eyeY)
	wipeEye(cx + eyeSep, eyeY)

	-- fake "pop" progression
	t = t or 1
	local pop = 1 + (1 - (t * t)) * 0.18

	local bigR = eyeSize + 1.1
	local smallR = eyeSize * 0.9

	lg.push()
	lg.translate(cx, eyeY)
	lg.scale(pop, pop)

	-- LEFT EYE = POPPED
	lg.setLineWidth(2.5)

	lg.setColor(0.95, 0.95, 0.95, 1)
	lg.circle("fill", -eyeSep, 0, bigR)

	lg.setColor(colorFace)
	lg.circle("line", -eyeSep, 0, bigR)

	-- RIGHT EYE = NORMAL
	lg.setLineWidth(1)
	lg.setColor(colorFace)
	lg.circle("fill", eyeSep, 0, smallR)

	lg.pop()
end

local function drawEnemy(kind, isDead, fakeEyes, popped)
    local def = EnemyDefs[kind]

    local enemy = {
        kind = kind,
        def = def,
        x = 0,
        y = 0,
		prevX = 0,
		prevY = 0,
		rx = 0,
		ry = 0,
		prevRX = 0,
		prevRY = 0,
        boss = def.boss or false,

        hp = 0,
        maxHp = def.hp or 1,
        baseSpeed = def.speed,
        speed = def.speed,
        reward = def.reward,
        score = def.score,

        radius = def.radius,
        split = def.split,

        alpha = 1,
        animT = 0,
		prevAnimT = 0,
		dist = 0,
		prevDist = 0,
		seg = 1,
		prevSeg = 1,

        hitFlash = hitFlash or 0,
        dying = isDead,
        deathDur = 0.3,
        deathT = isDead and 0.3 or 0,

        spawnFade = 0,
        exitFade = nil,
        modifiers = def.modifiers,

        slowFactor = 1,
        slowTimer = 0,
        poisonStacks = 0,
        poisonTimer = 0,
        poisonDPS = 0,
    }

    centerAndScale(function()
        DrawEntities.drawEnemy(enemy)

		if fakeEyes then
			drawDeadEyes(enemy.radius)
		elseif popped then
			drawPoppedEyes(enemy.radius, 0.6)
		end

        lg.setColor(1, 1, 1, 1)
    end, ENEMY_SCALE, 5)
end

-- Kill Tier Achievement Export
local function drawKillTier(enemyType, isDead, fakeEyes, popped)
	drawEnemy(enemyType, isDead, fakeEyes, popped)

	lg.push()
	lg.origin()
	lg.pop()
end

-- Just a fake entry that we can spawn
TowerDefs.upgrade_1 =  {
	nameKey = "tower.cannon",
	descKey = "towerDesc.cannon",
	cost = 65,
	range = 3.2 * Constants.TILE,
	fireRate = 0.85,
	damage = 19,
	recoilStrength = Constants.TILE * 0.12,
	recoilDecay = 14,
	projSpeed = 320,
	turnSpeed = 8,
	color = Theme.ui.good,
	canRotate = true,
}

TowerDefs.upgrade_100 =  {
	nameKey = "tower.cannon",
	descKey = "towerDesc.cannon",
	cost = 65,
	range = 3.2 * Constants.TILE,
	fireRate = 0.85,
	damage = 19,
	recoilStrength = Constants.TILE * 0.12,
	recoilDecay = 14,
	projSpeed = 320,
	turnSpeed = 8,
	color = Theme.medal.gold,
	canRotate = true,
}

local function drawTowerUpgradeIcon(kind, level)
	local REF_SIZE = 18

	centerAndScale(function()
		local cx, cy = 0, 0

		local level = level or 1
		local height = (level - 1) * 4

		-- Dark extruded base
		DrawEntities.drawTowerBase(kind, cx, cy, 1, 0.2, 0.2, 0.2, height)

		DrawEntities.drawTowerVisual(kind, cx, cy - height, 1)

		-- Arrow
		local arrowH = REF_SIZE * 1.2
		local arrowW = REF_SIZE * 0.6

		local shaftW = arrowW * 0.35
		local shaftH = arrowH * 0.75
		local tipH = arrowH * 0.45

		local ay = cy
		local verticalOffset = -height -- -height?
		local overlap = tipH * 0.45

		lg.setColor(Theme.outline.color)

		-- Shaft
		lg.rectangle("fill", cx - shaftW * 0.5, ay - shaftH * 0.5 + verticalOffset, shaftW, shaftH, 2, 2)

		-- Arrow head using rounded rectangles
		local headLen = tipH
		local headW = shaftW

		local tipX = cx
		local tipY = ay - shaftH * 0.5 + verticalOffset

		local inward = headW - 5

		for i = -1, 1, 2 do
			lg.push()

			lg.translate(tipX, tipY)
			lg.rotate(i * math.pi / 4)
			lg.translate(-i * inward, 0)

			lg.rectangle("fill", -headW * 0.5, 0, headW, headLen, 2, 2)

			lg.pop()
		end

	end, TOWER_SCALE, level == 3 and 24 or 10)
end

local function drawStopwatchIcon()
	local REF_RADIUS = 14
	local outlineW = Theme.outline.width

	local outlineColor = Theme.outline.color
	local lighting = Theme.lighting
	local darkMul = lighting.shadowMul
	local highlightOffset = lighting.highlightOffset
	local highlightScale = lighting.highlightScale

	local faceR, faceG, faceB = 0.90, 0.90, 0.88

	centerAndScale(function()
		local cx, cy = 0, 0
		local r = REF_RADIUS

		-- =================================
		-- TOP CROWN (FIXED ATTACHMENT)
		-- =================================
		do
			local crownW = r * 0.64
			local crownH = r * 0.30

			local stemH = r * 0.38
			local stemW = r * 0.25

			-- push slightly INTO circle so it connects
			local stemTop = cy - r + 1

			lg.setColor(outlineColor)

			-- stem
			lg.rectangle("fill",
				cx - stemW * 0.5,
				stemTop - stemH,
				stemW,
				stemH,
				0, 0
			)

			-- crown block
			lg.rectangle("fill",
				cx - crownW * 0.5,
				stemTop - stemH - crownH + 1,
				crownW,
				crownH,
				2, 2
			)
		end

		-- =================================
		-- FLOATING SIDE BUTTON (NO ARM)
		-- =================================
		do
			local btnW = r * 0.42
			local btnH = r * 0.25

			local angle = math.rad(45)

			-- Position near top-right of the stopwatch
			local bx = cx + r * 0.95
			local by = cy - r * 0.91

			lg.setColor(outlineColor)

			lg.push()
			lg.translate(bx, by)
			lg.rotate(angle)

			lg.rectangle("fill",
				-btnW * 0.5,
				-btnH * 0.5,
				btnW,
				btnH,
				2, 2
			)

			lg.pop()
		end

		-- =================================
		-- FLOATING SIDE BUTTON (NO ARM)
		-- =================================
		do
			local btnW = r * 0.42
			local btnH = r * 0.25

			local angle = math.rad(135)

			-- Position near top-right of the stopwatch
			local bx = cx - r * 0.95
			local by = cy - r * 0.91

			lg.setColor(outlineColor)

			lg.push()
			lg.translate(bx, by)
			lg.rotate(angle)

			lg.rectangle("fill",
				-btnW * 0.5,
				-btnH * 0.5,
				btnW,
				btnH,
				2, 2
			)

			lg.pop()
		end

		-- Body
		lg.setColor(outlineColor)
		lg.circle("fill", cx, cy, r + outlineW)

		lg.setColor(faceR * darkMul, faceG * darkMul, faceB * darkMul)
		lg.circle("fill", cx, cy, r)

		local hx = cx
		local hy = cy - r * highlightOffset
		local hr = r * highlightScale

		lg.setColor(faceR, faceG, faceB)
		lg.circle("fill", hx, hy, hr)

		-- =================================
		-- HANDS
		-- =================================
		do
			local minuteLen = r * 0.70
			local minuteW = 3.5

			local secondLen = r * 0.9
			local secondW = 3.5

			local minuteAngle = math.rad(280)
			local secondAngle = math.rad(45)

			lg.setColor(outlineColor)

			-- Minute hand
			lg.push()
			lg.translate(cx, cy)
			lg.rotate(minuteAngle)
			lg.rectangle("fill", -minuteW * 0.5, -minuteLen + 2, minuteW, minuteLen, 2, 2)
			lg.pop()

			-- Second hand
			lg.push()
			lg.translate(cx, cy)
			lg.rotate(secondAngle)
			lg.rectangle("fill", -secondW * 0.5, -secondLen + 2, secondW, secondLen, 2, 2)
			lg.pop()

			-- Center pin
			lg.circle("fill", cx, cy, 2.5)
		end

	end, TOWER_SCALE, 15)
end

local function drawPadlock(cx, cy, r, color)
	local outlineW = Theme.outline.width
	local outlineColor = Theme.outline.color

	local lighting = Theme.lighting
	local darkMul = lighting.shadowMul
	local highlightOffset = lighting.highlightOffset
	local highlightScale = lighting.highlightScale

	local fr, fg, fb = color[1], color[2], color[3]

	-- =========================
	-- BODY (smaller, tighter)
	-- =========================

	local bodyW = r * 1.2
	local bodyH = r * 0.9
	local bodyX = cx - bodyW * 0.5
	local bodyY = cy + r * 0.2

	local radius = r * 0.28

	-- Outline
	lg.setColor(outlineColor)
	lg.rectangle("fill",
		bodyX - outlineW,
		bodyY - outlineW,
		bodyW + outlineW * 2,
		bodyH + outlineW * 2,
		radius + outlineW * 0.5,
		radius + outlineW * 0.5
	)

	-- Base
	lg.setColor(fr * darkMul, fg * darkMul, fb * darkMul)
	lg.rectangle("fill",
		bodyX,
		bodyY,
		bodyW,
		bodyH,
		radius,
		radius
	)

	-- Highlight
	local hx = cx
	local hy = bodyY + bodyH * 0.35 - bodyH * highlightOffset
	local hw = bodyW * highlightScale
	local hh = bodyH * highlightScale

	lg.setColor(fr, fg, fb)
	lg.rectangle("fill",
		hx - hw * 0.5,
		hy - hh * 0.5,
		hw,
		hh,
		radius * highlightScale,
		radius * highlightScale
	)

	-- =========================
	-- SHACKLE (fixed orientation)
	-- =========================

	local shackleR = r * 0.55
	local shackleW = r * 0.22

	local shackleY = bodyY -- sits right on top of body

	-- Outline
	lg.setColor(outlineColor)
	lg.setLineWidth(shackleW + outlineW * 2)
	lg.arc("line", "open",
		cx,
		shackleY,
		shackleR + outlineW * 0.5,
		math.pi, 0
	)

	-- Inner
	lg.setColor(fr * darkMul, fg * darkMul, fb * darkMul)
	lg.setLineWidth(shackleW)
	lg.arc("line", "open",
		cx,
		shackleY,
		shackleR,
		math.pi, 0
	)

	lg.setLineWidth(1)
end

local achievements = {
    {
        id = "TOWER_LANCER_250",
        render = function()
            drawTower("lancer")
        end
    },

    {
        id = "TOWER_LANCER_1000",
        render = function()
            drawTowerAction("lancer")
        end
    },

    {
        id = "TOWER_SLOW_250",
        render = function()
            drawTower("slow")
        end
    },

    {
        id = "TOWER_SLOW_1000",
        render = function()
            drawTowerAction("slow")
        end
    },

    {
        id = "TOWER_CANNON_250",
        render = function()
            drawTower("cannon")
        end
    },

    {
        id = "TOWER_CANNON_1000",
        render = function()
            drawTowerAction("cannon")
        end
    },

    {
        id = "TOWER_SHOCK_250",
        render = function()
            drawTower("shock")
        end
    },

    {
        id = "TOWER_SHOCK_1000",
        render = function()
            drawTowerAction("shock")
        end
    },

    {
        id = "TOWER_POISON_250",
        render = function()
            drawTower("poison")
        end
    },

    {
        id = "TOWER_POISON_1000",
        render = function()
            drawTowerAction("poison")
        end
    },

    {
        id = "TOWER_PLASMA_250",
        render = function()
            drawTower("plasma")
        end
    },

    {
        id = "TOWER_PLASMA_1000",
        render = function()
            drawTowerAction("plasma")
        end
    },

    {
        id = "BOSS_KILL_1",
        render = function()
			drawKillTier("boss", false)
		end
    },

    {
        id = "BOSS_KILL_25",
        render = function()
			drawKillTier("boss", true)
		end
    },

    {
        id = "ENEMY_KILL_500",
        render = function()
			drawKillTier("fakeEntry", false)
		end
    },

    {
        id = "ENEMY_KILL_1500",
        render = function()
			drawKillTier("fakeEntry", true, nil, true)
		end
    },

    {
        id = "ENEMY_KILL_3000",
        render = function()
			drawKillTier("fakeEntry", true, true)
		end
    },

    {
        id = "CAMPAIGN_EASY",
        render = function()
            drawCampaignMedal(1)
        end
    },

    {
        id = "CAMPAIGN_NORMAL",
        render = function()
            drawCampaignMedal(2)
        end
    },

    {
        id = "CAMPAIGN_HARD",
        render = function()
            drawCampaignMedal(3)
        end
    },

	{
		id = "NO_LEAKS_NORMAL",
		render = function()
			drawNoLeaksIcon(1)
		end
	},

	{
		id = "NO_LEAKS_HARD",
		render = function()
			drawNoLeaksIcon(2)
		end
	},

	{
		id = "TOWER_UPGRADE_1",
		render = function()
			drawTowerUpgradeIcon("upgrade_1", 2)
		end
	},

	{
		id = "TOWER_UPGRADE_100",
		render = function()
			drawTowerUpgradeIcon("upgrade_100", 2)
		end
	},

	{
		id = "LAST_SECOND",
		render = function()
			drawStopwatchIcon()
		end
	},

	{
		id = "PADLOCK",
		render = function()
			centerAndScale(function()
				drawPadlock(0, 0, 18, Theme.ui.good)
			end, TOWER_SCALE)
		end
	},
}

local lockedShader = love.graphics.newShader([[
    extern float dim; // 0.0..1.0  (ex: 0.80)

    vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc)
    {
        vec4 p = Texel(tex, uv);

        // True luminance grayscale
        float g = dot(p.rgb, vec3(0.299, 0.587, 0.114));

        // Uniform "locked" look: grayscale + dim
        g = clamp(g * dim, 0.0, 1.0);

        return vec4(g, g, g, p.a);
    }
]])

local function makeLockedVersion(sourceCanvas)
    local locked = lg.newCanvas(SIZE, SIZE, {msaa = 8})

    lg.setCanvas(locked)
    lg.clear(0, 0, 0, 0)

    lg.setColor(0.25, 0.25, 0.26, 1)
    lg.rectangle("fill", 0, 0, SIZE, SIZE)

    lockedShader:send("dim", 0.8) -- 0.85
    lg.setShader(lockedShader)
    lg.draw(sourceCanvas, 0, 0)
    lg.setShader()

    lg.setCanvas()

    return locked
end

function Export.exportAchievements()
    for _, ach in ipairs(achievements) do
        local fg = beginCanvas()
        ach.render()
        finishCanvas()

        local earned = lg.newCanvas(SIZE, SIZE, { msaa = 8 })
        lg.setCanvas(earned)
        lg.clear(0, 0, 0, 0)

        lg.setColor(0.25, 0.25, 0.26, 1)
        lg.rectangle("fill", 0, 0, SIZE, SIZE)

        lg.setColor(1, 1, 1, 1)
        lg.draw(fg, 0, 0)

        lg.setCanvas()
        savePNG(earned, ACH_DIR .. "/" .. ach.id)

        local locked = makeLockedVersion(fg)
        savePNG(locked, ACH_DIR .. "/" .. ach.id .. "_LOCKED")
    end
end

function Export.run()
	Fonts.load()

	-- Add a new font for our artwork
	Fonts.achievement = love.graphics.newFont("assets/fonts/PTSans.ttf", 82) -- 72

	-- Add a new fake enemy type just for artwork sizing
	EnemyDefs.fakeEntry = {
		nameKey = "enemy.tank",
		hp = 90,
		speed = 45,
		reward = 12,
		score = 22,
		radius = 14,
	},

    ensureDirs()

    Export.exportAchievements()

    love.event.quit()
end

return Export