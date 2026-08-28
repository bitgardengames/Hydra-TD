local Spatial = require("world.spatial_grid")
local State = require("core.state")

local Targeting = {}

local EPS = 0.0001
local HUGE_NEG = -math.huge
local pointToCell = Spatial.pointToCell
local queryCellsLocal = Spatial.queryCellsLocal
local localQueryFootprintKey = Spatial.localQueryFootprintKey
local simpleCtx = {}
-- Frame cache uses nested integer-keyed tables to reduce temporary string
-- allocations and GC spikes from composed cache keys.
local frameCache = {
	frameId = -1,
	entries = {},
	touched = {},
	listPool = {},
}
local MAX_POOLED_LISTS = 16
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
	local pool = cache.listPool
	for i = 1, #cache.touched do
		local entry = cache.touched[i]
		local list = entry.list
		for candidateIndex = 1, entry.count do
			list[candidateIndex] = nil
		end
		if #pool < MAX_POOLED_LISTS then
			pool[#pool + 1] = list
		end
		cache.touched[i] = nil
	end

	-- Drop every coordinate level. In particular, cells belonging to sold
	-- towers or to a previous map must not keep growing this index forever.
	for cx in pairs(cache.entries) do
		cache.entries[cx] = nil
	end
	cache.frameId = frameId
end

function Targeting.clearFrameCache()
	clearFrameCache(frameCache, -1)
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
	if entry then
		return entry.list, entry.count
	end

	local pool = frameCache.listPool
	entry = {
		list = pool[#pool] or {},
		count = 0,
	}
	pool[#pool] = nil
	entriesByFootprint[footprintKey] = entry
	frameCache.touched[#frameCache.touched + 1] = entry

	local candidates, candidateCount = queryCellsLocal(tower.x, tower.y, tower.range, false)
	local list = entry.list
	local count = 0
	for i = 1, candidateCount do
		local e = candidates[i]
		if e and e.hp > 0 and not e.dying then
			count = count + 1
			list[count] = e
		end
	end
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
