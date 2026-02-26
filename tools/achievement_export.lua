local TowersDefs = require("world.tower_defs")
local EnemyDefs = require("world.enemy_defs")
local DrawEntities = require("render.draw_entities")
local Fonts = require("core.fonts")
local Text = require("ui.text")

local Export = {}
local lg = love.graphics

local SIZE = 256
local REF_ICON_SIZE = 64
local TOWER_SCALE = (SIZE / REF_ICON_SIZE) * 1.5 -- 1.5 scale
local ENEMY_SCALE = (SIZE / REF_ICON_SIZE) * 1.5 -- 1.0 scale

local EXPORT_DIR = "export"
local ACH_DIR = EXPORT_DIR .. "/achievements"

local function ensureDirs()
    love.filesystem.createDirectory(EXPORT_DIR)
    love.filesystem.createDirectory(ACH_DIR)
end

local function beginCanvas()
    local canvas = lg.newCanvas(SIZE, SIZE, { msaa = 8 })
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

local function drawTower(kind)
    centerAndScale(function()
        DrawEntities.drawTowerCore(kind, 0, 0, { angle  = -math.pi / 4, alpha  = 1, shadow = false})

        lg.setColor(1, 1, 1, 1)
    end, TOWER_SCALE)
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

	lg.setColor(1, 1, 1, 1)

	Text.printShadow(text, pad, SIZE - h + (pad * 0.5), {ox = 2, oy = 2})

	lg.pop()
end

local achievements = {
	-- No tower achievements are implemented yet
    {
        id = "TOWER_LANCER_250",
        render = function()
            drawTower("lancer")
        end
    },

    {
        id = "TOWER_SLOW_250",
        render = function()
            drawTower("slow")
        end
    },

    {
        id = "TOWER_CANNON_250",
        render = function()
            drawTower("cannon")
        end
    },

    {
        id = "TOWER_SHOCK_250",
        render = function()
            drawTower("shock")
        end
    },

    {
        id = "TOWER_POISON_250",
        render = function()
            drawTower("poison")
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
	Fonts.achievement = love.graphics.newFont("assets/fonts/PTSans.ttf", 72)

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