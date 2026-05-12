local Spatial = require("world.spatial_grid")

local Targeting = {}

local EPS = 0.0001
local HUGE_NEG = -math.huge
local forEachInCells = Spatial.forEachInCells
Targeting.MODES = {
	PROGRESS = "progress",
	LOW_HP = "low_hp",
	HIGH_HP = "high_hp",
	FARTHEST = "farthest",
}
local MODES = Targeting.MODES
local simpleCtx = {}
local validModes = {
	[MODES.PROGRESS] = true,
	[MODES.LOW_HP] = true,
	[MODES.HIGH_HP] = true,
	[MODES.FARTHEST] = true,
}

local function normalizeMode(mode)
	if mode == nil then
		return MODES.PROGRESS
	end

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

local function evaluateProgressCandidate(e, c)
	if e.hp <= 0 or e.dying then
		return
	end

	local dx = e.x - c.tx
	local dy = e.y - c.ty
	local d2 = dx * dx + dy * dy

	if d2 > c.r2 then
		return
	end

	local score = e.dist
	if e.slowTimer > 0 then
		score = score - 5
	end

	updateBest(e, c, score)
end

local function evaluateLowHpCandidate(e, c)
	if e.hp <= 0 or e.dying then
		return
	end

	local dx = e.x - c.tx
	local dy = e.y - c.ty
	if dx * dx + dy * dy > c.r2 then
		return
	end

	updateBest(e, c, -e.hp)
end

local function evaluateHighHpCandidate(e, c)
	if e.hp <= 0 or e.dying then
		return
	end

	local dx = e.x - c.tx
	local dy = e.y - c.ty
	if dx * dx + dy * dy > c.r2 then
		return
	end

	updateBest(e, c, e.hp)
end

local function evaluateFarthestCandidate(e, c)
	if e.hp <= 0 or e.dying then
		return
	end

	local dx = e.x - c.tx
	local dy = e.y - c.ty
	local d2 = dx * dx + dy * dy
	if d2 > c.r2 then
		return
	end

	updateBest(e, c, d2)
end

local evaluatorsByMode = {
	[MODES.PROGRESS] = evaluateProgressCandidate,
	[MODES.LOW_HP] = evaluateLowHpCandidate,
	[MODES.HIGH_HP] = evaluateHighHpCandidate,
	[MODES.FARTHEST] = evaluateFarthestCandidate,
}

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

function Targeting.isValidTarget(tower, e)
	return Targeting.isSemanticallyValidTarget(tower, e)
end

local function pickSimpleTarget(tower, mode)
	local ctx = simpleCtx
	ctx.best = nil
	ctx.bestScore = HUGE_NEG
	ctx.r2 = tower.range2
	ctx.tx = tower.x
	ctx.ty = tower.y

	forEachInCells(tower.x, tower.y, tower.range, evaluatorsByMode[mode] or evaluateProgressCandidate, ctx)

	return ctx.best
end

function Targeting.findTarget(tower, mode)
	return pickSimpleTarget(tower, normalizeMode(mode))
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
