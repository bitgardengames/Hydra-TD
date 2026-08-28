-- Behavior implementations for the emission role.
return function(ctx, register)
local B = {}
local min, max, sin, cos, sqrt, atan2, floor, random, abs, pi = ctx.min, ctx.max, ctx.sin, ctx.cos, ctx.sqrt, ctx.atan2, ctx.floor, ctx.random, ctx.abs, ctx.pi
local Constants, Spatial, lg = ctx.Constants, ctx.Spatial, ctx.lg
local clearMap, clearArray = ctx.clearMap, ctx.clearArray
local emitEvent, emitFX, emitSpawnProjectile = ctx.emitEvent, ctx.emitFX, ctx.emitSpawnProjectile
local getStat, emitDamage, beginChainDamageBudget = ctx.getStat, ctx.emitDamage, ctx.beginChainDamageBudget
local consumeChainDamageBudget, emitImpulse = ctx.consumeChainDamageBudget, ctx.emitImpulse
local canHitTarget, projectileHasHit, canProcTarget = ctx.canHitTarget, ctx.projectileHasHit, ctx.canProcTarget
local getProjectileColor, colorMul, getTowerMuzzle = ctx.getProjectileColor, ctx.colorMul, ctx.getTowerMuzzle
local SHARED_BEHAVIORS_LANCER_RICOCHET = ctx.SHARED_BEHAVIORS_LANCER_RICOCHET
local SHARED_BEHAVIORS_FROST_SHATTER = ctx.SHARED_BEHAVIORS_FROST_SHATTER
B.emit_on_target = {
	type = "emission",

	update = function(p, dt)
		local e = p.target

		if not e or e.hp <= 0 then
			return "consume"
		end

		-- snap to target (so FX origin is correct)
		p.x = e.x
		p.y = e.y

		-- trigger hit pipeline
		local evt = emitEvent(p, "hit")
		evt.target = e
		evt.origin = p.hitOrigin or "primary"

		return "consume"
	end
}

B.cannon_carpet_fire = {
	init = function(p, data)
		if p.hitOrigin == "carpet_child" then
			return
		end

		p._carpetFire = {
			tA = data.delayA or 0.08,
			tB = data.delayB or 0.16,
			spread = data.spread or 0.16,
			firedA = false,
			firedB = false,
		}
	end,

	update = function(p, dt)
		local c = p._carpetFire
		if not c then
			return
		end

		c.tA = c.tA - dt
		c.tB = c.tB - dt

		local source = p.sourceTower
		if not source then
			return
		end

		local function spawnWithOffset(offset)
			local x, y = getTowerMuzzle(source)
			local tx = (p.target and p.target.x) or p.lastTX or (x + cos(p.angle or 0) * 100)
			local ty = (p.target and p.target.y) or p.lastTY or (y + sin(p.angle or 0) * 100)
			local ang = atan2(ty - y, tx - x) + offset

			local evt = emitSpawnProjectile(p)
			evt.source = source
			evt.x = x
			evt.y = y
			evt.angle = ang
			evt.lastTX = tx
			evt.lastTY = ty
			evt.damage = p.damage
			evt.hitOrigin = "carpet_child"
		end

		if not c.firedA and c.tA <= 0 then
			c.firedA = true
			spawnWithOffset(-c.spread)
		end

		if not c.firedB and c.tB <= 0 then
			c.firedB = true
			spawnWithOffset(c.spread)
		end
	end
}

