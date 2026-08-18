local sin = math.sin
local pi = math.pi

local Dance = {}

-- Return a render-only pose for a tower's turret. Each tower type has its own
-- movement, while the index adds a small entrance/phase offset so duplicates do
-- not move as one rigid block.
function Dance.pose(clock, kind, index)
	clock = math.max(0, clock or 0)
	kind = kind or "lancer"
	index = index or 1

	-- Let the cheer travel across the board when the victory screen opens.
	local localTime = math.max(0, clock - (index - 1) * 0.045)
	local entrance = math.min(1, localTime / 0.28)
	local phase = ((index - 1) % 4) * 0.16

	if kind == "lancer" then
		-- Sharp double-bounce, like an emphatic victory salute.
		local beat = math.max(0, sin(localTime * pi * 2.4))
		return -beat * beat * 7 * entrance, sin(localTime * pi * 1.2) * 0.11 * entrance
	elseif kind == "slow" then
		-- Slow keeps its characteristic smooth, weightless orbit.
		return sin(localTime * pi * 1.7) * 4 * entrance,
			sin(localTime * pi * 0.85 + pi / 3) * 0.18 * entrance
	elseif kind == "cannon" then
		-- The heavy cannon makes short, punchy recoil hops.
		local kick = math.max(0, sin((localTime + phase) * pi * 3.1))
		return -kick * 5.5 * entrance, -kick * 0.15 * entrance
	elseif kind == "shock" then
		-- An energetic high-frequency shimmy.
		return sin((localTime + phase) * pi * 4.2) * 2.5 * entrance,
			sin((localTime + phase) * pi * 5.4) * 0.17 * entrance
	elseif kind == "poison" then
		-- A lopsided, languid wobble.
		return (-2.5 + sin((localTime + phase) * pi * 1.45) * 2.5) * entrance,
			sin((localTime + phase) * pi * 1.45 + pi / 2) * 0.13 * entrance
	elseif kind == "plasma" then
		-- Plasma floats up and spins through a broad celebratory arc.
		return -math.abs(sin((localTime + phase) * pi * 1.9)) * 6 * entrance,
			sin((localTime + phase) * pi * 1.9) * 0.18 * entrance
	end

	-- Custom/modded towers still get a restrained generic cheer.
	return -math.abs(sin((localTime + phase) * pi * 2.2)) * 4 * entrance,
		sin((localTime + phase) * pi * 1.1) * 0.12 * entrance
end

return Dance
