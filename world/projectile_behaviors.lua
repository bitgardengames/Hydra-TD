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
local floor = math.floor
local random = math.random

local ProjectileBehaviors = {}

local B = {}

local lg = love.graphics

local function clearMap(t)
	if not t then
		return
	end

	for k in pairs(t) do
		t[k] = nil
	end
end

local function clearArray(t)
	if not t then
		return
	end

	for i = #t, 1, -1 do
		t[i] = nil
	end
end

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

	local events = p.events
	if not events then
		events = {}
		p.events = events
		p.eventRead = 1
		p.eventCount = 0
	end

	local count = (p.eventCount or 0) + 1
	events[count] = evt
	p.eventCount = count
end

ProjectileBehaviors.pushEvent = pushEvent

local function takeEvent(p, id)
	local eventPool = p and p._eventPool
	local eventPoolCount = p and (p._eventPoolCount or 0) or 0
	local evt

	if eventPool and eventPoolCount > 0 then
		evt = eventPool[eventPoolCount]
		eventPool[eventPoolCount] = nil
		p._eventPoolCount = eventPoolCount - 1
	else
		evt = {}
	end

	evt.id = id
	return evt
end

ProjectileBehaviors.takeEvent = takeEvent

local function emitEvent(p, id)
	local evt = takeEvent(p, id)
	pushEvent(p, evt)
	return evt
end

local function emitFX(p, kind)
	local evt = emitEvent(p, "fx")
	evt.kind = kind
	return evt
end

local function emitSpawnProjectile(p)
	return emitEvent(p, "spawn_projectile")
end

local SHARED_BEHAVIORS_LANCER_RICOCHET = {
	{ id = "move_homing" },
	{ id = "hit_circle", data = { radius = 10 } },
	{ id = "hit_damage" },
	{ id = "lancer_hit_fx" },
	{ id = "draw_lancer" },
}

local SHARED_BEHAVIORS_FROST_SHATTER = {
	{ id = "move_linear" },
	{ id = "hit_damage" },
	{ id = "apply_slow", data = { factor = 0.35, dur = 0.8 } },
	{ id = "draw_frost_shard" },
}

local function getStat(p, key, fallback)
	local t = p.sourceTower
	if t and t[key] ~= nil then return t[key] end
	if p[key] ~= nil then return p[key] end
	return fallback
end

local function emitDamage(p, e, dmg)
	local evt = emitEvent(p, "damage")
	evt.target = e
	evt.amount = dmg
end

local function beginChainDamageBudget(p)
	p._chainBudgetUsed = 0
end

local function consumeChainDamageBudget(p, rawDmg)
	if rawDmg <= 0 then
		return 0
	end

	local base = p._baseDamage or p.damage or rawDmg
	local cap = base * 4.5
	local used = p._chainBudgetUsed or 0
	local remaining = max(0, cap - used)
	if remaining <= 0 then
		return 0
	end

	-- Soft-cap after first few secondary hits, then hard-cap at total budget.
	local secondaryCount = p._chainSecondaryHitCount or 0
	local diminished = rawDmg
	if secondaryCount >= 6 then
		diminished = diminished * 0.85
	end
	if secondaryCount >= 10 then
		diminished = diminished * 0.7
	end

	local allowed = min(diminished, remaining)
	if allowed > 0 then
		p._chainBudgetUsed = used + allowed
		p._chainSecondaryHitCount = secondaryCount + 1
	end

	return allowed
end

local function emitImpulse(p, e, px, py, strength)
	local evt = emitEvent(p, "impulse")
	evt.target = e
	evt.dx = e.x - px
	evt.dy = e.y - py
	evt.strength = strength
end

local function canHitTarget(p, enemy)
	for i = 1, #p.behaviors do
		local b = p.behaviors[i]
		local def = B[b.id]
		if def and def.canHit and not def.canHit(p, enemy, b.data) then
			return false
		end
	end

	return true
end

local function projectileHasHit(p, id)
	if p.hasHit then
		return p.hasHit(p, id)
	end

	return p.hitSet[id] == true
