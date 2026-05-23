local Spatial = require("world.spatial_grid")
local State = require("core.state")

local Targeting = {}

local EPS = 0.0001
local HUGE_NEG = -math.huge
local floor = math.floor
local max = math.max
local pointToCell = Spatial.pointToCell
local queryCellsLocal = Spatial.queryCellsLocal
local INV_RADIUS_BUCKET = 0.25
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
	usedKeys = {},
	usedCount = 0,
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
	return score
end

local function scoreLowHp(e)
	return -e.hp
end

local function scoreHighHp(e)
	return e.hp
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

local function clearFrameCache(cache)
	local used = cache.usedKeys
	for i = 1, cache.usedCount do
		local entry = used[i]
		entry.count = 0
		local list = entry.list
		for j = 1, #list do
			list[j] = nil
		end
		used[i] = nil
	end
	cache.usedCount = 0
end

local function radiusBucket(range)
	return max(1, floor((range or 0) * INV_RADIUS_BUCKET + 0.5))
end

local function getCandidatesForTower(tower)
	local frameId = State.frameId or 0
	if frameCache.frameId ~= frameId then
		clearFrameCache(frameCache)
		frameCache.frameId = frameId
	end

	local cx, cy = pointToCell(tower.x, tower.y)
	local radiusKey = radiusBucket(tower.range)
	local entriesByX = frameCache.entries
	local entriesByY = entriesByX[cx]
	if not entriesByY then
		entriesByY = {}
		entriesByX[cx] = entriesByY
	end
	local entriesByRadius = entriesByY[cy]
	if not entriesByRadius then
		entriesByRadius = {}
		entriesByY[cy] = entriesByRadius
	end
	local entry = entriesByRadius[radiusKey]
	if entry then
		return entry.list, entry.count
	end

	entry = {
		list = {},
		count = 0,
	}
	entriesByRadius[radiusKey] = entry

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
	for i = count + 1, #list do
		list[i] = nil
	end
	entry.count = count

	local usedCount = frameCache.usedCount + 1
	frameCache.usedCount = usedCount
	frameCache.usedKeys[usedCount] = entry

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
