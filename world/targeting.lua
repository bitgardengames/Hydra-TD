local Spatial = require("world.spatial_grid")

local Targeting = {}

local EPS = 0.0001
local HUGE_NEG = -math.huge
local queryCells = Spatial.queryCells
local forEachInCells = Spatial.forEachInCells
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
}
local MODES = Targeting.MODES
local MODE_ALIASES = {
	[MODES.PROGRESS] = SIMPLE_MODES.PROGRESS,
	[MODES.LOW_HP] = SIMPLE_MODES.LOW_HP,
	[MODES.HIGH_HP] = SIMPLE_MODES.HIGH_HP,
	[MODES.FARTHEST] = SIMPLE_MODES.FARTHEST,
	[SIMPLE_MODES.PROGRESS] = SIMPLE_MODES.PROGRESS,
	[SIMPLE_MODES.LOW_HP] = SIMPLE_MODES.LOW_HP,
	[SIMPLE_MODES.HIGH_HP] = SIMPLE_MODES.HIGH_HP,
	[SIMPLE_MODES.FARTHEST] = SIMPLE_MODES.FARTHEST,
}
local simpleCtx = {}

local function normalizeMode(mode)
	if mode == nil then
		return SIMPLE_MODES.PROGRESS
	end

	return MODE_ALIASES[mode] or SIMPLE_MODES.PROGRESS
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

-- Target enemy furthest along the path
function Targeting.findProgressTarget(tower)
	return Targeting.findTarget(tower, SIMPLE_MODES.PROGRESS)
end

function Targeting.findLowestHPTarget(tower)
	return Targeting.findTarget(tower, SIMPLE_MODES.LOW_HP)
end

function Targeting.findFarthestTarget(tower)
	return Targeting.findTarget(tower, SIMPLE_MODES.FARTHEST)
end

function Targeting.findHighestHPTarget(tower)
	return Targeting.findTarget(tower, SIMPLE_MODES.HIGH_HP)
end


function Targeting.findTarget(tower, mode)
	return pickSimpleTarget(tower, normalizeMode(mode))
end

return Targeting
