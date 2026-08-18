local sin = math.sin
local cos = math.cos
local pi = math.pi

local Dance = {}

local function smoothstep(t)
	t = math.max(0, math.min(1, t))
	return t * t * (3 - 2 * t)
end

-- Return a render-only offset and turn for a tower's turret. The curves use
-- paired sine waves rather than sharp, one-sided hops so direction changes ease
-- naturally. Index-based delays and phases keep groups from moving in lockstep.
function Dance.pose(clock, kind, index)
	clock = math.max(0, clock or 0)
	kind = kind or "lancer"
	index = index or 1

	-- Let the cheer travel across the board when the victory screen opens.
	local localTime = math.max(0, clock - (index - 1) * 0.045)
	local entrance = smoothstep(localTime / 0.4)
	local phase = ((index - 1) % 4) * pi * 0.32

	if kind == "lancer" then
		-- A broad side-to-side salute with a gentle floating bounce.
		local beat = localTime * pi * 1.8 + phase
		return sin(beat) * 3.4 * entrance,
			-cos(beat * 2) * 2.2 * entrance,
			sin(beat) * 0.48 * entrance
	elseif kind == "slow" then
		-- Slow traces a relaxed circle while following the orbit with its barrel.
		local orbit = localTime * pi * 1.05 + phase
		return cos(orbit) * 3.8 * entrance,
			sin(orbit) * 3.8 * entrance,
			orbit * 0.32 * entrance
	elseif kind == "cannon" then
		-- The heavy cannon rocks through a wide, weighty pendulum.
		local swing = localTime * pi * 1.35 + phase
		return sin(swing) * 2.2 * entrance,
			-cos(swing * 2) * 1.5 * entrance,
			sin(swing) * 0.62 * entrance
	elseif kind == "shock" then
		-- Shock buzzes around a tight circular path and spins continuously.
		local orbit = localTime * pi * 2.5 + phase
		return cos(orbit) * 2.7 * entrance,
			sin(orbit) * 2.7 * entrance,
			orbit * 0.72 * entrance
	elseif kind == "poison" then
		-- A languid figure-eight gives poison its lopsided wobble.
		local drift = localTime * pi * 1.15 + phase
		return sin(drift) * 3.2 * entrance,
			sin(drift * 2) * 2 * entrance,
			sin(drift + pi / 3) * 0.42 * entrance
	elseif kind == "plasma" then
		-- Plasma floats in a broad orbit while completing celebratory rotations.
		local orbit = localTime * pi * 1.5 + phase
		return cos(orbit) * 4.2 * entrance,
			sin(orbit) * 4.2 * entrance,
			orbit * entrance
	end

	-- Custom/modded towers still get a restrained, smooth circular cheer.
	local orbit = localTime * pi * 1.4 + phase
	return cos(orbit) * 2.5 * entrance,
		sin(orbit) * 2.5 * entrance,
		sin(orbit) * 0.35 * entrance
end

return Dance
