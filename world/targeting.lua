local Spatial = require("world.spatial_grid")
local State = require("core.state")

local Targeting = {}

local EPS = 0.0001
local HUGE_NEG = -math.huge
local pointToCell = Spatial.pointToCell
local queryCellsLocal = Spatial.queryCellsLocal
local queryContext = Spatial.newQueryContext(false)
local localQueryFootprintKey = Spatial.localQueryFootprintKey
local simpleCtx = {}
-- Keep only the current frame's keys. Entry objects own their candidate buffers,
-- and a bounded pool lets common cell/footprint counts avoid per-frame garbage.
local MAX_POOLED_ENTRIES = 256
local frameCache = {
	entries = {},
	activeEntries = {},
	activeCount = 0,
	frameId = nil,
	pool = {},
	poolCount = 0,
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

local function releaseCandidates(entry)
	local list = entry.list
	for i = 1, entry.count do
		list[i] = nil
	end
	entry.count = 0
end

local function recycleCurrentEntries(cache)
	local entries = cache.entries
	local activeEntries = cache.activeEntries
	for i = 1, cache.activeCount do
		local entry = activeEntries[i]
		releaseCandidates(entry)
		local cellX = entry.cellX
		local cellY = entry.cellY
		local footprintKey = entry.footprintKey
		local xEntries = entries[cellX]
		local yEntries = xEntries[cellY]
		yEntries[footprintKey] = nil
		if next(yEntries) == nil then
			xEntries[cellY] = nil
			if next(xEntries) == nil then
				entries[cellX] = nil
			end
		end
		entry.cellX = nil
		entry.cellY = nil
		entry.footprintKey = nil
		activeEntries[i] = nil
		if cache.poolCount < MAX_POOLED_ENTRIES then
			cache.poolCount = cache.poolCount + 1
			cache.pool[cache.poolCount] = entry
		end
	end
	cache.activeCount = 0
end

function Targeting.beginFrame(frameId)
	frameId = frameId or 0
	if frameCache.frameId == frameId then
		return
	end

	recycleCurrentEntries(frameCache)
	frameCache.frameId = frameId
end

function Targeting.clearFrameCache()
	recycleCurrentEntries(frameCache)
	-- A run reset also drains the reuse pool. Lists were scrubbed above (and are
	-- scrubbed before pooling), so neither active nor pooled buffers hold enemies.
	for i = 1, frameCache.poolCount do
		frameCache.pool[i] = nil
	end
	frameCache.poolCount = 0
	frameCache.frameId = nil
end

local function getCandidatesForTower(tower)
	local frameId = State.frameId or 0
	Targeting.beginFrame(frameId)
	local cx, cy = pointToCell(tower.x, tower.y)
	local footprintKey = localQueryFootprintKey(tower.range)
	local xEntries = frameCache.entries[cx]
	local yEntries = xEntries and xEntries[cy]
	local entry = yEntries and yEntries[footprintKey]
	if entry then
		return entry.list, entry.count
	end

	if not xEntries then
		xEntries = {}
		frameCache.entries[cx] = xEntries
	end
	if not yEntries then
		yEntries = {}
		xEntries[cy] = yEntries
	end

	if frameCache.poolCount > 0 then
		entry = frameCache.pool[frameCache.poolCount]
		frameCache.pool[frameCache.poolCount] = nil
		frameCache.poolCount = frameCache.poolCount - 1
	else
		entry = {list = {}, count = 0}
	end
	entry.cellX = cx
	entry.cellY = cy
	entry.footprintKey = footprintKey
	yEntries[footprintKey] = entry
	frameCache.activeCount = frameCache.activeCount + 1
	frameCache.activeEntries[frameCache.activeCount] = entry

	local list = entry.list

	local candidates, candidateCount = queryCellsLocal(tower.x, tower.y, tower.range, queryContext)
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
