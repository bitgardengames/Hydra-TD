local Spatial = require("world.spatial_grid")
local State = require("core.state")

local Targeting = {}

local EPS = 0.0001
local HUGE_NEG = -math.huge
local pointToCell = Spatial.pointToCell
local queryCellsLocal = Spatial.queryCellsLocal
local localQueryFootprintKey = Spatial.localQueryFootprintKey
local simpleCtx = {}
local function collectLiving(e)
	return e.hp > 0 and not e.dying
end
-- Frame cache uses nested integer-keyed tables to reduce temporary string
-- allocations and GC spikes from composed cache keys.
local frameCache = {
	frameId = -1,
	entries = {},
}
local function updateBest(e, c, score)
	local diff = score - c.bestScore
	if diff > EPS or (diff >= -EPS and (not c.best or e.id < c.best.id)) then
		c.bestScore = score
		c.best = e
	end
end

local function evaluateCandidate(e, c)
	if e.hp <= 0 or e.dying then
		return
	end

	local dx = e.x - c.tx
	local dy = e.y - c.ty
	local d2 = dx * dx + dy * dy
	if d2 > c.r2 then
		return
	end

	updateBest(e, c, e.dist)
end

local function clearFrameCache(cache, frameId)
	-- Entries own their frame stamps, so advancing the cache does not need to
	-- discard its coordinate tables, entries, or candidate lists. An entry is
	-- rebuilt lazily before it can be returned in the new frame.
	cache.frameId = frameId
end

local function getCandidatesForTower(tower)
	local frameId = State.frameId or 0
	if frameCache.frameId ~= frameId then
		clearFrameCache(frameCache, frameId)
	end

	local cx, cy = pointToCell(tower.x, tower.y)
	local footprintKey = localQueryFootprintKey(tower.range)
	local entriesByX = frameCache.entries
	local entriesByY = entriesByX[cx]
	if not entriesByY then
		entriesByY = {}
		entriesByX[cx] = entriesByY
	end
	local entriesByFootprint = entriesByY[cy]
	if not entriesByFootprint then
		entriesByFootprint = {}
		entriesByY[cy] = entriesByFootprint
	end
	local entry = entriesByFootprint[footprintKey]
	if entry and entry.frameId == frameId then
		return entry.list, entry.count
	end

	if not entry then
		local list = {}
		entry = {
			list = list,
			collectContext = Spatial.createCollectContext(list, collectLiving),
			count = 0,
			frameId = -1,
		}
		entriesByFootprint[footprintKey] = entry
	end

	entry.frameId = frameId

	local list, count = queryCellsLocal(tower.x, tower.y, tower.range, false, entry.collectContext)
	entry.count = count

	return list, count
end

function Targeting.isSemanticallyValidTarget(tower, e)
	if not Targeting.isTargetEntityValid(e) or e.hp <= 0 or e.dying then
		return false
	end

	local dx = e.x - tower.x
	local dy = e.y - tower.y

	return type(tower.range2) == "number" and dx * dx + dy * dy <= tower.range2
end

function Targeting.isTargetEntityValid(e)
	if not e then
		return false
	end

	return type(e.hp) == "number"
		and type(e.x) == "number"
		and type(e.y) == "number"
end

Targeting.isValidTarget = Targeting.isSemanticallyValidTarget

function Targeting.findTarget(tower)
	local ctx = simpleCtx
	ctx.best = nil
	ctx.bestScore = HUGE_NEG
	ctx.r2 = tower.range2
	ctx.tx = tower.x
	ctx.ty = tower.y
	local candidates, count = getCandidatesForTower(tower)
	for i = 1, count do
		evaluateCandidate(candidates[i], ctx)
	end

	return ctx.best
end

return Targeting
