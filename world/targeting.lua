local Spatial = require("world.spatial_grid")

local Targeting = {}

local EPS = 0.0001
local HUGE_NEG = -math.huge
local queryCells = Spatial.queryCells
local forEachInCells = Spatial.forEachInCells
local pointToCell = Spatial.pointToCell
local queryOccupancy = Spatial.queryOccupancy
local queryCellsLocal = Spatial.queryCellsLocal
local DENSE_LOCAL_RADIUS = 52
local DENSE_NEIGHBOR_CAP = 64
local DENSE_OCCUPANCY_RADIUS_CELLS = 1
local DENSE_USE_OCCUPANCY = true
local DENSE_DEBUG_COMPARE_FRAMES = 90
local denseDebugFrames = 0
local denseDebugMismatches = 0
local SIMPLE_MODES = {
	PROGRESS = 1,
	LOW_HP = 2,
	HIGH_HP = 3,
	FARTHEST = 4,
}

Targeting.MODES = {
	PROGRESS = "progress",
	LOW_HP = "low_hp",
	HIGH_HP = "high_hp",
	FARTHEST = "farthest",
	DENSE = "dense",
}
local MODES = Targeting.MODES
local simpleCtx = {}

local function evaluateSimpleCandidate(e, c)
	if e.hp <= 0 or e.dying then
		return
	end

	local dx = e.x - c.tx
	local dy = e.y - c.ty
	local d2 = dx * dx + dy * dy

	if d2 > c.r2 then
		return
	end

	local score
	if c.mode == SIMPLE_MODES.PROGRESS then
		score = e.dist
		if e.slowTimer > 0 then
			-- Slight deprioritization for slowed enemies
			score = score - 5
		end
	elseif c.mode == SIMPLE_MODES.LOW_HP then
		score = -e.hp
	elseif c.mode == SIMPLE_MODES.HIGH_HP then
		score = e.hp
	else
		score = d2
	end

	local diff = score - c.bestScore

	if diff > EPS or (diff >= -EPS and (not c.best or e.id < c.best.id)) then
		c.bestScore = score
		c.best = e
	end
end

function Targeting.isValidTarget(tower, e)
	if not e then
		return false
	end

	local hp = e.hp
	if type(hp) ~= "number" or hp <= 0 or e.dying then
		return false
	end

	if type(e.x) ~= "number" or type(e.y) ~= "number" then
		return false
	end

	local dx = e.x - tower.x
	local dy = e.y - tower.y

	return dx * dx + dy * dy <= tower.range2
end

local function pickSimpleTarget(tower, mode)
	local ctx = simpleCtx
	ctx.best = nil
	ctx.bestScore = HUGE_NEG
	ctx.r2 = tower.range2
	ctx.tx = tower.x
	ctx.ty = tower.y
	ctx.mode = mode

	forEachInCells(tower.x, tower.y, tower.range, evaluateSimpleCandidate, ctx)

	return ctx.best
end

local function pickDenseTargetLegacy(tower)
	local best = nil
	local bestScore = HUGE_NEG
	local r2 = tower.range2
	local tx = tower.x
	local ty = tower.y
	local localR2 = DENSE_LOCAL_RADIUS * DENSE_LOCAL_RADIUS
	local nearby, n = queryCells(tx, ty, tower.range)

	for i = 1, n do
		local e = nearby[i]

		if e.hp > 0 and not e.dying then
			local ex = e.x
			local ey = e.y
			local dx = ex - tx
			local dy = ey - ty
			local d2 = dx * dx + dy * dy

			if d2 <= r2 then
				local crowd = 0
				local localNearby, localN = queryCellsLocal(ex, ey, DENSE_LOCAL_RADIUS)

				if localN > DENSE_NEIGHBOR_CAP then
					localN = DENSE_NEIGHBOR_CAP
				end

				-- Bound local neighbor work so dense targeting cost remains stable in heavy waves.
				for j = 1, localN do
					local other = localNearby[j]

					if other.hp > 0 and not other.dying then
						local odx = other.x - ex
						local ody = other.y - ey

						if odx * odx + ody * ody <= localR2 then
							crowd = crowd + 1
						end
					end
				end

				local score = crowd * 1000 + e.dist
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

local function pickDenseTargetOccupancy(tower)
	local best = nil
	local bestScore = HUGE_NEG
	local r2 = tower.range2
	local tx = tower.x
	local ty = tower.y
	local nearby, n = queryCells(tx, ty, tower.range)

	for i = 1, n do
		local e = nearby[i]

		if e.hp > 0 and not e.dying then
			local ex = e.x
			local ey = e.y
			local dx = ex - tx
			local dy = ey - ty
			local d2 = dx * dx + dy * dy

			if d2 <= r2 then
				local cx, cy = pointToCell(ex, ey)
				local _, _, crowd = queryOccupancy(cx, cy, DENSE_OCCUPANCY_RADIUS_CELLS)
				local score = crowd * 1000 + e.dist
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

local function pickDenseTarget(tower)
	if not DENSE_USE_OCCUPANCY then
		return pickDenseTargetLegacy(tower)
	end

	local best = pickDenseTargetOccupancy(tower)

	if DENSE_DEBUG_COMPARE_FRAMES > 0 and denseDebugFrames < DENSE_DEBUG_COMPARE_FRAMES then
		denseDebugFrames = denseDebugFrames + 1
		local legacyBest = pickDenseTargetLegacy(tower)

		if (best and legacyBest and best.id ~= legacyBest.id) or (best and not legacyBest) or (legacyBest and not best) then
			denseDebugMismatches = denseDebugMismatches + 1
		end

		if denseDebugFrames == DENSE_DEBUG_COMPARE_FRAMES then
			print(
				string.format(
					"[targeting] dense occupancy parity: %d/%d mismatches",
					denseDebugMismatches,
					denseDebugFrames
				)
			)
		end
	end

	return best
end

-- Target enemy furthest along the path
function Targeting.findProgressTarget(tower)
	return pickSimpleTarget(tower, SIMPLE_MODES.PROGRESS)
end

function Targeting.findLowestHPTarget(tower)
	return pickSimpleTarget(tower, SIMPLE_MODES.LOW_HP)
end

function Targeting.findFarthestTarget(tower)
	return pickSimpleTarget(tower, SIMPLE_MODES.FARTHEST)
end

function Targeting.findHighestHPTarget(tower)
	return pickSimpleTarget(tower, SIMPLE_MODES.HIGH_HP)
end

function Targeting.findDenseTarget(tower)
	return pickDenseTarget(tower)
end

function Targeting.findTarget(tower, mode)
	if mode == MODES.LOW_HP then
		return pickSimpleTarget(tower, SIMPLE_MODES.LOW_HP)
	elseif mode == MODES.HIGH_HP then
		return pickSimpleTarget(tower, SIMPLE_MODES.HIGH_HP)
	elseif mode == MODES.FARTHEST then
		return pickSimpleTarget(tower, SIMPLE_MODES.FARTHEST)
	elseif mode == MODES.DENSE then
		return pickDenseTarget(tower)
	end

	return pickSimpleTarget(tower, SIMPLE_MODES.PROGRESS)
end

return Targeting
