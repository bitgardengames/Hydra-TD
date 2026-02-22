local TowersDefs = require("world.tower_defs")
local EnemyDefs = require("world.enemy_defs")
local DrawEntities = require("render.draw_entities")

local Export = {}
local lg = love.graphics

local SIZE = 256
local REF_ICON_SIZE = 64
local TOWER_SCALE = (SIZE / REF_ICON_SIZE) * 1.8 -- 1.5 scale
local ENEMY_SCALE = (SIZE / REF_ICON_SIZE) * 1.4 -- 1.0 scale

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
        DrawEntities.drawTowerCore(kind, 0, 0, { angle  = -math.pi / 4, alpha  = 1, shadow = false, scale = 2.0})

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

        hitFlash = 0,
        dying = isDead,
        deathDur = 0.3,
        deathT = isDead and 0.3 or 0,

        spawnFade = 0,
        exitFade = nil,
        pathIndex = 1,
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

local achievements = {
    {
        id = "ACH_LANCER_MASTER",
        render = function()
            drawTower("lancer")
        end
    },

    {
        id = "ACH_SLOW_MASTER",
        render = function()
            drawTower("slow")
        end
    },

    {
        id = "ACH_CANNON_MASTER",
        render = function()
            drawTower("cannon")
        end
    },

    {
        id = "ACH_SHOCK_MASTER",
        render = function()
            drawTower("shock")
        end
    },

    {
        id = "ACH_POISON_MASTER",
        render = function()
            drawTower("poison")
        end
    },

    {
        id = "ACH_FIRST_BOSS",
        render = function()
            drawEnemy("boss", false)
        end
    },

    {
        id = "ACH_BOSS_EXECUTED",
        render = function()
            drawEnemy("boss", true)
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
    lg.clear(0,0,0,0)

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
        lg.clear(0,0,0,0)

        lg.setColor(0.25, 0.25, 0.26, 1)
        lg.rectangle("fill", 0, 0, SIZE, SIZE)

        lg.setColor(1,1,1,1)
        lg.draw(fg, 0, 0)

        lg.setCanvas()
        savePNG(earned, ACH_DIR .. "/" .. ach.id)

        local locked = makeLockedVersion(fg)
        savePNG(locked, ACH_DIR .. "/" .. ach.id .. "_LOCKED")
    end
end

function Export.run()
    ensureDirs()
    Export.exportAchievements()

    love.event.quit()
end

return Export