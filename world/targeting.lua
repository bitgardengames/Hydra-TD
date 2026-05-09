local Spatial = require("world.spatial_grid")

local Targeting = {}

local EPS = 0.0001
local HUGE_NEG = -math.huge
local queryCells = Spatial.queryCells
local forEachInCells = Spatial.forEachInCells
Targeting.MODES = {
	PROGRESS = "progress",
	LOW_HP = "low_hp",
	HIGH_HP = "high_hp",
	FARTHEST = "farthest",
}
local MODES = Targeting.MODES
local simpleCtx = {}

local function normalizeMode(mode)
	if mode == nil then
		return MODES.PROGRESS
	end

	if mode == MODES.PROGRESS or mode == MODES.LOW_HP or mode == MODES.HIGH_HP or mode == MODES.FARTHEST then
		return mode
	end

	return MODES.PROGRESS
end

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
	if c.mode == MODES.PROGRESS then
		score = e.dist
		if e.slowTimer > 0 then
			-- Slight deprioritization for slowed enemies
			score = score - 5
		end
	elseif c.mode == MODES.LOW_HP then
		score = -e.hp
	elseif c.mode == MODES.HIGH_HP then
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
