local Camera = require("core.camera")
local Text = require("ui.text")

local floaters = {}
local pool = {}

local floor = math.floor
local random = love.math.random

local function add(x, y, text, r, g, b)
    local f = pool[#pool]

    if f then
        pool[#pool] = nil
    else
        f = {}
    end

    f.x = x
    f.y = y
    f.startY = y
    f.rise = 22 + random() * 6
    f.text = text
    f.t = 0
    f.life = 1
    f.r = r or 1
    f.g = g or 1
    f.b = b or 1

    floaters[#floaters + 1] = f
end

local function update(dt)
    for i = #floaters, 1, -1 do
        local f = floaters[i]

        f.t = f.t + dt
        local p = f.t / f.life

        if p >= 1 then
            floaters[i] = floaters[#floaters]
            floaters[#floaters] = nil
            pool[#pool + 1] = f
        else
            local ease = 1 - (1 - p) * (1 - p)
            f.y = f.startY - ease * f.rise
        end
    end
end

local function draw()
    local font = love.graphics.getFont()

    for i = 1, #floaters do
        local f = floaters[i]
        local p = f.t / f.life

        local rise = (1 - p) * 10
        local alpha = (p < 0.2) and 1 or (1 - (p - 0.2) / 0.8)

        local sx, sy = Camera.worldToScreen(f.x, f.y - rise)

        -- Measure width with CURRENT font
        local textW = font:getWidth(f.text)

        local leftX = sx - textW * 0.5
        leftX = floor(leftX + 0.5)
        sy = floor(sy + 0.5)

        love.graphics.setColor(f.r, f.g, f.b, alpha)
        Text.printShadow(f.text, leftX, sy)
    end
end

function clear()
    for i = #floaters, 1, -1 do
        pool[#pool + 1] = floaters[i]
        floaters[i] = nil
    end
end

return {
    floaters = floaters,
    add = add,
    update = update,
    draw = draw,
    clear = clear,
}