end

local HOOK_COMPAT = {
	on_shot = "init",
	on_tick = "update",
	on_hit = "onHit",
	on_kill = "onKill",
	on_expire = "onExpire",
}

local HOOK_IDS = {
	"on_shot",
	"on_tick",
	"on_hit",
	"on_kill",
	"on_expire",
}

local function behaviorSupportsHook(def, behaviorData, primaryHookId, compatHookId)
	if behaviorData and behaviorData.hooks then
		for i = 1, #behaviorData.hooks do
			local hook = behaviorData.hooks[i]
			if hook == primaryHookId or hook == compatHookId then
				return true
			end
		end
		return false
	end

	return def[primaryHookId] ~= nil or (compatHookId and def[compatHookId] ~= nil)
end

function ProjectileBehaviors.compileHooks(p)
	local hooks = {}

	for i = 1, #HOOK_IDS do
		hooks[HOOK_IDS[i]] = {}
	end

	for i = 1, #p.behaviors do
		local b = p.behaviors[i]
		local def = B[b.id]

		if def then
			for j = 1, #HOOK_IDS do
				local hookId = HOOK_IDS[j]
				local compatHookId = HOOK_COMPAT[hookId]

				if behaviorSupportsHook(def, b, hookId, compatHookId) then
					local fn = def[hookId] or def[compatHookId]
					if fn then
						local arr = hooks[hookId]
						arr[#arr + 1] = { fn = fn, data = b.data }
					end
				end
			end
		end
	end

	p._hooks = hooks
end

local function consumeProjectile(p)
	if p and not p._didExpireHook then
		p._didExpireHook = true
		local hooks = p._hooks and p._hooks.on_expire
		if hooks then
			for i = 1, #hooks do
				local hook = hooks[i]
				hook.fn(p, hook.data)
			end
		end
	end
	return "consume"
end

local function canProcTarget(p, procKey, enemy, cooldown)
	if not p or not procKey or not enemy then
		return false
	end
	local id = enemy.id or enemy
	p._procCooldowns = p._procCooldowns or {}
	local map = p._procCooldowns[procKey]
	if not map then
		map = {}
		p._procCooldowns[procKey] = map
	end
	local now = p.t or 0
	local nextAt = map[id] or -1
	if now < nextAt then
		return false
	end
	map[id] = now + (cooldown or 0)
	return true
end

ProjectileBehaviors.canProcTarget = canProcTarget

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
		local evt = emitEvent(p, "hit")
		evt.target = e
		evt.origin = p.hitOrigin or "primary"

		return "consume"
	end
}

B.retarget_on_spawn = {
	init = function(p, data)
		local radius = data.radius or 72
		local r2 = radius * radius

		local best = nil
		local bestDist = r2

		local nearby, nearbyCount = Spatial.queryCells(p.x, p.y, radius)

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
		local alive = e and e.hp and e.hp > 0

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
					local evt = emitEvent(p, "fx")
					evt.kind = "lancer_hit"
					evt.x = p.x
					evt.y = p.y
					evt.color = p.sourceTower and p.sourceTower.color
				elseif p.sourceKind == "poison" then
					local evt = emitEvent(p, "fx")
					evt.kind = "poison_splash"
					evt.x = p.x
					evt.y = p.y
					evt.color = p.sourceTower and p.sourceTower.color
				elseif p.sourceKind == "cannon" then
					local evt = emitEvent(p, "hit")
					evt.target = nil
					evt.origin = p.hitOrigin or "primary"
				elseif p.sourceKind == "slow" then
					local evt = emitEvent(p, "fx")
					evt.kind = "frost_burst"
					evt.x = p.x
					evt.y = p.y
					evt.color = p.sourceTower and p.sourceTower.color
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
		local nearby, nearbyCount = Spatial.queryCells(p.x, p.y, radius)

		for i = 1, nearbyCount do
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

		local evt = emitFX(p, "cannon_impact")
		evt.x = p.x
		evt.y = p.y
		evt.r = radius -- ALSO scaled for visuals
		evt.color = p.sourceTower and p.sourceTower.color
	end
}

