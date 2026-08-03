local Spatial = require("world.spatial_grid")
local State = require("core.state")

local Targeting = {}

local EPS = 0.0001
local HUGE_NEG = -math.huge
local pointToCell = Spatial.pointToCell
local queryCellsLocal = Spatial.queryCellsLocal
local localQueryFootprintKey = Spatial.localQueryFootprintKey
Targeting.MODES = {
	PROGRESS = "progress",
	LOW_HP = "low_hp",
	HIGH_HP = "high_hp",
	FARTHEST = "farthest",
}
local MODES = Targeting.MODES
local simpleCtx = {}
-- Frame cache uses nested integer-keyed tables to reduce temporary string
-- allocations and GC spikes from composed cache keys.
local frameCache = {
	frameId = -1,
	entries = {},
}
local validModes = {
	[MODES.PROGRESS] = true,
	[MODES.LOW_HP] = true,
	[MODES.HIGH_HP] = true,
	[MODES.FARTHEST] = true,
}

local function normalizeMode(mode)
	if validModes[mode] then
		return mode
	end
	return MODES.PROGRESS
end

local function updateBest(e, c, score)
	local diff = score - c.bestScore
	if diff > EPS or (diff >= -EPS and (not c.best or e.id < c.best.id)) then
		c.bestScore = score
		c.best = e
	end
end

local function scoreProgress(e)
	local score = e.dist
	if e.slowTimer > 0 then
		score = score - 5
	end
	score = score + ((e.def and e.def.targetPriority) or 0)
	return score
end

local function scoreLowHp(e)
	return -(e.hp + (e.shieldHp or 0))
end

local function scoreHighHp(e)
	return e.hp + (e.shieldHp or 0)
end

local function scoreFarthest(_, _, d2)
	return d2
end

local scoreByMode = {
	[MODES.PROGRESS] = scoreProgress,
	[MODES.LOW_HP] = scoreLowHp,
	[MODES.HIGH_HP] = scoreHighHp,
	[MODES.FARTHEST] = scoreFarthest,
}

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

	updateBest(e, c, c.scoreFn(e, c, d2))
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
		entry = {
			list = {},
			count = 0,
			frameId = -1,
		}
		entriesByFootprint[footprintKey] = entry
	end

	local previousCount = entry.count
	entry.count = 0
	entry.frameId = frameId

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
	for i = count + 1, previousCount do
		list[i] = nil
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

function Targeting.findTarget(tower, mode)
	local ctx = simpleCtx
	ctx.best = nil
	ctx.bestScore = HUGE_NEG
	ctx.r2 = tower.range2
	ctx.tx = tower.x
	ctx.ty = tower.y
	ctx.scoreFn = scoreByMode[normalizeMode(mode)]
	local candidates, count = getCandidatesForTower(tower)
	for i = 1, count do
		evaluateCandidate(candidates[i], ctx)
	end

	ctx.scoreFn = nil
	return ctx.best
end

for aliasName, mode in pairs({
	findProgressTarget = MODES.PROGRESS,
	findLowestHPTarget = MODES.LOW_HP,
	findFarthestTarget = MODES.FARTHEST,
	findHighestHPTarget = MODES.HIGH_HP,
}) do
	Targeting[aliasName] = function(tower)
		return Targeting.findTarget(tower, mode)
	end
end

return Targeting
