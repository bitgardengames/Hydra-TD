local State = require("core.state")
local Effects = require("world.effects")
local Enemies = require("world.enemies")
local Constants = require("core.constants")
local Spatial = require("world.spatial_grid")

--[[
	NOTE; ALL SYSTEMS MUST WORK TOGETHER FLUIDLY. This rule cannot be broken.

	Any tower should be able to emit any effect, behavior, or visual.

	Any mixture of projectile + behavior + visual has to work, period.

	Don't hard code things, that's already a broken contract.
--]]

local pi = math.pi
local min = math.min
local max = math.max
local sin = math.sin
local cos = math.cos
local sqrt = math.sqrt
local atan2 = math.atan2
local random = math.random

local ProjectileBehaviors = {}

local B = {}

local lg = love.graphics

-- helpers

--[[
	more ideas

	just a split shot that goes out in 2 directions

	either a 4x or even crazy 8x shot outwards from the tower

	shockwave type ring that expands out from the tower?

	can we make any projectile pierce? (even cannon shells, poison ticks, lancer shots) they just deal their damage but aren't consumed and move on

	we haven't even touched behaviors that modify tower targeting behavior, so currently all towers still shoot at the furthest enemy along the path

	maybe a behavior just turns the projectiles into an aura around the tower in some manner, but is this any different than orbital?

	a behavior that makes projectiles just larger/more damage
	make projectiles considerably wider

	make projectiles spin around like crazy

	projectiles bounce off the enemy
--]]

local function pushEvent(p, evt)
	if not p or not evt then return end
	if not evt.id then return end

	p.events = p.events or {}
	p.events[#p.events + 1] = evt
end

ProjectileBehaviors.pushEvent = pushEvent

local function getStat(p, key, fallback)
	local t = p.sourceTower
	if t and t[key] ~= nil then return t[key] end
	if p[key] ~= nil then return p[key] end
	return fallback
end

local function emitDamage(p, e, dmg)
	pushEvent(p, {
		id = "damage",
		target = e,
		amount = dmg
	})
end

local function emitImpulse(p, e, px, py, strength)
	pushEvent(p, {
		id = "impulse",
		target = e,
		dx = e.x - px,
		dy = e.y - py,
		strength = strength
	})
end

-- visual stuff
local function getProjectileColor(p, fallback)
	local t = p.sourceTower
	local c = t and t.color

	if c then
		return c[1], c[2], c[3]
	end

	return fallback[1], fallback[2], fallback[3]
end

local function colorMul(r, g, b, mul)
	return min(1, r * mul), min(1, g * mul), min(1, b * mul)
end

local function getTowerMuzzle(t)
	if not t then
		return 0, 0
	end

	local size = Constants.TILE * 0.42
	local kind = t.kind
	local tipX = size * 0.9

	if kind == "cannon" then
		tipX = size * 0.95
	elseif kind == "shock" then
		tipX = size * (0.28 + 0.52)
	elseif kind == "slow" then
		tipX = size * 0.64
	elseif kind == "poison" then
		tipX = size * 0.6
	elseif kind == "plasma" then
		tipX = (Constants.TILE * 0.48) * 0.86
	end

	local localX = tipX - (t.recoil or 0)
	local ca = cos(t.angle or 0)
	local sa = sin(t.angle or 0)

	local x = t.x + localX * ca
	local y = (t.renderY or t.y) + localX * sa

	return x, y
end

-- behaviors

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
		pushEvent(p, {
			id = "hit",
			target = e,
			origin = p.hitOrigin or "primary"
		})

		return "consume"
	end
}

