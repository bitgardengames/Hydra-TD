local Rumble = {}

Rumble.enabled = true
Rumble.globalStrength = 1.0

-- Internal state
local active = false
local timer = 0
local duration = 0
local strength = 0

local joystick = nil

local min = math.min
local max = math.max

local function getJoystick()
	if joystick and joystick:isConnected() then
		return joystick
	end

	local sticks = love.joystick.getJoysticks()

	joystick = sticks[1]

	return joystick
end

local function stop()
	if joystick then
		joystick:setVibration(0, 0)
	end

	active = false
	timer = 0
	duration = 0
	strength = 0
end

function Rumble.pulse(str, dur)
	if not Rumble.enabled then
		return
	end

	local js = getJoystick()

	if not js or not js:isVibrationSupported() then
		return
	end

	strength = min(1, max(0, (str or 0.3) * Rumble.globalStrength))
	duration = dur or 0.08
	timer = 0
	active = true

	js:setVibration(strength, strength)
end

function Rumble.stop()
	stop()
end

function Rumble.update(dt)
	if not active then
		return
	end

	timer = timer + dt

	if timer >= duration then
		stop()
	end
end

function Rumble.setEnabled(on)
	Rumble.enabled = on

	if not on then
		stop()
	end
end

function Rumble.setStrength(v)
	Rumble.globalStrength = min(1, max(0, v or 1))
end

return Rumble