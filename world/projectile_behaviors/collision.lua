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
local SHARED_BEHAVIORS_LANCER_RICOCHET = ctx.SHARED_BEHAVIORS_LANCER_RICOCHET
local SHARED_BEHAVIORS_FROST_SHATTER = ctx.SHARED_BEHAVIORS_FROST_SHATTER
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

	onSpawn = function(p, data)
		p.hitRadius = data.radius
	end
}

B.instant_hit = {
	type = "damage",

	update = function(p, dt)
		local e = p.target

		if not e or e.hp <= 0 then
			return "consume"
		end

		p.x = e.x
		p.y = e.y

		local id = e.id or e

		if not projectileHasHit(p, id) and canHitTarget(p, e) then
			p.hit = e
		end

		return "consume"
	end
}

B.pierce = {
	init = function(p, data)
		data = data or {}

		p.pierce = {
			maxHits = data.maxHits or -1, -- -1 = infinite
			hits = 0,
			hitTargets = {}
		}

		p.allowRepeatHits = true
		p.consumeOnHit = false
	end,

	canHit = function(p, enemy)
		local pierce = p.pierce
		if not pierce then
			return true
		end

		return not pierce.hitTargets[enemy]
	end,

	onHit = function(p, enemy, data)
		local pierce = p.pierce
		if not pierce then
			return
		end

		pierce.hitTargets[enemy] = true
		pierce.hits = pierce.hits + 1

		if pierce.maxHits > 0 and pierce.hits >= pierce.maxHits then
			p.dead = true
		end
	end
}

B.projectile_radius = {
	init = function(p, data)
		local radius = data.radius
		if not radius then
			return
		end

		p.r = radius
		p.baseR = radius
		p.hitRadius = radius
		p.hitRadius2 = radius * radius
	end
}

for id, handlers in pairs(B) do register({ id = id, role = "collision", handlers = handlers }) end
end
