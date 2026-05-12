local Cursor = {
	x = 0,
	y = 0,
}

local lg = love.graphics

local min = math.min
local max = math.max

-- Call every frame
function Cursor.update(dt)
	Cursor.x, Cursor.y = love.mouse.getPosition()

	-- Clamp
	local sw, sh = lg.getDimensions()

	Cursor.x = max(0, min(sw, Cursor.x))
	Cursor.y = max(0, min(sh, Cursor.y))
end

local HOTSPOT_X = 2

function Cursor.draw()
    local tipX, tipY = Cursor.x, Cursor.y

    local h = 16
    local w = 11
	local HOTSPOT_Y = h + 2

    local down = love.mouse.isDown(1) and 0.88 or 1

    love.graphics.push()

    -- Move origin to hotspot
    love.graphics.translate(tipX + HOTSPOT_X, tipY + HOTSPOT_Y)
    love.graphics.scale(1, down)

    -- Define geometry relative to hotspot (0,0 is the tip)
    local p1x, p1y = 0, 0
    local p2x, p2y = 0, -h
    local p3x, p3y = w, 0

    -- Outline
    love.graphics.setColor(0.04, 0.04, 0.04, 1)
    love.graphics.setLineWidth(3)
    love.graphics.polygon("line", p1x, p1y, p2x, p2y, p3x, p3y)

    -- Fill
    love.graphics.setColor(0.92, 0.94, 0.96, 1)
    love.graphics.polygon("fill", p1x, p1y, p2x, p2y, p3x, p3y)

    love.graphics.pop()
    love.graphics.setLineWidth(1)
end

function Cursor.mousemoved(x, y)
    Cursor.x = x
    Cursor.y = y
end

return Cursor
