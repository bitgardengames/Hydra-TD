local Spatial = require("world.spatial_grid")

local Targeting = {}

local EPS = 0.0001
local HUGE_NEG = -math.huge
local queryCells = Spatial.queryCells
local queryCellsCount = Spatial.queryCellsCount
local queryCellsInto = Spatial.queryCellsInto
local DENSE_LOCAL_RADIUS = 52
local DENSE_NEIGHBOR_CAP = 64
local denseQueryBuffer = {}

Targeting.MODES = {
	PROGRESS = "progress",
	LOW_HP = "low_hp",
	HIGH_HP = "high_hp",
	FARTHEST = "farthest",
	DENSE = "dense",
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
	local highHpMode = mode == MODES.HIGH_HP
	local farthestMode = mode == MODES.FARTHEST
	local denseMode = mode == MODES.DENSE

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
				elseif highHpMode then
					score = e.hp
				elseif farthestMode then
					score = d2
				elseif denseMode then
					local localR2 = DENSE_LOCAL_RADIUS * DENSE_LOCAL_RADIUS
					local crowd = 0
					local localNearby = denseQueryBuffer
					local localN = queryCellsInto(localNearby, e.x, e.y, DENSE_LOCAL_RADIUS)
					if localN > DENSE_NEIGHBOR_CAP then
						localN = DENSE_NEIGHBOR_CAP
					end

					-- Old approach scanned every in-range candidate for every candidate (O(n^2));
					-- this bounds work to a local spatial query (+ optional cap), reducing hitch risk in large waves.
					for j = 1, localN do
						local other = localNearby[j]
						if other.hp > 0 and not other.dying then
							local odx = other.x - e.x
							local ody = other.y - e.y
							if odx * odx + ody * ody <= localR2 then
								crowd = crowd + 1
							end
						end
					end

					score = crowd * 1000 + e.dist
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

function Targeting.findHighestHPTarget(tower)
	return pickTargetByScore(tower, MODES.HIGH_HP)
end

function Targeting.findDenseTarget(tower)
	return pickTargetByScore(tower, MODES.DENSE)
end

function Targeting.findTarget(tower, mode)
	if mode == MODES.LOW_HP then
		return Targeting.findLowestHPTarget(tower)
	elseif mode == MODES.HIGH_HP then
		return Targeting.findHighestHPTarget(tower)
	elseif mode == MODES.FARTHEST then
		return Targeting.findFarthestTarget(tower)
	elseif mode == MODES.DENSE then
		return Targeting.findDenseTarget(tower)
	end

	return Targeting.findProgressTarget(tower)
end

return Targeting