B.retarget_on_spawn = {
	init = function(p, data)
		local radius = data.radius or 72
		local r2 = radius * radius

		local best = nil
		local bestDist = r2

		local nearby = Spatial.queryCells(p.x, p.y)

		for i = 1, #nearby do
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
		local alive = e and e.hp > 0

		if alive then
			tx, ty = e.x, e.y
			p.lastTX, p.lastTY = tx, ty
		else
			tx, ty = p.lastTX, p.lastTY
		end

		if not tx then
			return
		end

		-- direction to target center
		local dx = tx - p.x
		local dy = ty - p.y

		local dist = sqrt(dx*dx + dy*dy)
		if dist < 1e-6 then
			dist = 1e-6
		end

		local inv = 1 / dist
		local nx = dx * inv
		local ny = dy * inv

		-- NEW: aim at enemy SURFACE, not center
		local enemyRadius = (alive and e.radius) or 0
		local targetX = tx - nx * enemyRadius
		local targetY = ty - ny * enemyRadius

		-- recompute toward surface
		dx = targetX - p.x
		dy = targetY - p.y

		dist = sqrt(dx*dx + dy*dy)
		if dist < 1e-6 then
			dist = 1e-6
		end

		local step = (p.speed or 0) * dt

		-- NEW: no radius fudge
		if dist <= step then
			p.x, p.y = targetX, targetY

			if alive then
				p.hit = e
			else
				-- preserve your existing FX fallback behavior
				if p.sourceKind == "lancer" then
					pushEvent(p, {
						id = "fx",
						kind = "lancer_hit",
						x = p.x,
						y = p.y,
						color = p.sourceTower and p.sourceTower.color
					})
				elseif p.sourceKind == "poison" then
					pushEvent(p, {
						id = "fx",
						kind = "poison_splash",
						x = p.x,
						y = p.y,
						color = p.sourceTower and p.sourceTower.color
					})
				elseif p.sourceKind == "cannon" then
					pushEvent(p, {
						id = "hit",
						target = nil,
						origin = p.hitOrigin or "primary"
					})
				elseif p.sourceKind == "slow" then
					pushEvent(p, {
						id = "fx",
						kind = "frost_burst",
						x = p.x,
						y = p.y,
						color = p.sourceTower and p.sourceTower.color
					})
				end
			end

			return "consume"
		end

		-- normal movement
		local inv2 = 1 / dist
		p.x = p.x + dx * inv2 * step
		p.y = p.y + dy * inv2 * step

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

B.hit_damage = {
	onHit = function(p, e)
		if not e or e.hp <= 0 then
			return
		end

		local dmg = getStat(p, "damage", 0)
		emitDamage(p, e, dmg)
		emitImpulse(p, e, p.x, p.y, 1.5)
	end
}

B.aoe_damage = {
	onHit = function(p, e, data)
		local baseRadius = data.radius or 32
		local falloff = data.falloff or 0.5

		local scale = p._growthScale or 1
		local radius = baseRadius * scale

		local r2 = radius * radius
		local nearby = Spatial.queryCells(p.x, p.y)

		for i = 1, #nearby do
			local other = nearby[i]
			local dx = other.x - p.x
			local dy = other.y - p.y
			local d2 = dx*dx + dy*dy

			if d2 <= r2 then
				local t = 1 - (d2 / r2)
				local dmg = p.damage * (falloff + (1 - falloff) * t)

				emitDamage(p, other, dmg)
				emitImpulse(p, other, p.x, p.y, 3.2)
			end
		end

		pushEvent(p, {
			id = "fx",
			kind = "cannon_impact",
			x = p.x,
			y = p.y,
			r = radius, -- ALSO scaled for visuals
			color = p.sourceTower and p.sourceTower.color
		})
	end
}

B.hit_circle = {
	type = "damage",

	update = function(p, dt, data)
		local radius = data.radius
		if radius == nil then
			radius = p.hitRadius or p.r or 10
		end

		local nearby = Spatial.queryCells(p.x, p.y)

		for i = 1, #nearby do
			local e = nearby[i]

			if e.hp > 0 and e ~= p.ignoreTarget then
				local dx = e.x - p.x
				local dy = e.y - p.y

				if dx*dx + dy*dy <= radius*radius then
					local id = e.id or e

					if not p.hitSet[id] then
						p.hit = e
						return "consume"
					end
				end
			end
		end
	end,

	onSpawn = function(p, data)
		p.hitRadius = data.radius
	end
}

B.hit_chain = {
	type = "damage",

	onHit = function(p, e, data)
		local jumps = data.jumps or 3
		local baseRadius = data.radius or 56
		local falloff = data.falloff or 0.75

		-- =========================================
		-- GROWTH / SHARED SCALE
		-- =========================================
		local baseDamage = p._baseDamage or p.damage or 0
		local currentDamage = p.damage or 0

		local scale = 1
		if baseDamage > 0 then
			scale = currentDamage / baseDamage
		end

		-- optional future-proof override
		if p._growthScale then
			scale = p._growthScale
		end

		local radius = baseRadius * scale

		-- =========================================
		-- CHAIN LOGIC
		-- =========================================
		local chain = {}
		local visited = {}
		local current = e
		local dmg = currentDamage

		for i = 1, jumps + 1 do
			if not current or current.hp <= 0 then break end

			-- deal damage
			emitDamage(p, current, dmg)
			emitImpulse(p, current, p.x, p.y, 1.25)

			local prev = chain[#chain]

			chain[#chain + 1] = {
				from = prev and prev.to or nil,
				to = current
			}

			visited[current] = true

			-- =========================================
			-- FIND NEXT TARGET
			-- =========================================
			local nextTarget = nil
			local bestDist = radius * radius

			local nearby = Spatial.queryCells(current.x, current.y)

			for j = 1, #nearby do
				local other = nearby[j]

				if not visited[other] and other.hp > 0 then
					local dx = other.x - current.x
					local dy = other.y - current.y
					local d2 = dx*dx + dy*dy

					if d2 < bestDist then
						bestDist = d2
						nextTarget = other
					end
				end
			end

			current = nextTarget

			-- =========================================
			-- DECAY
			-- =========================================
			dmg = dmg * falloff

			-- optional: decay radius slightly per jump (feels good)
			radius = radius * 0.9

			-- optional: decay scale influence per jump
			scale = scale * 0.95
		end

		-- store for FX
		p._chain = chain
	end
}

B.fork_chain = {
	type = "damage",

	onHit = function(p, e, data)
		if not p._chain then return end

		local forks = {}

		for i = 1, #p._chain do
			local link = p._chain[i]

			if link.to and link.to.hp > 0 then
				local nearby = Spatial.queryCells(link.to.x, link.to.y)

				for j = 1, #nearby do
					local other = nearby[j]

					if other ~= link.to and other.hp > 0 then
						forks[#forks + 1] = {
							from = link.to,
							to = other
						}
						break
					end
				end
			end
		end

		for i = 1, #forks do
			p._chain[#p._chain + 1] = forks[i]
		end
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

		if not p.hitSet[id] then
			p.hit = e
		end

		return "consume"
	end
}

B.split_on_hit = {
	type = "damage",

	onHit = function(p, e, data)
		data = data or {}

		local count = data.count or 2
		local spread = data.spread or 0.35 -- radians (~20° total default)
		local dmgMult = data.dmgMult or 0.6

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
			pushEvent(p, {
				id = "spawn_projectile",
				x = spawnX,
				y = spawnY,
				angle = base,
				damage = (p.damage or 0) * dmgMult,
				source = p.sourceTower,
				parent = p,
				ignoreTarget = e,
			})
			return
		end

		-- Spread evenly across cone
		for i = 1, count do
			local t = (i - 1) / (count - 1) -- 0 → 1
			local offset = (t - 0.5) * spread

			local ang = base + offset

			pushEvent(p, {
				id = "spawn_projectile",
				x = spawnX,
				y = spawnY,
				angle = ang,
				damage = (p.damage or 0) * dmgMult,
				source = p.sourceTower,
				parent = p,
				ignoreTarget = e,
			})
		end

		pushEvent(p, {
			id = "fx",
			kind = "lancer_hit",
			x = p.x,
			y = p.y
		})

		return "consume"
	end
}

B.tick_zap = {
	type = "damage",

	init = function(p, data)
		p._zap = {
			timer = 0,
			rate = data.rate or 0.25,
			radius = data.radius or 64,
		}
	end,

	update = function(p, dt)
		local z = p._zap
		z.timer = z.timer - dt
		if z.timer > 0 then return end

		local radius = z.radius
		local r2 = radius * radius

		local nearby = Spatial.queryCells(p.x, p.y)

		local best = nil
		local bestDist = r2

		for i = 1, #nearby do
			local e = nearby[i]

			if e.hp > 0 then
				local dx = e.x - p.x
				local dy = e.y - p.y
				local d2 = dx*dx + dy*dy

				if d2 <= bestDist then
					bestDist = d2
					best = e
				end
			end
		end

		if best then
			emitDamage(p, best, p.damage or 0)

			pushEvent(p, {
				id = "fx",
				kind = "zap",
				x = p.x,
				y = p.y,
				chain = {
					{ from = nil, to = best }
				}
			})
		end

		z.timer = z.rate
	end
}

B.chaos_bounce = {
	onHit = function(p, e, data)
		local ang = random() * (pi * 2)

		p.vx = cos(ang)
		p.vy = sin(ang)
		p.hit = nil
	end
}

B.explode_on_hit = {
	type = "damage",

	onHit = function(p, e, data)
		pushEvent(p, {
			id = "fx",
			kind = "cannon_impact",
			x = p.x,
			y = p.y,
			r = data.radius or 48
		})
	end
}

-- Jacobs Ladder?
B.link_projectiles = {
	update = function(p, dt, data)
		local others = data.list or {}

		for i = 1, #others do
			local o = others[i]

			pushEvent(p, {
				id = "fx",
				kind = "zap",
				x = p.x,
				y = p.y,
				chain = {
					{ from = nil, to = o }
				}
			})
		end
	end
}

B.slow_pop = {
	onHit = function(p, e)
		if not e or e.hp <= 0 then
			return
		end

		if e.slowTimer and e.slowTimer > 0 then
			local radius = 28
			local nearby = Spatial.queryCells(e.x, e.y)

			for i = 1, #nearby do
				local other = nearby[i]

				local dx = other.x - e.x
				local dy = other.y - e.y

				if dx * dx + dy * dy <= radius * radius then
					emitDamage(p, other, (p.damage or 0) * 0.5)
				end
			end

			pushEvent(p, {
				id = "fx",
				kind = "frost_burst",
				x = e.x,
				y = e.y,
				color = p.sourceTower and p.sourceTower.color
			})
		end
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

			pushEvent(p, {
				id = "spawn_projectile",
				x = e.x,
				y = e.y,
				angle = ang,
				damage = (p.damage or 0) * dmgMult,
				source = p.sourceTower,
				behaviors = {
					{ id = "move_linear" },
					{ id = "hit_damage" },
					{ id = "apply_slow", data = { factor = 0.35, dur = 0.8 } },
					{ id = "draw_frost_shard" }
				}
			})
		end

		pushEvent(p, {
			id = "fx",
			kind = "frost_burst",
			x = e.x,
			y = e.y,
			color = p.sourceTower and p.sourceTower.color
		})
	end
}

B.spawn_static_field = {
	onHit = function(p, e, data)
		pushEvent(p, {
			id = "spawn_projectile",
			x = p.x,
			y = p.y,
			source = p.sourceTower,
			damage = p.damage * (data.dmgMult or 0.4),
			behaviors = {
				{ id = "stationary" },
				{ id = "tick_damage", data = { radius = data.radius or 48, rate = 0.3 } },
				{ id = "draw_static_field" }
			}
		})
	end
}

B.pierce = {
	onHit = function(p, e)
		-- do nothing, let projectile continue
	end
}

B.stationary = {
	update = function() end
}

B.plasma_conductor = {
	update = function(p, dt, data)
		p._conductRadius = data.radius or 42
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

		local count = data.count or 2
		local spawnRadius = (e.radius or 12) + 6

		for i = 1, count do
			local ang = ((i - 1) / count) * pi * 2

			local ox = cos(ang) * spawnRadius
			local oy = sin(ang) * spawnRadius

			pushEvent(p, {
				id = "spawn_projectile",
				hitOrigin = "secondary",
				x = e.x + ox,
				y = e.y + oy,
				angle = ang,
				source = p.sourceTower,
				target = e,
				damage = p.damage * 0.4,
				ignoreTarget = e,
				behaviors = {
					{ id = "move_enemy_orbit", data = { radius = 32 } },
					{ id = "tick_damage", data = { radius = 28, rate = 0.25 } },
					{ id = "draw_shock_orb" }
				}
			})
		end
	end
}

B.infect_spread = {
	onHit = function(p, e, data)
		e._infectSpread = {
			radius = data.radius or 48,
			stackMult = data.stackMult or 1,
			source = p.sourceTower
		}
	end
}

B.poison_burst_on_death = {
	onDeath = function(e)
		local spread = e._infectSpread
		if not spread then return end

		local nearby = Spatial.queryCells(e.x, e.y)
		local radius = spread.radius
		local r2 = radius * radius

		for i = 1, #nearby do
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

B.growing_projectile = {
	init = function(p)
		p.baseR = p.r or 4.5

		-- Cache base values ONCE
		p._baseDamage = p.damage

		-- Shared scale (for all other behaviors)
		p._growthScale = 1
	end,

	update = function(p, dt, data)
		local maxScale = data.scale or 2.0

		local progress = p.t / p.life
		progress = min(progress, 1)

		-- smoothstep easing
		local t = progress * progress * (3 - 2 * progress)

		local scale = 1 + (maxScale - 1) * t

		-- =========================================
		-- SHARED SCALE
		-- =========================================
		p._growthScale = scale

		-- =========================================
		-- SIZE
		-- =========================================
		p.r = p.baseR * scale
		p.hitRadius = p.r
		p.hitRadius2 = p.r * p.r

		-- =========================================
		-- DAMAGE
		-- =========================================
		p.damage = p._baseDamage * scale
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

		for k, v in pairs(b.hitCooldown) do
			v = v - dt
			if v <= 0 then
				b.hitCooldown[k] = nil
			else
				b.hitCooldown[k] = v
			end
		end

		local vx, vy = p.vx, p.vy
		local len = math.sqrt(vx*vx + vy*vy)
		if len == 0 then return end

		vx, vy = vx / len, vy / len

		local x1, y1 = p.x, p.y
		local segments = 10

		for s = 0, segments do
			local tSeg = s / segments

			local sx = x1 + vx * b.length * tSeg
			local sy = y1 + vy * b.length * tSeg

			if b.timer <= 0 then
				local nearby = Spatial.queryCells(sx, sy)

				for i = 1, #nearby do
					local e2 = nearby[i]

					if e2.hp > 0 then
						local dx = e2.x - sx
						local dy = e2.y - sy
						local dist2 = dx*dx + dy*dy
						local rr = width + (e2.radius or 0)

						if dist2 <= rr*rr then
							local id = e2.id or e2

							if not b.hitCooldown[id] then
								pushEvent(p, {
									id = "hit",
									target = e2,
									origin = "beam",
									hitX = sx,
									hitY = sy
								})

								b.hitCooldown[id] = b.rate
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

B.apply_slow = {
	onHit = function(p, e, data)
		if e and e.hp > 0 then
			local factor = min(data.factor, 0.9)
			local newFactor = 1 - factor

			if not e.slowFactor or newFactor < e.slowFactor then
				e.slowFactor = newFactor
			end

			e.slowTimer = max(e.slowTimer or 0, data.dur)
		end

		pushEvent(p, {
			id = "fx",
			kind = "frost_burst",
			x = p.x,
			y = p.y,
			color = p.sourceTower and p.sourceTower.color
		})
	end
}

B.apply_poison = {
	onHit = function(p, e, data)
		if e and e.hp > 0 then
			e.poisonStacks = e.poisonStacks or 0
			e.poisonMaxStacks = max(e.poisonMaxStacks or 0, data.maxStacks)
			e.poisonDPS = max(e.poisonDPS or 0, data.dps)

			e.poisonStacks = min(e.poisonStacks + 1, e.poisonMaxStacks)
			e.poisonTimer = max(e.poisonTimer or 0, data.dur)
			e.poisonSource = p.sourceTower
		end

		pushEvent(p, {
			id = "fx",
			kind = "poison_splash",
			x = p.x,
			y = p.y,
			color = p.sourceTower and p.sourceTower.color
		})
	end
}

-- Temp, not sure if this type of effect should be handled like this or not
B.lancer_hit_fx = {
	onHit = function(p)
		pushEvent(p, {
			id = "fx",
			kind = "lancer_hit",
			x = p.x,
			y = p.y
		})
	end
}

B.chain_zap_fx = {
	onHit = function(p)
		if not p._chain or #p._chain == 0 then
			return
		end

		local t = p.sourceTower

		local size = Constants.TILE * 0.42
		local tipX = size * 0.39

		local ca = cos(t.angle)
		local sa = sin(t.angle)

		local localX = tipX - (t.recoil or 0)

		local originX = t.x + (localX * ca)
		local originY = t.renderY + (localX * sa)

		pushEvent(p, {
			id = "fx",
			kind = "zap",
			x = originX,
			y = originY,
			chain = p._chain,
		})
	end
}

-- =========================
-- CONTINUOUS DAMAGE
-- =========================

B.tick_damage = {
	init = function(p, data)
		p.allowRepeatHits = true
		p._tick = {
			timer = 0,
			rate = data.rate or 0.5,
			radius = data.radius or p.hitRadius or 12
		}
	end,

	update = function(p, dt, data)
		local t = p._tick

		t.timer = t.timer - dt
		if t.timer > 0 then
			return
		end

		local radius = data.radius or t.radius or p.hitRadius or 12
		local nearby = Spatial.queryCells(p.x, p.y)

		for i = 1, #nearby do
			local e = nearby[i]

			if e.hp > 0 then
				local dx = e.x - p.x
				local dy = e.y - p.y
				local rr = radius + (e.radius or 0)

				if dx*dx + dy*dy <= rr*rr then
					emitDamage(p, e, p.damage or 0)

					local id = e.id or e

					-- only fire "hit" occasionally
					if not p.hitCooldowns[id] then
						pushEvent(p, {
							id = "hit",
							target = e,
							origin = p.hitOrigin or "primary"
						})

						p.hitCooldowns[id] = data.hitRate or 0.35 -- tweak this
					end

					pushEvent(p, {
						id = "fx",
						kind = "plasma_hit",
						x = p.x,
						y = p.y,
						vx = p.vx or 0,
						vy = p.vy or 0,
						color = p.sourceTower and p.sourceTower.color
					})
				end
			end
		end

		t.timer = t.rate
	end
}

-- =========================
-- VISUALS (NOW MODULAR)
-- =========================

B.draw_lancer = {
	draw = function(p, a)
		local rx = p.r * (6 / 4.5)
		local ry = p.r * (3 / 4.5)

		local r, g, b = getProjectileColor(p, {0.97, 0.97, 0.97})
		local hr, hg, hb = colorMul(r, g, b, 1.15)

		lg.setColor(r, g, b, a)
		lg.ellipse("fill", 0, 0, rx, ry)

		lg.setColor(hr, hg, hb, a * 0.7)
		lg.ellipse("fill", -rx * 0.15, -ry * 0.15, rx * 0.65, ry * 0.65)
	end
}

B.draw_slow = {
	draw = function(p, a)
		local size = p.r * (8 / 4.5)
		local r = p.r * (2 / 4.5)

		local cr, cg, cb = getProjectileColor(p, {0.7, 0.85, 1.0})
		local hr, hg, hb = colorMul(cr, cg, cb, 1.15)

		lg.setColor(cr, cg, cb, a)
		lg.push()
		lg.rotate(pi / 4)
		lg.rectangle("fill", -size / 2, -size / 2, size, size, r, r)
		lg.pop()

		lg.setColor(hr, hg, hb, a * 0.6)
		lg.push()
		lg.rotate(pi / 4)
		lg.rectangle("fill", -size * 0.3, -size * 0.3, size * 0.6, size * 0.6, r, r)
		lg.pop()
	end
}

B.draw_poison = {
	draw = function(p, a)
		local wx = sin(p.t * 10) * 1.5
		local wy = cos(p.t * 8) * 1.5
		local outer = p.r * ((p.baseR + 1.5) / p.baseR)

		local cr, cg, cb = getProjectileColor(p, {0.55, 0.85, 0.45})
		local hr, hg, hb = colorMul(cr, cg, cb, 1.2)

		lg.push()
		lg.translate(wx, wy)

		lg.setColor(cr, cg, cb, a)
		lg.circle("fill", 0, 0, outer)

		lg.setColor(hr, hg, hb, a * 0.9)
		lg.circle("fill", 0, 0, p.r)

		lg.pop()
	end
}

B.draw_cannon = {
	draw = function(p, a)
		local w = p.r * (14 / 4.5)
		local h = p.r * (8 / 4.5)
		local r = p.r * (4 / 4.5)

		local cr, cg, cb = getProjectileColor(p, {1.0, 0.8, 0.4})
		local hr, hg, hb = colorMul(cr, cg, cb, 1.15)

		lg.setColor(cr, cg, cb, a)
		lg.rectangle("fill", -w / 2, -h / 2, w, h, r, r)

		lg.setColor(hr, hg, hb, a * 0.6)
		lg.rectangle("fill", -w * 0.3, -h * 0.3, w * 0.6, h * 0.6, r, r)
	end
}

B.draw_plasma = {
	draw = function(p, a)
		local pulse = sin(p.t * 6) * 0.5 + 0.5
		local outer = p.r * (8 / 4.5) + pulse * (1.2 / 4.5) * p.r
		local inner = p.r * (4.5 / 4.5) + pulse * (0.6 / 4.5) * p.r

		local cr, cg, cb = getProjectileColor(p, {0.85, 0.55, 1.0})
		local hr, hg, hb = colorMul(cr, cg, cb, 1.2)

		lg.setColor(cr, cg, cb, a)
		lg.circle("fill", 0, 0, outer)

		lg.setColor(hr, hg, hb, a * 0.9)
		lg.circle("fill", 0, 0, inner)
	end
}

B.draw_shock_orb = {
	draw = function(p, a)
		local t = p.t
		local outer = p.r * (10 / 4.5)
		local inner = p.r * (5 / 4.5)

		local cr, cg, cb = getProjectileColor(p, {0.6, 0.9, 1.0})
		local hr, hg, hb = colorMul(cr, cg, cb, 1.2)

		lg.setColor(cr, cg, cb, a * 0.4)
		lg.circle("fill", 0, 0, outer)

		lg.setColor(hr, hg, hb, a)
		lg.circle("fill", 0, 0, inner)

		for i = 1, 3 do
			local ang = t * 6 + i * 2
			local r = p.r * (6 / 4.5) + sin(t * 8 + i) * (2 / 4.5) * p.r

			local x = cos(ang) * r
			local y = sin(ang) * r

			lg.setColor(1, 1, 1, a * 0.7)
			lg.circle("fill", x, y, 1.5)
		end
	end
}

B.draw_static_field = {
	draw = function(p, a)
		local base = p.r * (16/4.5)
		local wobble = sin(p.t * 4) * (2/4.5) * p.r

		lg.setColor(0.5, 0.8, 1.0, a * 0.4)
		lg.circle("line", 0, 0, base + wobble)
	end
}

B.draw_frost_shard = {
	draw = function(p, a)
		local w = p.r * (4 / 4.5)
		local h = p.r * (10 / 4.5)
		lg.setColor(0.75, 0.9, 1.0, a)

		lg.push()
		lg.rotate(p.rotation or 0)

		lg.rectangle("fill", -w / 2, -h / 2, w, h)

		lg.pop()
	end
}

-- =========================
-- ENGINE
-- =========================

function ProjectileBehaviors.build(t)
	local b = {}

	-- base behaviors
	if t.def.behaviors then
		for i = 1, #t.def.behaviors do
			b[#b+1] = t.def.behaviors[i]
		end
	end

	-- modifiers (future system)
	if t.modBehaviors then
		for i = 1, #t.modBehaviors do
			b[#b+1] = t.modBehaviors[i]
		end
	end

	return b
end

function ProjectileBehaviors.buildChildBehaviors(parentBehaviors)
	local out = {}

	for i = 1, #parentBehaviors do
		local b = parentBehaviors[i]

		-- skip behaviors that should not propagate
		if not b.noInherit then
			local copy = {
				id = b.id
			}

			-- deep copy data
			if b.data then
				local d = {}
				for k, v in pairs(b.data) do
					d[k] = v
				end
				copy.data = d
			end

			out[#out + 1] = copy
		end
	end

	-- CRITICAL SAFETY: ensure child can actually hit something
	local hasHit = false

	for i = 1, #out do
		local id = out[i].id

		if id == "hit_damage" or id == "hit_circle" or id == "instant_hit" then
			hasHit = true
			break
		end
	end

	if not hasHit then
		out[#out + 1] = { id = "hit_damage" }
	end

	return out
end

function ProjectileBehaviors.init(p)
	for i = 1, #p.behaviors do
		local b = p.behaviors[i]
		local def = B[b.id]
		if def and def.init then def.init(p, b.data) end
	end
end

function ProjectileBehaviors.update(p, dt)
	for i = 1, #p.behaviors do
		local b = p.behaviors[i]
		local def = B[b.id]

		if def and def.update then
			local result = def.update(p, dt, b.data)
			if result then return result end
		end
	end
end

function ProjectileBehaviors.hit(p, e, ctx)
	if not ctx then
		ctx = p._defaultHitCtx
	end

	if not ctx then
		ctx = { origin = p.hitOrigin or "primary" }
	end

	local oldX, oldY = p.x, p.y

	if ctx.hitX and ctx.hitY then
		p.x, p.y = ctx.hitX, ctx.hitY
	end

	for i = 1, #p.behaviors do
		local b = p.behaviors[i]
		local def = B[b.id]

		if def and def.onHit then
			def.onHit(p, e, b.data, ctx)
		end
	end

	p.x, p.y = oldX, oldY
end

function ProjectileBehaviors.draw(p, a)
	for i = 1, #p.behaviors do
		local b = p.behaviors[i]
		local def = B[b.id]

		if def and def.draw then
			def.draw(p, a)
		end
	end
end

return ProjectileBehaviors
