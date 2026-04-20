local Spatial = require("world.spatial_grid")

local Targeting = {}

local EPS = 0.0001
local HUGE_NEG = -math.huge
local queryCells = Spatial.queryCells
local queryCellsCount = Spatial.queryCellsCount

Targeting.MODES = {
	PROGRESS = "progress",
	LOW_HP = "low_hp",
	FARTHEST = "farthest",
}
local MODES = Targeting.MODES

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
	local bestScore = HUGE_NEG
	local r2 = tower.range2
	local tx = tower.x
	local ty = tower.y

	local nearby = queryCells(tx, ty, tower.range)
	local n = queryCellsCount()
	local lowHpMode = mode == MODES.LOW_HP
	local farthestMode = mode == MODES.FARTHEST

	for i = 1, n do
		local e = nearby[i]

		if e.hp > 0 and not e.dying then
			local dx = e.x - tx
			local dy = e.y - ty
			local d2 = dx * dx + dy * dy

			if d2 <= r2 then
				local score = e.dist

				if lowHpMode then
					score = -e.hp
				elseif farthestMode then
					score = d2
				elseif e.slowTimer > 0 then
					-- Slight deprioritization for slowed enemies
					score = score - 5
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
	return pickTargetByScore(tower, MODES.PROGRESS)
end

function Targeting.findLowestHPTarget(tower)
	return pickTargetByScore(tower, MODES.LOW_HP)
end

function Targeting.findFarthestTarget(tower)
	return pickTargetByScore(tower, MODES.FARTHEST)
end

function Targeting.findTarget(tower, mode)
	if mode == MODES.LOW_HP then
		return Targeting.findLowestHPTarget(tower)
	elseif mode == MODES.FARTHEST then
		return Targeting.findFarthestTarget(tower)
	end

	return Targeting.findProgressTarget(tower)
end

return Targeting