B.fork_chain = {
	type = "damage",

	onHit = function(p, e, data)
		if not p._chain then return end
		data = data or {}
		local radius = data.radius or 48
		local radius2 = radius * radius
		local dmgMult = data.dmgMult or 0.35
		local forksPerLink = max(1, data.forksPerLink or 1)

		local forks = p._forksScratch
		if forks then
			clearArray(forks)
		else
			forks = {}
			p._forksScratch = forks
		end

		local claimed = p._claimedScratch
		if claimed then
			clearMap(claimed)
		else
			claimed = {}
			p._claimedScratch = claimed
		end

		-- Forks should be "extra side arcs", so avoid spending fork damage on
		-- enemies already hit by the main chain.
		for i = 1, #p._chain do
			local chained = p._chain[i].to
			if chained then
				claimed[chained] = true
			end
		end

		for i = 1, #p._chain do
			local link = p._chain[i]

			if link.to and link.to.hp > 0 then
				local nearby, nearbyCount = Spatial.queryCells(link.to.x, link.to.y, radius)

				local forksAdded = 0

				for j = 1, nearbyCount do
					local other = nearby[j]
					local dx = other.x - link.to.x
					local dy = other.y - link.to.y
					local d2 = dx * dx + dy * dy

					if other ~= link.to and other.hp > 0 and d2 <= radius2 and not claimed[other] then
						local nextFork = #forks + 1
						local fork = forks[nextFork] or {}
						fork.from = link.to
						fork.to = other
						forks[nextFork] = fork
						claimed[other] = true
						local forkDmg = consumeChainDamageBudget(p, (p.damage or 0) * dmgMult)
						if forkDmg > 0 then
							emitDamage(p, other, forkDmg)
						end
						forksAdded = forksAdded + 1

						if forksAdded >= forksPerLink then
							break
						end
					end
				end
			end
		end

		for i = 1, #forks do
			p._chain[#p._chain + 1] = forks[i]
		end
	end
}

B.split_on_hit = {
	type = "damage",

	onHit = function(p, e, data)
		if e and not canProcTarget(p, "split_on_hit", e, (data and data.targetCooldown) or 0.08) then
			return
		end

		data = data or {}

		local count = data.count or 2
		local spread = data.spread or 0.35 -- radians (~20° total default)
		local dmgMult = data.dmgMult or 0.6
		local parentSplitGen = p.splitGeneration or 0
		local childSplitGen = parentSplitGen + 1
		local childDamageDecay = data.childDamageDecay or 0.85
		local childTravelDecay = data.childTravelDecay or 0.7
		local childTravelMin = data.childTravelMin or 380
		local baseTravelDistance = data.travelDistance or 2000
		local childDamageMult = dmgMult * (childDamageDecay ^ parentSplitGen)
		local childTravelDistance = max(childTravelMin, baseTravelDistance * (childTravelDecay ^ parentSplitGen))

		-- Forward direction (toward/through target)
		local baseVX = p.vx or cos(p.rotation or 0)
		local baseVY = p.vy or sin(p.rotation or 0)
		local baseMag = sqrt(baseVX * baseVX + baseVY * baseVY)

		if baseMag < 1e-6 then
			baseVX = cos(p.rotation or 0)
			baseVY = sin(p.rotation or 0)
			baseMag = sqrt(baseVX * baseVX + baseVY * baseVY)
		end

		if baseMag < 1e-6 then
			baseVX, baseVY = 1, 0
			baseMag = 1
		end

		baseVX = baseVX / baseMag
		baseVY = baseVY / baseMag

		local base = atan2(baseVY, baseVX)
		local hitRadius = (e and e.radius) or 12
		local spawnOffset = hitRadius + (data.spawnOffset or 6)
		local spawnX = p.x + baseVX * spawnOffset
		local spawnY = p.y + baseVY * spawnOffset

		-- If only 1 projectile, just shoot forward
		if count == 1 then
			local evt = emitSpawnProjectile(p)
			evt.x = spawnX
			evt.y = spawnY
			evt.angle = base
			evt.lastTX = spawnX + cos(base) * childTravelDistance
			evt.lastTY = spawnY + sin(base) * childTravelDistance
			evt.damage = (p.damage or 0) * childDamageMult
			evt.source = p.sourceTower
			evt.parent = p
			evt.ignoreTarget = e
			evt.splitGeneration = childSplitGen
			return
		end

		-- Spread evenly across cone
		for i = 1, count do
			local t = (i - 1) / (count - 1) -- 0 → 1
			local offset = (t - 0.5) * spread

			local ang = base + offset

			local evt = emitSpawnProjectile(p)
			evt.x = spawnX
			evt.y = spawnY
			evt.angle = ang
			evt.lastTX = spawnX + cos(ang) * childTravelDistance
			evt.lastTY = spawnY + sin(ang) * childTravelDistance
			evt.damage = (p.damage or 0) * childDamageMult
			evt.source = p.sourceTower
			evt.parent = p
			evt.ignoreTarget = e
			evt.splitGeneration = childSplitGen
		end

		local fxEvt = emitFX(p, "lancer_hit")
		fxEvt.x = p.x
		fxEvt.y = p.y

		return "consume"
	end
}

B.lancer_ricochet = {
	onHit = function(p, e, data)
		if not e then
			return
		end

		local radius = data.radius or 90
		local r2 = radius * radius

		local nearby, nearbyCount = Spatial.queryCells(e.x, e.y, radius)

		local best = nil
		local bestDist = r2

		for i = 1, nearbyCount do
			local other = nearby[i]

			if other ~= e and other.hp > 0 then
				local dx = other.x - e.x
				local dy = other.y - e.y
				local d2 = dx*dx + dy*dy

				if d2 <= bestDist then
					bestDist = d2
					best = other
				end
			end
		end

		if best then
			local dx = best.x - e.x
			local dy = best.y - e.y
			local dist = sqrt(dx * dx + dy * dy)
			local nx, ny = 0, 0

			if dist > 0.001 then
				nx = dx / dist
				ny = dy / dist
			end

			local evt = emitSpawnProjectile(p)
			evt.x = e.x + nx * 8
			evt.y = e.y + ny * 8
			evt.source = p.sourceTower
			evt.target = best
			evt.damage = p.damage * 0.8
			evt.ignoreTarget = e
			evt.behaviors = SHARED_BEHAVIORS_LANCER_RICOCHET
		end
	end
}

B.lancer_sustained_barrage = {
	onHit = function(p, e, data)
		if not e or e.hp <= 0 then
			return
		end

		local tower = p.sourceTower
		if not tower then
			return
		end

		data = data or {}
		local cycleShots = max(1, floor(data.cycleShots or 6))
		local burstShots = min(cycleShots, max(1, floor(data.burstShots or 3)))
		local bonusDmgMult = data.bonusDmgMult or 0.45

		local shotIndex = (tower._lancerBarrageShotIndex or 0) + 1
		if shotIndex > cycleShots then
			shotIndex = 1
		end
		tower._lancerBarrageShotIndex = shotIndex

		if shotIndex > burstShots then
			return
		end

		emitDamage(p, e, (p.damage or 0) * bonusDmgMult)
	end
}

B.frost_shatter = {
	onHit = function(p, e, data)
		if not e or e.hp <= 0 then
			return
		end

		if not e.slowTimer or e.slowTimer <= 0 then
			return
		end

		local count = data.count or 5
		local dmgMult = data.dmgMult or 0.5

		for i = 1, count do
			local ang = random() * (pi * 2)

			local evt = emitSpawnProjectile(p)
			evt.x = e.x
			evt.y = e.y
			evt.angle = ang
			evt.damage = (p.damage or 0) * dmgMult
			evt.source = p.sourceTower
			evt.behaviors = SHARED_BEHAVIORS_FROST_SHATTER
		end

		local fxEvt = emitFX(p, "frost_burst")
		fxEvt.x = e.x
		fxEvt.y = e.y
		fxEvt.color = p.sourceTower and p.sourceTower.color
	end
}

B.spawn_static_field = {
	onHit = function(p, e, data)
		local evt = emitSpawnProjectile(p)
		evt.x = p.x
		evt.y = p.y
		evt.source = p.sourceTower
		evt.damage = p.damage * (data.dmgMult or 0.4)
		evt.behaviors = {
			{ id = "stationary" },
			{ id = "tick_damage", data = { radius = data.radius or 48, rate = 0.3 } },
			{ id = "draw_static_field" }
		}
	end
}

B.spawn_orbital_on_hit = {
	onHit = function(p, e, data, ctx)
		if ctx and ctx.origin ~= "primary" then
			return
		end

		if not e or e.hp <= 0 then
			return
		end
		if not canProcTarget(p, "spawn_orbital_on_hit", e, (data and data.targetCooldown) or 0.2) then
			return
		end

		local count = data.count or 2
		local spawnRadius = (e.radius or 12) + 6

		for i = 1, count do
			local ang = ((i - 1) / count) * pi * 2

			local ox = cos(ang) * spawnRadius
			local oy = sin(ang) * spawnRadius

			local evt = emitSpawnProjectile(p)
			evt.hitOrigin = "secondary"
			evt.x = e.x + ox
			evt.y = e.y + oy
			evt.angle = ang
			evt.source = p.sourceTower
			evt.target = e
			evt.damage = p.damage * 0.4
			evt.ignoreTarget = e
			evt.behaviors = {
				{ id = "move_enemy_orbit", data = { radius = 32 } },
				{ id = "tick_damage", data = { radius = 28, rate = 0.25 } },
				{ id = "draw_shock_orb" }
			}
		end
	end
}

B.poison_burst_on_death = {
	onDeath = function(e)
		local spread = e._infectSpread
		if not spread then return end

		local nearby, nearbyCount = Spatial.queryCells(e.x, e.y, spread.radius)
		local radius = spread.radius
		local r2 = radius * radius

		for i = 1, nearbyCount do
			local other = nearby[i]

			if other ~= e and other.hp > 0 then
				local dx = other.x - e.x
				local dy = other.y - e.y

				if dx*dx + dy*dy <= r2 then
					-- APPLY POISON (not damage)
					other.poisonStacks = (other.poisonStacks or 0) + (e.poisonStacks or 0)
					other.poisonTimer = max(other.poisonTimer or 0, 1.5)
				end
			end
		end

		e._infectSpread = nil -- VERY IMPORTANT (prevents re-trigger)
	end
}

B.beam = {
	type = "output",

	init = function(p, data)
		p._beam = {
			length = data.length or 180,
			width = data.width or (p.r or 6),
			rate = data.rate or 0.1,
			timer = 0,
			hitCooldown = {}
		}

		local ang = p.angle or (p.sourceTower and p.sourceTower.angle) or 0
		p.vx = math.cos(ang)
		p.vy = math.sin(ang)
		p.rotation = ang
	end,

	update = function(p, dt)
		local b = p._beam
		local t = p.sourceTower
		local e = p.target

		if not t then return end

		local scale = p._growthScale or 1
		local width = b.width * scale

		-- lock beam to muzzle tip
		p.x, p.y = getTowerMuzzle(t)

		-- aim at target if exists
		if e and e.hp > 0 then
			local dx = e.x - p.x
			local dy = e.y - p.y

			local len = math.sqrt(dx*dx + dy*dy)
			if len > 0 then
				p.vx = dx / len
				p.vy = dy / len
				p.rotation = math.atan2(dy, dx)
				b.length = len
			end
		end

		-- cooldown timer
		b.timer = b.timer - dt

		local hitCooldown = b.hitCooldown
		for k, v in next, hitCooldown do
			v = v - dt
			if v <= 0 then
				hitCooldown[k] = nil
			else
				hitCooldown[k] = v
			end
		end

		local vx, vy = p.vx, p.vy

		local x1, y1 = p.x, p.y
		local segments = 10

		local step = b.length / segments
		for s = 0, segments do
			local dist = s * step

			local sx = x1 + vx * dist
			local sy = y1 + vy * dist

			if b.timer <= 0 then
				local nearby, nearbyCount = Spatial.queryCells(sx, sy, width)

				for i = 1, nearbyCount do
					local e2 = nearby[i]

					if e2.hp > 0 then
						local dx = e2.x - sx
						local dy = e2.y - sy
						local dist2 = dx*dx + dy*dy
						local rr = width + (e2.radius or 0)

						if dist2 <= rr*rr then
							local id = e2.id or e2

							if not hitCooldown[id] then
								local evt = emitEvent(p, "hit")
								evt.target = e2
								evt.origin = "beam"
								evt.hitX = sx
								evt.hitY = sy

								hitCooldown[id] = b.rate
							end
						end
					end
				end
			end
		end

		if b.timer <= 0 then
			b.timer = b.rate
		end
	end,

	draw = function(p, a)
		local beam = p._beam
		if not beam then return end

		local scale = p._growthScale or 1
		local width = beam.width * scale
		local len = beam.length or 0
		if len <= 0 then return end

		local tower = p.sourceTower
		local c = tower and tower.color or {1, 1, 1}
		local r, g, bcol = c[1], c[2], c[3]

		local glowR, glowG, glowB = r * 0.5, g * 0.5, bcol * 0.5
		local coreR = min(1, r * 1.35)
		local coreG = min(1, g * 1.35)
		local coreB = min(1, bcol * 1.35)

		local glowH = width * 2.6
		local bodyH = width * 1.3
		local coreH = width * 0.62

		local function drawBeamBody(h, cr, cg, cb, alpha)
			local y = -h * 0.5
			local radius = h * 0.5
			lg.setColor(cr, cg, cb, alpha)
			lg.rectangle("fill", 0, y, len, h, radius, radius, 12)
		end

		-- soft outer glow
		drawBeamBody(glowH, glowR, glowG, glowB, a * 0.20)
		-- main body
		drawBeamBody(bodyH, r, g, bcol, a * 0.92)
		-- bright center core
		drawBeamBody(coreH, coreR, coreG, coreB, a * 0.95)

		-- muzzle and tip bloom to keep it feeling energetic
		lg.setColor(r, g, bcol, a * 0.35)
		lg.circle("fill", 0, 0, bodyH * 0.52)
		lg.circle("fill", len, 0, bodyH * 0.45)

		lg.setColor(coreR, coreG, coreB, a * 0.55)
		lg.circle("fill", 0, 0, coreH * 0.7)
		lg.circle("fill", len, 0, coreH * 0.62)
	end
}

-- =========================
-- STATUS
-- =========================

for id, handlers in pairs(B) do register({ id = id, role = "emission", handlers = handlers }) end
end
