local Spatial = require("world.spatial_grid")
local State = require("core.state")
local EnemyPhase = require("world.enemy_phase")

local Targeting = {}

local EPS = 0.0001
local HUGE_NEG = -math.huge
local pointToCell = Spatial.pointToCell
local visitCellsLocal = Spatial.visitCellsLocal
local queryContext = Spatial.newQueryContext(false)
local localQueryFootprintKey = Spatial.localQueryFootprintKey
local simpleCtx = {}
local frameCache = {
	entries = {},
	frameId = nil,
}
local function updateBest(e, c, score)
	local diff = score - c.bestScore
	if diff > EPS or (diff >= -EPS and (not c.best or e.id < c.best.id)) then
		c.bestScore = score
		c.best = e
	end
end

local function evaluateCandidate(e, c)
	if e.hp <= 0 or e.dying or not EnemyPhase.canDirectHit(e) then
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

function Targeting.beginFrame(frameId)
	frameId = frameId or 0
	frameCache.frameId = frameId
end

function Targeting.clearFrameCache()
	for cellX, xEntries in pairs(frameCache.entries) do
		for _, yEntries in pairs(xEntries) do
			for _, entry in pairs(yEntries) do
				for i = 1, entry.count do entry.list[i] = nil end
				entry.count = 0
				entry.fillCount = nil
				entry.frameId = nil
			end
		end
		frameCache.entries[cellX] = nil
	end
	frameCache.frameId = nil
end

local function retainTargetableCandidate(enemy, entry)
	if enemy.hp > 0 and not enemy.dying and EnemyPhase.canDirectHit(enemy) then
		entry.fillCount = entry.fillCount + 1
		entry.list[entry.fillCount] = enemy
	end
end

local function getCandidatesForTower(tower)
	local frameId = State.frameId or 0
	Targeting.beginFrame(frameId)
	local cx, cy = pointToCell(tower.x, tower.y)
	local footprintKey = localQueryFootprintKey(tower.range)
	local xEntries = frameCache.entries[cx]
	local yEntries = xEntries and xEntries[cy]
	local entry = yEntries and yEntries[footprintKey]
	if entry and entry.frameId == frameId then
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

	if not entry then
		entry = {list = {}, count = 0}
		yEntries[footprintKey] = entry
	end

	local previousCount = entry.count
	entry.fillCount = 0
	visitCellsLocal(tower.x, tower.y, tower.range, retainTargetableCandidate, entry, queryContext)
	local count = entry.fillCount
	for i = count + 1, previousCount do
		entry.list[i] = nil
	end
	entry.count = count
	entry.frameId = frameId

	return entry.list, count
end

function Targeting.isSemanticallyValidTarget(tower, e)
	if not Targeting.isTargetEntityValid(e) or e.hp <= 0 or e.dying or not EnemyPhase.canDirectHit(e) then
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
