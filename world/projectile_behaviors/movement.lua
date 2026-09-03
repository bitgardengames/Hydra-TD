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
local SHARED_BEHAVIORS_LANCER_RICOCHET = ctx.SHARED_BEHAVIORS_LANCER_RICOCHET
local SHARED_BEHAVIORS_FROST_SHATTER = ctx.SHARED_BEHAVIORS_FROST_SHATTER
B.retarget_on_spawn = {
	init = function(p, data)
		local radius = data.radius or 72
		local r2 = radius * radius

		local best = nil
		local bestDist = r2

		local nearby, nearbyCount = Spatial.querySquareCandidates(p.x, p.y, radius, spatialQueryContext)

		for i = 1, nearbyCount do
			local e = nearby[i]

			if e.hp > 0 and e ~= p.ignoreTarget then
				local dx = e.x - p.x
				local dy = e.y - p.y
				local d2 = dx*dx + dy*dy

				if d2 < bestDist then
					bestDist = d2
					best = e
				end
			end
		end

		-- assign new target if found
		if best then
			p.target = best
			p.targetID = best.id
			p.lastTX = best.x
			p.lastTY = best.y
		end
	end
}

-- =========================
-- MOVEMENT
-- =========================

-- This needs to be written better, absolutely disgusting. NO HARD CODING.

B.move_homing = {
	type = "movement",

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

		local step = (p.speed or 0) * dt
		-- Treat the projectile and target as circles. In particular, do not use
		-- abs(dist - radius) here: once a fast projectile crosses the target's
		-- surface that value makes it steer back out of the enemy instead of
		-- resolving the overlap as a hit.
		-- The projectile is drawn around its center, so bring that center to the
		-- enemy surface. Including the projectile radius here makes larger shots
		-- (notably Lancer's 12px collision profile) hit and emit their impact
		-- particles visibly short of the enemy.
		local contactRadius = alive and (e.radius or 0) or 0
		local distanceToContact = dist - contactRadius

		if distanceToContact <= step then
			-- Keep an already-overlapping projectile where it is; otherwise stop it
			-- at the first point of contact so impact effects are positioned there.
			if distanceToContact > 0 then
				p.x = p.x + nx * distanceToContact
				p.y = p.y + ny * distanceToContact
			end

			if alive then
				p.hit = e
			end

			return "consume"
		end

		-- normal movement
		p.x = p.x + nx * step
		p.y = p.y + ny * step

		p.rotation = atan2(dy, dx)
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

B.move_boomerang = {
	type = "movement",

	init = function(p, data)
		local ang = p.angle or p.sourceTower.angle or 0

		p._boom = {
			dirX = cos(ang),
			dirY = sin(ang),
			dist = 0,
			maxDist = data.dist or 140,
			speed = p.speed or 140,
			state = "out"
		}

		p.vx = p._boom.dirX
		p.vy = p._boom.dirY
	end,

	update = function(p, dt, data)
		local b = p._boom
		local spd = b.speed

		local oldX, oldY = p.x, p.y

		if b.state == "out" then
			p.vx = b.dirX
			p.vy = b.dirY

			p.x = p.x + p.vx * spd * dt
			p.y = p.y + p.vy * spd * dt

			b.dist = b.dist + spd * dt

			if b.dist >= b.maxDist then
				b.state = "return"
			end

		else
			local t = p.sourceTower
			local dx = t.x - p.x
			local dy = t.renderY - p.y

			local d = sqrt(dx*dx + dy*dy)

			if d < 8 then
				return "consume"
			end

			local inv = 1 / d

			p.vx = dx * inv
			p.vy = dy * inv

			p.x = p.x + p.vx * spd * dt
			p.y = p.y + p.vy * spd * dt
		end

		p.rotation = atan2(p.vy, p.vx)
	end
}

B.move_orbit = {
	type = "movement",

	init = function(p, data)
		p.cx = p.x
		p.cy = p.y

		p.angle = p.sourceTower.angle or 0
		p.radius = data.radius or 40
		p.orbitSpeed = data.speed or 4

		-- NEW
		p._orbit = {
			state = "launch",
			dist = 0,
			launchSpeed = data.launchSpeed or 220
		}
	end,

	update = function(p, dt)
		local o = p._orbit

		if o.state == "launch" then
			-- move outward from center
			o.dist = o.dist + o.launchSpeed * dt

			if o.dist >= p.radius then
				o.dist = p.radius
				o.state = "orbit"
			end

			p.x = p.cx + cos(p.angle) * o.dist
			p.y = p.cy + sin(p.angle) * o.dist

		else
			-- orbit normally
			p.angle = p.angle + p.orbitSpeed * dt

			p.x = p.cx + cos(p.angle) * p.radius
			p.y = p.cy + sin(p.angle) * p.radius
		end
	end
}

B.move_enemy_orbit = {
	init = function(p, data)
		p._orbitE = {
			target = p.target,
			angle = 0,
			radius = data.radius or 32
		}
	end,

	update = function(p, dt)
		local o = p._orbitE
		local e = o.target

		if not e or e.hp <= 0 then return end

		o.angle = o.angle + 4 * dt

		p.x = e.x + cos(o.angle) * o.radius
		p.y = e.y + sin(o.angle) * o.radius
	end
}

B.move_spiral = {
	type = "movement",

	init = function(p, data)
		local ang = p.angle or p.sourceTower.angle or 0

		p._spiral = {
			baseX = p.x,
			baseY = p.y,
			dirX = cos(ang),
			dirY = sin(ang),
			t = 0,
			freq = data.freq or 6,
			amp = data.amp or 12
		}

		p.rotation = ang
	end,

	update = function(p, dt)
		local s = p._spiral
		s.t = s.t + dt

		local forward = (p.speed or 0) * dt

		-- move forward
		s.baseX = s.baseX + s.dirX * forward
		s.baseY = s.baseY + s.dirY * forward

		-- perpendicular offset
		local px = -s.dirY
		local py = s.dirX

		local wave = sin(s.t * s.freq) * s.amp

		p.x = s.baseX + px * wave
		p.y = s.baseY + py * wave
	end
}

B.move_wave = {
	type = "movement",

	init = function(p, data)
		local ang = p.angle or p.sourceTower.angle or 0

		p._wave = {
			baseX = p.x,
			baseY = p.y,
			dirX = cos(ang),
			dirY = sin(ang),
			t = 0,
			amp = data.amp or 24,
			freq = data.freq or 5
		}
	end,

	update = function(p, dt)
		local w = p._wave
		w.t = w.t + dt

		local speed = p.speed * dt

		-- forward
		w.baseX = w.baseX + w.dirX * speed
		w.baseY = w.baseY + w.dirY * speed

		-- perpendicular wave
		local px = -w.dirY
		local py = w.dirX

		local offset = sin(w.t * w.freq) * w.amp

		p.x = w.baseX + px * offset
		p.y = w.baseY + py * offset
	end
}

B.move_suspend = {
	init = function(p, data)
		p._suspend = {
			timer = data.delay or 0.5,
			released = false
		}
	end,

	update = function(p, dt)
		local s = p._suspend

		if not s.released then
			s.timer = s.timer - dt
			if s.timer <= 0 then
				s.released = true
			end
			return
		end

		-- after release → normal movement
		return B.move_linear.update(p, dt)
	end
}

-- =========================
-- DAMAGE
-- =========================

B.stationary = {
	update = function() end
}

for id, handlers in pairs(B) do register({ id = id, role = "movement", handlers = handlers }) end
end
