local Cursor = {
	x = 0,
	y = 0,

	usingVirtual = false,

	speed = 800, -- px / second
	deadzone = 0.18,
}

local lg = love.graphics

local min = math.min
local max = math.max
local abs = math.abs

-- Call every frame
function Cursor.update(dt)
	Cursor.pollJoystick(dt)

	if Cursor.usingVirtual then
		Cursor.updateVirtual(dt)
	end

	-- Clamp to screen
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

    -- Define geometry RELATIVE to hotspot (0,0 is the tip)
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

-- Gamepad / Steam Deck movement
function Cursor.updateVirtual(dt)
	local js = love.joystick.getJoysticks()[1]

	if not js then
		return
	end

	local ax = js:getAxis(1)
	local ay = js:getAxis(2)

	if abs(ax) < Cursor.deadzone then
		ax = 0
	end

	if abs(ay) < Cursor.deadzone then
		ay = 0
	end

	Cursor.x = Cursor.x + ax * Cursor.speed * dt
	Cursor.y = Cursor.y + ay * Cursor.speed * dt
end

-- Call this when a gamepad is used
function Cursor.enableVirtual()
	if Cursor.usingVirtual then
		return
	end

	local x, y = love.mouse.getPosition()
	local sw, sh = lg.getDimensions()

	x = max(0, min(sw - 1, x))
	y = max(0, min(sh - 1, y))

	-- Gamepad only / edge case protection
	if x == 0 and y == 0 then
		Cursor.x = sw * 0.5
		Cursor.y = sh * 0.5
	else
		Cursor.x = x
		Cursor.y = y
	end

	Cursor.usingVirtual = true
end

-- Call this when mouse moves
function Cursor.disableVirtual()
	if not Cursor.usingVirtual then
		return
	end

	Cursor.usingVirtual = false
end

function Cursor.pollJoystick(dt)
	local js = love.joystick.getJoysticks()[1]

	if not js then
		return
	end

	local ax = js:getAxis(1)
	local ay = js:getAxis(2)

	if abs(ax) > Cursor.deadzone or abs(ay) > Cursor.deadzone then
		Cursor.enableVirtual()
	end
end

function Cursor.mousemoved(x, y)
    Cursor.x = x
    Cursor.y = y
end

return Cursor