local Util = require("core.util")
local State = require("core.state")
local Spatial = require("world.spatial_grid")

local Shock = {}

local dist2 = Util.dist2
local random = love.math.random
local abs = math.abs

local nextID = 0
local EPS = 0.0001

-- Reusable context
local ctx = {
	tower = nil,
	order = {}
}

local function resetContext(tower)
	ctx.tower = tower

	local order = ctx.order

	for i = 1, #order do
		order[i] = nil
	end
end

local function addLink(from, to)
	local order = ctx.order
	local i = #order + 1

	local link = order[i]

	if not link then
		link = {}
		order[i] = link
	end

	link.from = from
	link.to = to
end

local minPush = 0.35 -- Ensure minimum push

local function applyHitImpulse(e, fromX, fromY, strength)
	local ex = e.x
	local ey = e.y

	local dx = ex - fromX
	local dy = ey - fromY

	-- Cheap "normalization" (no sqrt)
	local denom = abs(dx) + abs(dy) + 1
	dx = dx / denom
	dy = dy / denom

	-- Use sim tangent
	local tx = e.simPathDX or 1
	local ty = e.simPathDY or 0

	-- Path normal
	local nx = -ty
	local ny = tx

	local lateral = dx * nx + dy * ny

	if lateral > -minPush and lateral < minPush then
		if lateral >= 0 then
			lateral = minPush
		else
			lateral = -minPush
		end
	end

	e.lateralVelocity = e.lateralVelocity + lateral * strength

	-- Clamp
	if e.lateralVelocity > 120 then
		e.lateralVelocity = 120
	elseif e.lateralVelocity < -120 then
		e.lateralVelocity = -120
	end
end

local function zapEnemy(from, e, dmg)
	e.hp = e.hp - dmg

	if e.hitFlash <= 0 then
		e.hitFlash = 0.05
	end

	-- Knockback and jitter
	if not e.boss then
		applyHitImpulse(e, from.x, from.y, 48)
	end

	addLink(from, e)

	local tower = ctx.tower
	tower.damageDealt = tower.damageDealt + dmg
	e.lastHitTower = tower

	State.addDamage("shock", dmg, e.boss == true)
end

function Shock.fire(sourceTower, initialTarget)
	if not initialTarget or initialTarget.hp <= 0 then
		return nil
	end

	local chain = sourceTower.chain

	if not chain then
		return nil
	end


	resetContext(sourceTower)

	nextID = nextID + 1
	local shockID = nextID

	local damage = sourceTower.damage

	-- First hit
	initialTarget.shockID = shockID
	zapEnemy(sourceTower, initialTarget, damage)

	local last = initialTarget
	local radius2 = chain.radius * chain.radius
	local falloff = chain.falloff

	for _ = 1, chain.jumps do
		damage = damage * falloff

		local best = nil
		local bestDist = math.huge

		local nearby = Spatial.queryCells(last.x, last.y)

		for i = 1, #nearby do
			local e = nearby[i]

			if e.hp > 0 and not e.dying and e.shockID ~= shockID then
				local d = dist2(last.x, last.y, e.x, e.y)
				local diff = d - bestDist

				if diff < -EPS or (diff <= EPS and (not best or e.id < best.id)) then
					bestDist = d
					best = e
				end
			end
		end

		-- Stop if nothing valid or out of range
		if not best or bestDist > radius2 then
			break
		end

		-- Mark as hit before applying damage
		best.shockID = shockID

		zapEnemy(last, best, damage)

		last = best
	end

	return ctx.order
end

return Shock