local Util = require("core.util")
local State = require("core.state")
local Spatial = require("world.spatial_grid")

local Shock = {}

local dist2 = Util.dist2

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
		local n = #nearby

		for i = 1, n do
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