B.cannon_shockwave = {
	onHit = function(p, _, data)
		local radius = data.radius or 54
		local impulse = data.impulse or 4.8
		local damageMult = data.damageMult or 0.6
		local minFalloff = data.minFalloff or 0.35
		local r2 = radius * radius

		local nearby, nearbyCount = Spatial.queryCells(p.x, p.y, radius)

		for i = 1, nearbyCount do
			local other = nearby[i]
			if other.hp > 0 then
				local dx = other.x - p.x
				local dy = other.y - p.y
				local d2 = dx * dx + dy * dy
				if d2 <= r2 then
					local t = 1 - (d2 / r2)
					local dmg = (p.damage or 0) * damageMult * (minFalloff + (1 - minFalloff) * t)
					emitDamage(p, other, dmg)
					emitImpulse(p, other, p.x, p.y, impulse)
				end
			end
		end
	end
}

B.cannon_damage_scale = {
	init = function(p, data)
		p.damage = (p.damage or 0) * (data.mult or 1)
	end
}


B.cannon_long_fuse = {
	onHit = function(p, _, data)
		if p.hitOrigin == "long_fuse_payload" then
			return
		end

		data = data or {}
		local delay = data.delay or 0.45
		local radius = data.radius or 86
		local falloff = data.falloff or 0.52
		local damageMult = data.damageMult or 1.55
		local ringRadius = data.ringRadius or 54
		local ringWidth = data.ringWidth or 22
		local ringDamageMult = data.ringDamageMult or 1.15
		local repeatHitMult = data.repeatHitMult or 0.6

		local evt = emitSpawnProjectile(p)
		evt.x = p.x
		evt.y = p.y
		evt.damage = p.damage
		evt.source = p.sourceTower
		evt.hitOrigin = "long_fuse_payload"
		evt.longFuseHitSet = p.hitSet
		evt.behaviors = {
			{ id = "stationary" },
			{ id = "cannon_delayed_blast", data = {
				delay = delay,
				radius = radius,
				falloff = falloff,
				damageMult = damageMult,
				ringRadius = ringRadius,
				ringWidth = ringWidth,
				ringDamageMult = ringDamageMult,
				repeatHitMult = repeatHitMult,
			}},
		}
	end
}

