local sin = math.sin
local pi = math.pi

local Dance = {}

-- Return a render-only pose for a tower's turret. The three choreography lanes
-- deliberately use different meters so a crowded board feels celebratory rather
-- than moving as one rigid block.
function Dance.pose(clock, index)
	clock = math.max(0, clock or 0)
	index = index or 1

	-- Let the cheer travel across the board when the victory screen opens.
	local localTime = math.max(0, clock - (index - 1) * 0.045)
	local entrance = math.min(1, localTime / 0.28)
	local lane = (index - 1) % 3

	if lane == 0 then
		-- Upbeat double-bounce with a small side-to-side nod.
		local beat = math.max(0, sin(localTime * pi * 2.4))
		return -beat * beat * 7 * entrance, sin(localTime * pi * 1.2) * 0.11 * entrance
	elseif lane == 1 then
		-- A slower floating sway.
		return sin(localTime * pi * 1.7) * 4 * entrance,
			sin(localTime * pi * 0.85 + pi / 3) * 0.18 * entrance
	end

	-- Quick alternating hops, offset from the other two lanes.
	local hop = math.abs(sin(localTime * pi * 2.9))
	return -hop * 5 * entrance, sin(localTime * pi * 2.9) * 0.14 * entrance
end

return Dance
