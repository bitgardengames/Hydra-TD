local floor = math.floor

local TowerStatDisplay = {}

-- Combat keeps sub-second precision internally, but players compare a whole
-- number of attacks over a readable one-minute window.
function TowerStatDisplay.attackSpeed(fireRate)
	return floor((fireRate or 0) * 60 + 0.5)
end

-- Range is already measured in world pixels. Keep that unit and remove the
-- fractional noise produced by tile-based balance values and upgrades.
function TowerStatDisplay.range(range)
	return floor((range or 0) + 0.5)
end

return TowerStatDisplay
