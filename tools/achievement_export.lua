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
	local cy = SIZE * 0.60   -- slightly higher than before
	local radius = 12

	lg.push()
	lg.origin()

	-- ribbons
	drawMedalRibbons(cx, cy, radius, tier)

	-- medal
	Medals.drawTier(cx, cy, tier, radius, MEDAL_SCALE)

	-- tier text
	local text = roman[tier]
	local pad = 20

	Fonts.set("achievement")

	local font = Fonts.get("achievement")
	local h = font:getHeight()

	lg.setColor(colorText)

	Text.printShadow(text, pad, SIZE - h + 8, {ox = 2, oy = 2})

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
	local thickness = r * 0.20
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
		thickness * 0.4,
		thickness * 0.4
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

local Constants = require("core.constants")

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

	if not t.chain then
		--Projectiles.spawn(t, enemy)
	else
		local zapOrder = Shock.fire(t, enemy)

		if zapOrder and #zapOrder > 0 then
			local mx, my = getShockOrigin(t)

			Effects.spawnZapEffect(mx, my, zapOrder)
		end
	end

	-- === SIMULATE REAL GAME ===
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

local function drawEnemy(kind, isDead)
    local def = EnemyDefs[kind]

    local enemy = {
        kind = kind,
        def = def,
        x = 0,
        y = 0,
		prevX = 0,
		prevY = 0,
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

        hitFlash = 0,
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

		if isDead and kind ~= "boss" then
			drawDeadEyes(enemy.radius)
		end

        lg.setColor(1, 1, 1, 1)
    end, ENEMY_SCALE, 5)
end

-- Kill Tier Achievement Export
local function drawKillTier(enemyType, isDead, tierNumber)
	drawEnemy(enemyType, isDead)

	if not tierNumber then
		return
	end

	lg.push()
	lg.origin()

	local pad = 16
	local text = tostring(tierNumber)

	Fonts.set("achievement")

	local font = Fonts.get("achievement")
	local h = font:getHeight()

	lg.setColor(colorText)

	Text.printShadow(text, pad, SIZE - h + 8, {ox = 2, oy = 2})

	lg.pop()
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
			drawKillTier("boss", true)
		end
    },

    {
        id = "BOSS_KILL_25",
        render = function()
			drawKillTier("boss", true, 25)
		end
    },

    {
        id = "ENEMY_KILL_500",
        render = function()
			drawKillTier("fakeEntry", true, 500)
		end
    },

    {
        id = "ENEMY_KILL_1500",
        render = function()
			drawKillTier("fakeEntry", true, 1500)
		end
    },

    {
        id = "ENEMY_KILL_3000",
        render = function()
			drawKillTier("fakeEntry", true, 3000)
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

    lockedShader:send("dim", 0.85)
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