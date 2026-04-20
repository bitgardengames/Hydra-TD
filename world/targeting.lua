local Spatial = require("world.spatial_grid")

local Targeting = {}

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
	local tx = tower.x
	local ty = tower.y

	local nearby = Spatial.queryCells(tx, ty, tower.range)
	local n = Spatial.queryCellsCount()

	if mode == Targeting.MODES.LOW_HP then
		for i = 1, n do
			local e = nearby[i]
			if e.hp > 0 and not e.dying then
				local dx = e.x - tx
				local dy = e.y - ty
				local d2 = dx * dx + dy * dy
				if d2 <= r2 then
					local score = -(e.hp or 0)
					local diff = score - bestScore
					if diff > EPS or (diff >= -EPS and (not best or e.id < best.id)) then
						bestScore = score
						best = e
					end
				end
			end
		end
	elseif mode == Targeting.MODES.FARTHEST then
		for i = 1, n do
			local e = nearby[i]
			if e.hp > 0 and not e.dying then
				local dx = e.x - tx
				local dy = e.y - ty
				local d2 = dx * dx + dy * dy
				if d2 <= r2 then
					local score = d2
					local diff = score - bestScore
					if diff > EPS or (diff >= -EPS and (not best or e.id < best.id)) then
						bestScore = score
						best = e
					end
				end
			end
		end
	else
		for i = 1, n do
			local e = nearby[i]
			if e.hp > 0 and not e.dying then
				local dx = e.x - tx
				local dy = e.y - ty
				local d2 = dx * dx + dy * dy
				if d2 <= r2 then
					local score = e.dist
					-- Slight deprioritization for slowed enemies
					if e.slowTimer > 0 then
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
