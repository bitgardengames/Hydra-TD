-- Behavior implementations for the collision role.
return function(ctx, register)
local B = {}
local min, max, sin, cos, sqrt, atan2, floor, random, abs, pi = ctx.min, ctx.max, ctx.sin, ctx.cos, ctx.sqrt, ctx.atan2, ctx.floor, ctx.random, ctx.abs, ctx.pi
local Constants, Spatial, lg = ctx.Constants, ctx.Spatial, ctx.lg
local spatialQueryContext = Spatial.newQueryContext(false)
local clearMap, clearArray = ctx.clearMap, ctx.clearArray
local emitEvent, emitFX, emitSpawnProjectile = ctx.emitEvent, ctx.emitFX, ctx.emitSpawnProjectile
local getStat, emitDamage, beginChainDamageBudget = ctx.getStat, ctx.emitDamage, ctx.beginChainDamageBudget
local consumeChainDamageBudget, emitImpulse = ctx.consumeChainDamageBudget, ctx.emitImpulse
local canHitTarget, projectileHasHit, canProcTarget = ctx.canHitTarget, ctx.projectileHasHit, ctx.canProcTarget
local getProjectileColor, colorMul, getTowerMuzzle = ctx.getProjectileColor, ctx.colorMul, ctx.getTowerMuzzle
B.hit_circle = {
	type = "damage",

	update = function(p, dt, data)
		local radius = data.radius
		if radius == nil then
			radius = p.hitRadius or p.r or 10
		end

		local nearby, nearbyCount = Spatial.querySquareCandidates(p.x, p.y, radius, spatialQueryContext)

		for i = 1, nearbyCount do
			local e = nearby[i]

			if e.hp > 0 and e ~= p.ignoreTarget then
				local dx = e.x - p.x
				local dy = e.y - p.y

				if dx*dx + dy*dy <= radius*radius then
					local id = e.id or e

					if not projectileHasHit(p, id) and canHitTarget(p, e) then
						p.hit = e

						if p.consumeOnHit ~= false then
							return "consume"
						end
					end
				end
			end
		end
	end,

	init = function(p, data)
		p.hitRadius = data.radius
	end
}

for id, handlers in pairs(B) do register(id, handlers) end
end
