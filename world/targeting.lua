local Util = require("core.util")
local Spatial = require("world.spatial_grid")

local Targeting = {}

local dist2 = Util.dist2

--[[
	Targeting.findClosest(...)
	Targeting.findLowestHP(...)
	Targeting.findBossPriority(...)

	-- Make an enum table
	Targeting.MODES = {
		PROGRESS = "progress",
	}

	-- Then towers can do:
	t.targetMode = Targeting.MODES.PROGRESS
--]]

function Targeting.isValidTarget(tower, e)
	if not e or e.hp <= 0 or e.dying then
		return false
	end

	local dx = e.x - tower.x
	local dy = e.y - tower.y

	return dx * dx + dy * dy <= tower.range2
end

-- Target enemy furthest along the path
function Targeting.findProgressTarget(tower)
	local best = nil
	local bestProg = -1
	local r2 = tower.range2

	local nearby = Spatial.queryCells(tower.x, tower.y)
	local n = #nearby

	for i = 1, n do
		local e = nearby[i]

		if e.hp > 0 and not e.dying then
			local dx = e.x - tower.x
			local dy = e.y - tower.y

			if dx * dx + dy * dy <= r2 then
				local prog = e.dist

				if e.slowTimer > 0 then
					prog = prog - 5
				end

				if prog > bestProg then
					bestProg = prog
					best = e
				end
			end
		end
	end

	return best
end

return Targeting