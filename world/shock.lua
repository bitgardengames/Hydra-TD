local Util = require("core.util")
local State = require("core.state")
local Spatial = require("world.spatial_grid")

local Shock = {}

local dist2 = Util.dist2
local random = love.math.random
local sqrt = math.sqrt

-- Reusable context
local ctx = {
	tower = nil,
	hit = {},
	order = {}
}

local function resetContext(tower)
	ctx.tower = tower

	local hit = ctx.hit

	for k in pairs(hit) do
		hit[k] = nil
	end

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

local function zapEnemy(from, e, dmg)
	e.hp = e.hp - dmg
	ctx.hit[e] = true

	if e.hitFlash <= 0 then
		e.hitFlash = 0.05
	end

	-- Subtle nudge
	if not e.boss then
		local dx, dy

		if from then
			dx = e.x - from.x
			dy = e.y - from.y
		else
			-- First hit from tower
			dx = e.x - sourceTower.x
			dy = e.y - sourceTower.y
		end

		local len = sqrt(dx * dx + dy * dy)

		if len > 0 then
			dx = dx / len
			dy = dy / len
		end

		local strength = 0.25

		e.hitVelX = (e.hitVelX or 0) + dx * strength
		e.hitVelY = (e.hitVelY or 0) + dy * strength
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

	local damage = sourceTower.damage

	-- First hit
	zapEnemy(sourceTower, initialTarget, damage)

	local last = initialTarget
	local radius2 = chain.radius * chain.radius
	local falloff = chain.falloff

	for _ = 1, chain.jumps do
		damage = damage * falloff

		local best = nil
		local bestDist = radius2

		local nearby = Spatial.queryCells(last.x, last.y)

		for i = 1, #nearby do
			local e = nearby[i]

			if not ctx.hit[e] and e.hp > 0 then
				local d = dist2(last.x, last.y, e.x, e.y)

				if d <= bestDist then
					bestDist = d
					best = e
				end
			end
		end

		if not best then
			break
		end

		zapEnemy(last, best, damage)
		last = best
	end

	return ctx.order
end

return Shock