B.cannon_delayed_blast = {
	init = function(p, data)
		p._delayedBlast = {
			timer = max(0.01, data.delay or 0.45),
			radius = data.radius or 86,
			falloff = data.falloff or 0.52,
			damageMult = data.damageMult or 1.55,
			ringRadius = data.ringRadius or 54,
			ringWidth = data.ringWidth or 22,
			ringDamageMult = data.ringDamageMult or 1.15,
			repeatHitMult = data.repeatHitMult or 0.6,
			fired = false,
		}
	end,

	update = function(p, dt)
		local b = p._delayedBlast
		if not b or b.fired then
			return
		end

		b.timer = b.timer - dt
		if b.timer > 0 then
			return
		end
		b.fired = true

		local radius = b.radius
		local r2 = radius * radius
		local ringRadius = b.ringRadius
		local ringHalfWidth = b.ringWidth * 0.5
		local ringInner = max(0, ringRadius - ringHalfWidth)
		local ringOuter = ringRadius + ringHalfWidth
		local ringInner2 = ringInner * ringInner
		local ringOuter2 = ringOuter * ringOuter

		local nearby, nearbyCount = Spatial.queryCells(p.x, p.y, radius)

		for i = 1, nearbyCount do
			local other = nearby[i]
			if other.hp > 0 then
				local dx = other.x - p.x
				local dy = other.y - p.y
				local d2 = dx * dx + dy * dy
				if d2 <= r2 then
					local t = 1 - (d2 / r2)
					local coreDmg = (p.damage or 0) * b.damageMult * (b.falloff + (1 - b.falloff) * t)
					local ringBonus = 0
					if d2 >= ringInner2 and d2 <= ringOuter2 then
						ringBonus = (p.damage or 0) * b.ringDamageMult
					end

					local totalDmg = coreDmg + ringBonus
					local priorHits = p.longFuseHitSet
					if priorHits and priorHits[other.id] then
						totalDmg = totalDmg * b.repeatHitMult
					end

					emitDamage(p, other, totalDmg)
					emitImpulse(p, other, p.x, p.y, 4.2)
				end
			end
		end

		local evt = emitFX(p, "cannon_impact")
		evt.x = p.x
		evt.y = p.y
		evt.r = radius
		evt.color = p.sourceTower and p.sourceTower.color
		evt.hitOrigin = "long_fuse_payload"

		p.dead = true
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

B.hit_circle = {
	type = "damage",

	update = function(p, dt, data)
		local radius = data.radius
		if radius == nil then
			radius = p.hitRadius or p.r or 10
		end

		local nearby, nearbyCount = Spatial.queryCells(p.x, p.y, radius)

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

B.hit_chain = {
	type = "damage",

	onHit = function(p, e, data)
		beginChainDamageBudget(p)
		p._chainSecondaryHitCount = 0

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
		local chain = p._chain
		if chain then
			clearArray(chain)
		else
			chain = {}
			p._chain = chain
		end

		local visited = p._chainVisited
		if visited then
			clearMap(visited)
		else
			visited = {}
			p._chainVisited = visited
		end
		local current = e
		local dmg = currentDamage

		for i = 1, jumps + 1 do
			if not current or current.hp <= 0 then break end

			-- deal damage
			local dealt = dmg
			if i > 1 then
				dealt = consumeChainDamageBudget(p, dmg)
			end
			if dealt > 0 then
				emitDamage(p, current, dealt)
			end
			emitImpulse(p, current, p.x, p.y, 1.25)

			local prev = chain[#chain]

			local nextIndex = #chain + 1
			local link = chain[nextIndex] or {}
			link.from = prev and prev.to or nil
			link.to = current
			chain[nextIndex] = link

			visited[current] = true

			-- =========================================
			-- FIND NEXT TARGET
			-- =========================================
			local nextTarget = nil
			local bestDist = radius * radius

			local nearby, nearbyCount = Spatial.queryCells(current.x, current.y, radius)

			for j = 1, nearbyCount do
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

		-- store for FX (array reused across hits to reduce churn)
		p._chain = chain
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

B.chain_static_surge = {
	type = "damage",

	onHit = function(p, e, data)
		if not p._chain then return end
		data = data or {}

		local bonusPerStack = data.bonusPerStack or 0.2
		local maxStacks = data.maxStacks or 6
		local stackMap = p.sourceTower and p.sourceTower._shockSurgeStacks

		if not stackMap and p.sourceTower then
			stackMap = {}
			p.sourceTower._shockSurgeStacks = stackMap
		end

		if not stackMap then
			return
		end

		for i = 1, #p._chain do
			local target = p._chain[i].to
			if target and target.hp > 0 then
				local key = target.id or target
				local stacks = min((stackMap[key] or 0) + 1, maxStacks)
				stackMap[key] = stacks

				local extraMult = (stacks - 1) * bonusPerStack
				if extraMult > 0 then
					local surgeDmg = consumeChainDamageBudget(p, (p.damage or 0) * extraMult)
					if surgeDmg > 0 then
						emitDamage(p, target, surgeDmg)
					end
				end
			end
		end
	end
}

B.chain_endpoint_burst = {
	type = "damage",

	onHit = function(p, e, data)
		if not p._chain then return end
		data = data or {}

		local radius = data.radius or 32
		local radius2 = radius * radius
		local dmgMult = data.dmgMult or 0.5
		local endpoints = p._endpointScratch
		if endpoints then
			clearMap(endpoints)
		else
			endpoints = {}
			p._endpointScratch = endpoints
		end

		local hasOutgoing = p._hasOutgoingScratch
		if hasOutgoing then
			clearMap(hasOutgoing)
		else
			hasOutgoing = {}
			p._hasOutgoingScratch = hasOutgoing
		end

		for i = 1, #p._chain do
			local link = p._chain[i]
			if link.from then
				hasOutgoing[link.from] = true
			end
		end

		for i = 1, #p._chain do
			local target = p._chain[i].to
			if target and target.hp > 0 and not hasOutgoing[target] and not endpoints[target] then
				endpoints[target] = true

				local nearby, nearbyCount = Spatial.queryCells(target.x, target.y, radius)

				for j = 1, nearbyCount do
					local other = nearby[j]
					if other.hp > 0 then
						local dx = other.x - target.x
						local dy = other.y - target.y
						if dx * dx + dy * dy <= radius2 then
							emitDamage(p, other, (p.damage or 0) * dmgMult)
						end
					end
				end
			end
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

		if not projectileHasHit(p, id) and canHitTarget(p, e) then
			p.hit = e
		end

		return "consume"
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

B.lancer_overdrive = {
	onHit = function(p, e, data)
		if not e or e.hp <= 0 then
			return
		end

		local tower = p.sourceTower
		if not tower then
			return
		end

		data = data or {}
		local triggerEvery = max(1, floor(data.triggerEvery or 4))
		local bonusDmgMult = data.bonusDmgMult or 1.4
		tower._lancerOverdriveHits = (tower._lancerOverdriveHits or 0) + 1

		if (tower._lancerOverdriveHits % triggerEvery) ~= 0 then
			return
		end

		emitDamage(p, e, (p.damage or 0) * bonusDmgMult)

		local evt = emitFX(p, "lancer_hit")
		evt.x = e.x
		evt.y = e.y
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


B.lancer_focus_fire = {
	onHit = function(p, e, data)
		if not e or e.hp <= 0 then
			return
		end

		local tower = p.sourceTower
		if not tower then
			return
		end

		data = data or {}
		local window = data.window or 1.1
		local perStackMult = data.perStackMult or 0.18
		local maxStacks = max(1, floor(data.maxStacks or 4))

		local now = p.t or 0
		local key = e.id or e
		local stacks = tower._lancerFocusStacks
		if not stacks then
			stacks = {}
			tower._lancerFocusStacks = stacks
		end

		local state = stacks[key]
		if not state or now > state.expiresAt then
			state = {count = 1, expiresAt = now + window}
		else
			state.count = min(state.count + 1, maxStacks)
			state.expiresAt = now + window
		end
		stacks[key] = state

		if state.count <= 1 then
			return
		end

		local bonusMult = (state.count - 1) * perStackMult
		if bonusMult > 0 then
			emitDamage(p, e, (p.damage or 0) * bonusMult)
		end
	end
}

B.lancer_rail_momentum = {
	onHit = function(p, e, data)
		if not e or e.hp <= 0 then
			return
		end

		data = data or {}
		local perHitMult = data.perHitMult or 0.2
		local maxStacks = max(1, floor(data.maxStacks or 4))
		local stacks = min((p._railMomentumStacks or 0) + 1, maxStacks)
		p._railMomentumStacks = stacks

		if stacks <= 1 then
			return
		end

		local bonusMult = (stacks - 1) * perHitMult
		if bonusMult > 0 then
			emitDamage(p, e, (p.damage or 0) * bonusMult)
		end
	end
}
B.lancer_opening_strike = {
	onHit = function(p, e, data)
		if not e or e.hp <= 0 then
			return
		end

		data = data or {}
		local hpFrac = (e.hp or 0) / max(1, e.maxHp or 1)
		if hpFrac < (data.triggerHpFrac or 0.8) then
			return
		end

		emitDamage(p, e, (p.damage or 0) * (data.bonusDmgMult or 0.65))
	end
}

B.draw_rail_lance = {
	draw = function(p, a)
		local w = p.r * 3.0
		local h = p.r * 0.9

		lg.setColor(1,1,1,a)
		lg.rectangle("fill", -w/2, -h/2, w, h, h, h)
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

		local nearby, nearbyCount = Spatial.queryCells(p.x, p.y, radius)

		local best = nil
		local bestDist = r2

		for i = 1, nearbyCount do
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

			local evt = emitFX(p, "zap")
			evt.x = p.x
			evt.y = p.y
			evt.chain = {
				{ from = nil, to = best }
			}
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
		local evt = emitFX(p, "cannon_impact")
		evt.x = p.x
		evt.y = p.y
		evt.r = data.radius or 48
	end
}

-- Jacobs Ladder?
B.link_projectiles = {
	update = function(p, dt, data)
		local others = data.list or {}

		for i = 1, #others do
			local o = others[i]

			local evt = emitFX(p, "zap")
			evt.x = p.x
			evt.y = p.y
			evt.chain = {
				{ from = nil, to = o }
			}
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
			local nearby, nearbyCount = Spatial.queryCells(e.x, e.y, radius)

			for i = 1, nearbyCount do
				local other = nearby[i]

				local dx = other.x - e.x
				local dy = other.y - e.y

				if dx * dx + dy * dy <= radius * radius then
					emitDamage(p, other, (p.damage or 0) * 0.5)
				end
			end

			local evt = emitFX(p, "frost_burst")
			evt.x = e.x
			evt.y = e.y
			evt.color = p.sourceTower and p.sourceTower.color
		end
	end
}

B.shatter_bonus = {
	onHit = function(p, e, data)
		if not e or e.hp <= 0 then
			return
		end

		if e.slowTimer and e.slowTimer > 0 then
			local mult = data.mult or 0.5
			emitDamage(p, e, (p.damage or 0) * mult)
		end
	end
}

B.snowball_ramp = {
	onHit = function(p, e, data)
		if not e or e.hp <= 0 then
			return
		end

		local hitSet = p._snowballHits
		if not hitSet then
			hitSet = {}
			p._snowballHits = hitSet
		end

		if hitSet[e.id] then
			return
		end

		hitSet[e.id] = true

		local ramp = data.ramp or 0.18
		local cap = data.cap or 2.8
		local base = p._snowballBaseDamage or p.damage or 0
		local stacks = (p._snowballStacks or 0) + 1
		local mult = min(1 + stacks * ramp, cap)

		p._snowballBaseDamage = base
		p._snowballStacks = stacks
		p.damage = base * mult
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

B.infect_spread = {
	onHit = function(p, e, data)
		local spread = e._infectSpread
		if not spread then
			spread = {}
			e._infectSpread = spread
		end

		spread.radius = data.radius or 48
		spread.stackMult = data.stackMult or 1
		spread.loop = data.loop == true
		spread.source = p.sourceTower
	end
}

B.poison_neurotoxin = {
	onHit = function(_, e, data)
		if not e or e.hp <= 0 then
			return
		end

		local baseBonusStacks = max(0, floor(data.bonusStacks or 0))
		if baseBonusStacks <= 0 then
			return
		end

		e.poisonStacks = e.poisonStacks or 0
		e.poisonMaxStacks = e.poisonMaxStacks or e.poisonStacks

		local branchCap = e.poisonMaxStacks
		if data.branchMaxStacks then
			branchCap = min(branchCap, max(0, floor(data.branchMaxStacks)))
		end

		if branchCap <= e.poisonStacks then
			return
		end

		local bonusStacks = baseBonusStacks
		local diminishAt = max(0, floor(data.diminishAt or branchCap))
		if e.poisonStacks >= diminishAt then
			bonusStacks = max(1, floor(baseBonusStacks * (data.highStackBonusMult or 0.5)))
		end

		e.poisonStacks = min(e.poisonStacks + bonusStacks, branchCap)
	end
}


B.poison_cull_weak = {
	onHit = function(p, e, data)
		if not e or e.hp <= 0 then
			return
		end

		local stacks = e.poisonStacks or 0
		if stacks <= 0 then
			return
		end

		local cap = max(1, floor(data.maxBonusStacks or 10))
		local usedStacks = min(stacks, cap)
		local bonusPerStack = data.bonusPerStack or 0.08
		local dmgMult = usedStacks * bonusPerStack
		if dmgMult <= 0 then
			return
		end

		emitDamage(p, e, (p.damage or 0) * dmgMult)
	end
}

B.poison_corrupt_strong = {
	onHit = function(p, e, data)
		if not e or e.hp <= 0 then
			return
		end

		local nearby, nearbyCount = Spatial.queryCells(e.x, e.y, data.radius or 64)
		local maxTargets = 2
		local hits = 0
		local spreadStacks = max(1, floor(data.spreadStacks or 2))
		local spreadDur = data.spreadDur or 1.4

		for i = 1, nearbyCount do
			if hits >= maxTargets then
				break
			end

			local other = nearby[i]
			if other ~= e and other.hp > 0 then
				other.poisonStacks = min((other.poisonStacks or 0) + spreadStacks, other.poisonMaxStacks or math.huge)
				other.poisonDPS = max(other.poisonDPS or 0, e.poisonDPS or 0)
				other.poisonTimer = max(other.poisonTimer or 0, spreadDur)
				other.poisonDuration = max(other.poisonDuration or 0, spreadDur)
				other.poisonSource = p.sourceTower
				hits = hits + 1
			end
		end
	end
}
B.poison_hemotoxin = {
	onHit = function(_, e, data)
		if not e or e.hp <= 0 then
			return
		end

		e.poisonMissingHpMult = max(e.poisonMissingHpMult or 0, data.missingHpMult or 0.8)
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

B.plasma_supernova_burst = {
	init = function(p)
		p._supernovaBurstDone = false
	end,

	update = function(p, _, data)
		if p._supernovaBurstDone then
			return
		end

		local triggerAt = data.triggerAt or 0.2
		if p.life > triggerAt then
			return
		end

		p._supernovaBurstDone = true

		local radius = data.radius or 36
		local dmg = (p.damage or 0) * (data.dmgMult or 2.0)

		local nearby, nearbyCount = Spatial.queryCells(p.x, p.y, radius)

		for i = 1, nearbyCount do
			local e = nearby[i]
			if e.hp > 0 then
				local dx = e.x - p.x
				local dy = e.y - p.y
				local r = radius + (e.radius or 0)

				if dx * dx + dy * dy <= r * r then
					emitDamage(p, e, dmg)
				end
			end
		end

		local evt = emitFX(p, "plasma_hit")
		evt.x = p.x
		evt.y = p.y
		evt.color = p.sourceTower and p.sourceTower.color

		return "consume"
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
				local nearby, nearbyCount = Spatial.queryCells(sx, sy)

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

B.apply_slow = {
	onHit = function(p, e, data)
		if e and e.hp > 0 then
			local factor = min(data.factor, 0.9)
			local newFactor = 1 - factor

			if not e.slowFactor or newFactor < e.slowFactor then
				e.slowFactor = newFactor
			end

			e.slowTimer = max(e.slowTimer or 0, data.dur)
			e.slowDuration = max(e.slowDuration or 0, data.dur)
		end

		local evt = emitFX(p, "frost_burst")
		evt.x = p.x
		evt.y = p.y
		evt.color = p.sourceTower and p.sourceTower.color
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
			e.poisonDuration = max(e.poisonDuration or 0, data.dur)
			e.poisonSource = p.sourceTower
		end

		local evt = emitFX(p, "poison_splash")
		evt.x = p.x
		evt.y = p.y
		evt.color = p.sourceTower and p.sourceTower.color
	end
}

-- Temp, not sure if this type of effect should be handled like this or not
B.lancer_hit_fx = {
	onHit = function(p)
		local evt = emitFX(p, "lancer_hit")
		evt.x = p.x
		evt.y = p.y
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

		local evt = emitFX(p, "zap")
		evt.x = originX
		evt.y = originY
		evt.chain = p._chain
	end
}

-- =========================
-- CONTINUOUS DAMAGE
-- =========================

B.tick_damage = {
	init = function(p, data)
		p.allowRepeatHits = true
		p._tickStates = p._tickStates or {}
		local key = data or "__default_tick"
		p._tickStates[key] = {
			timer = 0,
			rate = data.rate or 0.5,
			radius = data.radius or p.hitRadius or 12
		}
	end,

	update = function(p, dt, data)
		local states = p._tickStates
		if not states then
			return
		end

		local key = data or "__default_tick"
		local t = states[key]
		if not t then
			t = {
				timer = 0,
				rate = (data and data.rate) or 0.5,
				radius = (data and data.radius) or p.hitRadius or 12
			}
			states[key] = t
		end

		t.timer = t.timer - dt
		if t.timer > 0 then
			return
		end

		local radius = data.radius or t.radius or p.hitRadius or 12
		local nearby, nearbyCount = Spatial.queryCells(p.x, p.y, radius)

		for i = 1, nearbyCount do
			local e = nearby[i]

			if e.hp > 0 then
				local dx = e.x - p.x
				local dy = e.y - p.y
				local rr = radius + (e.radius or 0)

				if dx*dx + dy*dy <= rr*rr then
					emitDamage(p, e, p.damage or 0)
					if data and data.impulse and data.impulse > 0 then
						emitImpulse(p, e, p.x, p.y, data.impulse)
					end

					local id = e.id or e

					-- only fire "hit" occasionally
					local cooldownActive = p.getHitCooldownExpiry and p.getHitCooldownExpiry(p, id)

					if not cooldownActive then
						local hitEvt = emitEvent(p, "hit")
						hitEvt.target = e
						hitEvt.origin = p.hitOrigin or "primary"

						if p.setHitCooldownExpiry then
							p.setHitCooldownExpiry(p, id, data.hitRate or 0.35) -- tweak this
						else
							p.hitCooldowns[id] = data.hitRate or 0.35 -- tweak this
						end
					end

					local fxEvt = emitFX(p, "plasma_hit")
					fxEvt.x = p.x
					fxEvt.y = p.y
					fxEvt.vx = p.vx or 0
					fxEvt.vy = p.vy or 0
					fxEvt.color = p.sourceTower and p.sourceTower.color
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

	-- CRITICAL SAFETY: ensure child can actually collide and apply damage.
	local hasHitDetector = false
	local hasHitDamage = false

	for i = 1, #out do
		local id = out[i].id

		if id == "hit_circle" or id == "instant_hit" or id == "emit_on_target" then
			hasHitDetector = true
		end

		if id == "hit_damage" or id == "aoe_damage" or id == "hit_chain" then
			hasHitDamage = true
		end
	end

	if not hasHitDetector then
		out[#out + 1] = { id = "hit_circle", data = { radius = 10 } }
	end

	if not hasHitDamage then
		out[#out + 1] = { id = "hit_damage" }
	end

	return out
end

function ProjectileBehaviors.init(p)
	local hooks = p._hooks and p._hooks.on_shot
	if hooks then
		for i = 1, #hooks do
			local hook = hooks[i]
			hook.fn(p, hook.data)
		end
	end
end

function ProjectileBehaviors.update(p, dt)
	local hooks = p._hooks and p._hooks.on_tick
	if hooks then
		for i = 1, #hooks do
			local hook = hooks[i]
			local result = hook.fn(p, dt, hook.data)
			if result == "consume" then
				return consumeProjectile(p)
			end
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

	local shouldConsume = false

	local hitHooks = p._hooks and p._hooks.on_hit
	if hitHooks then
		for i = 1, #hitHooks do
			local hook = hitHooks[i]
			local result = hook.fn(p, e, hook.data, ctx)
			if result == "consume" then
				shouldConsume = true
			end
		end
	end

	if e and e.hp and e.hp <= 0 then
		local killHooks = p._hooks and p._hooks.on_kill
		if killHooks then
			for i = 1, #killHooks do
				local hook = killHooks[i]
				hook.fn(p, e, hook.data, ctx)
			end
		end
	end

	p.x, p.y = oldX, oldY

	if shouldConsume then
		return consumeProjectile(p)
	end
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
