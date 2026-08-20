local sin = math.sin
local max = math.max
local min = math.min
local pi = math.pi

local Cheer = {duration = 1.05}

local function smoothstep(t)
	t = max(0, min(1, t))
	return t * t * (3 - 2 * t)
end

-- A small, non-looping salute. Staggering is deliberately capped so even a
-- crowded board completes the gesture within the celebration window.
function Cheer.pose(remaining, index, motionEnabled)
	if motionEnabled == false or not remaining or remaining <= 0 then
		return 0, 0, 0
	end

	local elapsed = Cheer.duration - remaining
	local delay = ((index or 1) - 1) % 8 * 0.035
	local progress = (elapsed - delay) / 0.62
	if progress <= 0 or progress >= 1 then return 0, 0, 0 end

	local envelope = smoothstep(min(1, progress * 4))
		* smoothstep(min(1, (1 - progress) * 4))
	local beat = sin(progress * pi)
	local side = ((index or 1) % 2 == 0) and -1 or 1
	return side * beat * 0.7 * envelope, -beat * 1.8 * envelope,
		side * beat * 0.12 * envelope
end

return Cheer
