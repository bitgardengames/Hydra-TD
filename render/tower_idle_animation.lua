local sin = math.sin
local abs = math.abs
local max = math.max
local min = math.min
local pi = math.pi
local tau = pi * 2

local Idle = {}

local function smootherstep(t)
	t = max(0, min(1, t))
	return t * t * t * (t * (t * 6 - 15) + 10)
end

local function pulse(t)
	if t < 0 or t > 1 then return 0 end
	local joined = t * (1 - t)
	return 64 * joined * joined * joined
end

-- Render-only pose data. idleDuration is supplied by the renderer, while phase
-- is stable per tower; no random source or simulation field is read or changed.
function Idle.pose(idleDuration, kind, index, phase, motionEnabled)
	idleDuration = max(0, idleDuration or 0)
	kind = kind or "modded"
	index = index or 1
	phase = (phase or ((index * 0.61803398875) % 1)) * tau

	if motionEnabled == false then
		return 0, 0, 0, 0
	end

	-- Wait before the first gesture and leave most of every cycle completely
	-- still. The phase offsets duplicate towers without introducing randomness.
	local entrance = smootherstep((idleDuration - 0.65) / 0.55)
	local cycle, start, length = 9.7, 7.8, 0.9
	local clock = (idleDuration + phase / tau * cycle) % cycle
	local p = (clock - start) / length
	local envelope = pulse(p) * entrance
	if envelope == 0 then return 0, 0, 0, 0 end

	local wave = sin(p * tau)
	if kind == "lancer" then
		return wave * 0.8 * envelope, -abs(wave) * 0.35 * envelope,
			wave * 0.09 * envelope, 0
	elseif kind == "slow" then
		return wave * 0.35 * envelope, sin(p * pi) * 0.45 * envelope,
			-wave * 0.13 * envelope, 0.12 * envelope
	elseif kind == "cannon" then
		return 0, abs(wave) * 0.5 * envelope, wave * 0.075 * envelope, 0
	elseif kind == "shock" then
		local twitch = sin(p * tau * 3)
		return twitch * 0.55 * envelope, 0, twitch * 0.055 * envelope,
			0.22 * envelope
	elseif kind == "poison" then
		return wave * 0.45 * envelope, sin(p * tau * 2) * 0.3 * envelope,
			-wave * 0.1 * envelope, 0.1 * envelope
	elseif kind == "plasma" then
		return 0, -sin(p * pi) * 0.65 * envelope,
			wave * 0.065 * envelope, 0.28 * envelope
	end

	-- Unknown/modded turrets get only a restrained nod.
	return 0, 0, wave * 0.035 * envelope, 0
end

return Idle
