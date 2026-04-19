local Util = require("core.util")
local Spatial = require("world.spatial_grid")

local Targeting = {}

local dist2 = Util.dist2

local EPS = 0.0001

Targeting.MODES = {
	PROGRESS = "progress",
	LOW_HP = "low_hp",
	FARTHEST = "farthest",
}

function Targeting.isValidTarget(tower, e)
	if not e or e.hp <= 0 or e.dying then
		return false
	end

	local dx = e.x - tower.x
	local dy = e.y - tower.y

	return dx * dx + dy * dy <= tower.range2
end

local function pickTargetByScore(tower, mode)
	local best = nil
	local bestScore = -math.huge
	local r2 = tower.range2

	local nearby = Spatial.queryCells(tower.x, tower.y)
	local n = #nearby

	for i = 1, n do
		local e = nearby[i]

		if e.hp > 0 and not e.dying then
			local dx = e.x - tower.x
			local dy = e.y - tower.y
			local d2 = dx * dx + dy * dy

			if d2 <= r2 then
				local score

				if mode == Targeting.MODES.LOW_HP then
					score = -(e.hp or 0)
				elseif mode == Targeting.MODES.FARTHEST then
					score = d2
				else
					score = e.dist

					-- Slight deprioritization for slowed enemies
					if e.slowTimer > 0 then
						score = score - 5
					end
				end

				local diff = score - bestScore

				if diff > EPS or (diff >= -EPS and (not best or e.id < best.id)) then
					bestScore = score
					best = e
				end
			end
		end
	end

	return best
end

-- Target enemy furthest along the path
function Targeting.findProgressTarget(tower)
	return pickTargetByScore(tower, Targeting.MODES.PROGRESS)
end

function Targeting.findLowestHPTarget(tower)
	return pickTargetByScore(tower, Targeting.MODES.LOW_HP)
end

function Targeting.findFarthestTarget(tower)
	return pickTargetByScore(tower, Targeting.MODES.FARTHEST)
end

function Targeting.findTarget(tower, mode)
	if mode == Targeting.MODES.LOW_HP then
		return Targeting.findLowestHPTarget(tower)
	elseif mode == Targeting.MODES.FARTHEST then
		return Targeting.findFarthestTarget(tower)
	end

	return Targeting.findProgressTarget(tower)
end

return Targeting
