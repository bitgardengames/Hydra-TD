-- Behavior implementations for the movement role.
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
B.move_homing = {
	update = function(p, dt)
		local e = p.target

		local tx, ty
		local alive = e and e.hp and e.hp > 0 and ((not p.targetID) or e.id == p.targetID)

		if alive then
			tx, ty = e.x, e.y
			p.lastTX, p.lastTY = tx, ty
		else
			if e and p.targetID and e.id ~= p.targetID then
				p.target = nil
			end
			tx, ty = p.lastTX, p.lastTY
		end

		if not tx then
			return
		end

		-- direction to target center (computed once)
		local dx = tx - p.x
		local dy = ty - p.y
		local dist2 = dx * dx + dy * dy

		local dist = sqrt(dist2)
		if dist < 1e-6 then
			dist = 1e-6
		end

		local inv = 1 / dist
		local nx = dx * inv
		local ny = dy * inv

		-- aim at enemy surface, derived from center-normalized direction
		local enemyRadius = (alive and e.radius) or 0
		local targetX = tx - nx * enemyRadius
		local targetY = ty - ny * enemyRadius

		local surfaceScale = dist - enemyRadius
		local surfaceDx = nx * surfaceScale
		local surfaceDy = ny * surfaceScale
		local surfaceDist = abs(surfaceScale)
		local surfaceDist2 = surfaceDist * surfaceDist

		local step = (p.speed or 0) * dt
		local step2 = step * step

		if surfaceDist2 <= step2 then
			p.x, p.y = targetX, targetY

			if alive then
				p.hit = e
			end

			return "consume"
		end

		-- normal movement
		local invSurfaceDist = 1 / surfaceDist
		p.x = p.x + surfaceDx * invSurfaceDist * step
		p.y = p.y + surfaceDy * invSurfaceDist * step

		p.rotation = atan2(surfaceDy, surfaceDx)
	end
}

B.move_linear = {
	type = "movement",

	init = function(p)
		local ang = p.angle or p.sourceTower.angle or 0
		p.vx = cos(ang)
		p.vy = sin(ang)
		p.rotation = ang
	end,

	update = function(p, dt)
		p.x = p.x + p.vx * p.speed * dt
		p.y = p.y + p.vy * p.speed * dt
	end
}

-- Fly to the target's position at the instant the projectile was created.
-- Unlike homing movement, this deliberately does not update the destination as
-- the enemy moves (or disappears), so an unguided shell always reaches and
-- detonates at its original aim point.

B.move_to_target_point = {
	type = "movement",

	init = function(p)
		local tx = p.lastTX
		local ty = p.lastTY
		local dx = tx - p.x
		local dy = ty - p.y
		local dist = sqrt(dx * dx + dy * dy)

		-- Carpet-fire children retain their angular spread while using the same
		-- range as the parent shell's snapshotted destination.
		if p.hitOrigin == "carpet_child" then
			local ang = p.angle or 0
			tx = p.x + cos(ang) * dist
			ty = p.y + sin(ang) * dist
			dx = tx - p.x
			dy = ty - p.y
		end

		p._targetPointX = tx
		p._targetPointY = ty

		if dist > 1e-6 then
			p.vx = dx / dist
			p.vy = dy / dist
		else
			p.vx = 0
			p.vy = 0
		end
		p.rotation = atan2(dy, dx)
	end,

	update = function(p, dt)
		local dx = p._targetPointX - p.x
		local dy = p._targetPointY - p.y
		local dist2 = dx * dx + dy * dy
		local step = (p.speed or 0) * dt

		if dist2 <= step * step or dist2 < 1e-12 then
			p.x = p._targetPointX
			p.y = p._targetPointY

			local evt = emitEvent(p, "hit")
			evt.target = nil
			evt.origin = p.hitOrigin or "primary"

			return "consume"
		end

		p.x = p.x + p.vx * step
		p.y = p.y + p.vy * step
	end
}

for id, handlers in pairs(B) do register(id, handlers) end
end
