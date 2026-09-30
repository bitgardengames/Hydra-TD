local Constants = require("core.constants")
local floor = math.floor

local TowerStatDisplay = {}

-- Present range on a compact, unitless scale instead of exposing world pixels.
-- Twenty display units per tile keeps every tower's range easy to compare while
-- still making the smallest authored per-level increase visible as a whole
-- number after rounding.
local RANGE_UNITS_PER_TILE = 20

-- Combat keeps sub-second precision internally, but players compare a whole
-- number of attacks over a readable one-minute window.
function TowerStatDisplay.attackSpeed(fireRate)
	return floor((fireRate or 0) * 60 + 0.5)
end

function TowerStatDisplay.range(range)
	return floor((range or 0) * RANGE_UNITS_PER_TILE / Constants.TILE + 0.5)
end

return TowerStatDisplay
