local Util = require("core.util")
local State = require("core.state")

local Shock = {}

local dist2 = Util.dist2
local tinsert = table.insert

local function zapEnemy(ctx, from, e, dmg)
	e.hp = e.hp - dmg
	ctx.hit[e] = true

	tinsert(ctx.order, {from = from, to = e})

	-- Attribute damage
	local tower = ctx.tower

	tower.damageDealt = tower.damageDealt + dmg
	e.lastHitTower = tower

	State.addDamage("shock", dmg, e.boss == true)
end

function Shock.fire(sourceTower, initialTarget, enemies)
	if not initialTarget or initialTarget.hp <= 0 then
		return nil
	end

	local chain = sourceTower.chain

	if not chain then
		return nil
	end

	-- Context object (explicit instead of closure)
	local ctx = {tower = sourceTower, hit = {}, order = {}}

	-- First hit
	local damage = sourceTower.damage

	zapEnemy(ctx, sourceTower, initialTarget, damage)

	local last = initialTarget

	-- Chain jumps
	for _ = 1, chain.jumps do
		damage = damage * chain.falloff

		local best = nil
		local bestDist = chain.radius * chain.radius

		for _, e in ipairs(enemies) do
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

		zapEnemy(ctx, last, best, damage)

		last = best
	end

	return ctx.order
end

return Shock