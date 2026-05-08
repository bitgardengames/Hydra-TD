local State = require("core.state")
local Enemies = require("world.enemies")
local Modules = require("systems.modules")
local Effects = require("world.effects")
local Sound = require("systems.sound")
local PB = require("world.projectile_behaviors")

local projectiles = {}
local pool = {}

local lg = love.graphics
local min = math.min
local cos = math.cos
local sin = math.sin

local pushEvent = PB.pushEvent
local takeEvent = PB.takeEvent

local function clearTable(t)
	for k in pairs(t) do
		t[k] = nil
	end
end

local function releaseEvent(p, evt)
	if not evt then
		return
	end

	clearTable(evt)

	local eventPool = p and p._eventPool
	if eventPool then
		local count = (p._eventPoolCount or 0) + 1
		eventPool[count] = evt
		p._eventPoolCount = count
	end
end

local function nextHitSetStamp(p)
	local stamp = (p.hitSetStamp or 0) + 1

	if stamp >= 2147483647 then
		stamp = 1

		local hitSet = p.hitSet
		if hitSet then
			clearTable(hitSet)
		end
	end

	p.hitSetStamp = stamp
	return stamp
end

local function markProjectileHit(p, id)
	p.hitSet[id] = p.hitSetStamp
end

local function projectileHasHit(p, id)
	return p.hitSet[id] == p.hitSetStamp
end

local function getProjectileNow(p)
	return p.t or 0
end

local function getHitCooldownExpiry(p, id, now)
	local cds = p.hitCooldowns
	if not cds then
		return nil
	end

	local expiry = cds[id]
	if not expiry then
		return nil
	end

	now = now or getProjectileNow(p)
	if now >= expiry then
		cds[id] = nil
		return nil
	end

	return expiry
end

local function setHitCooldownExpiry(p, id, cooldownDur, now)
	local cds = p.hitCooldowns
	if not cds then
		cds = {}
		p.hitCooldowns = cds
	end

	now = now or getProjectileNow(p)
	cds[id] = now + (cooldownDur or 0)
	return cds[id]
end

local function acquire()
	local p = pool[#pool]

	if p then
		pool[#pool] = nil

		return p
	end

	return {}
end

local function release(p)
	local hitSet = p.hitSet
	local hitCooldowns = p.hitCooldowns
	local events = p.events
	local defaultHitCtx = p._defaultHitCtx
	local eventPool = p._eventPool
	local eventPoolCount = p._eventPoolCount or 0

	for k in pairs(p) do
		p[k] = nil
	end

	if hitSet then
		clearTable(hitSet)
		p.hitSet = hitSet
	end

	if hitCooldowns then
		clearTable(hitCooldowns)
		p.hitCooldowns = hitCooldowns
	end

	if events then
		clearTable(events)
		p.events = events
		p.eventRead = 1
		p.eventCount = 0
	end

	if defaultHitCtx then
		clearTable(defaultHitCtx)
		p._defaultHitCtx = defaultHitCtx
	end

	if eventPool then
		p._eventPool = eventPool
		p._eventPoolCount = eventPoolCount
	end

	pool[#pool + 1] = p
end

local function removeAt(i)
	local p = projectiles[i]

	release(p)

	projectiles[i] = projectiles[#projectiles]
	projectiles[#projectiles] = nil
end

local function initProjectile(p, source, opts)
	opts = opts or {}

	p.x = opts.x or source.x
	p.y = opts.y or source.renderY or source.y

	p.r = opts.r or 4.5
	p.baseR = p.r
	p.scale = opts.scale or 1

	p.life = opts.life or 3
	p.t = 0

	p.sourceTower = source
	p.sourceKind = source.kind

	p.speed = opts.speed or source.projSpeed or 0
	p.damage = opts.damage or source.damage or 0

	p.hitOrigin = opts.hitOrigin or "primary"

	p.target = opts.target
	p.ignoreTarget = opts.ignoreTarget

	p.angle = opts.angle or source.angle or 0
	p.rotation = p.angle

	p.vx = opts.vx
	p.vy = opts.vy

	p.hit = nil
	p.eventRead = 1
	p.eventCount = 0
	if p.events then
		clearTable(p.events)
	end
	p._consumed = false
	p.hasHit = projectileHasHit
	p.markHit = markProjectileHit
	p.getHitCooldownExpiry = getHitCooldownExpiry
	p.setHitCooldownExpiry = setHitCooldownExpiry

	local hitSet = p.hitSet
	if not hitSet then
		hitSet = {}
		p.hitSet = hitSet
	end
	nextHitSetStamp(p)

	local hitCooldowns = p.hitCooldowns
	if hitCooldowns then
		clearTable(hitCooldowns)
	else
		hitCooldowns = {}
		p.hitCooldowns = hitCooldowns
	end

	p._defaultHitCtx = p._defaultHitCtx or {}
	p._defaultHitCtx.origin = p.hitOrigin
	p._defaultHitCtx.hitX = nil
	p._defaultHitCtx.hitY = nil

	p.hitRadius = opts.hitRadius or p.r
	p.hitRadius2 = p.hitRadius * p.hitRadius

	if p.target then
		p.lastTX = p.target.x
		p.lastTY = p.target.y
	elseif opts.lastTX and opts.lastTY then
		p.lastTX = opts.lastTX
		p.lastTY = opts.lastTY
	elseif p.vx and p.vy then
		p.lastTX = p.x + p.vx * 10
		p.lastTY = p.y + p.vy * 10
	else
		p.lastTX = p.x + cos(p.angle) * 10
		p.lastTY = p.y + sin(p.angle) * 10
	end

	if opts.behaviors then
		p.behaviors = opts.behaviors
	elseif opts.context then
		p.behaviors = opts.context.behaviors
	else
		local fireProfile = source._fireProfile
		p.behaviors = fireProfile and fireProfile.behaviors or source.def.behaviors
	end

	return p
end

local function spawnEvent(evt)
	local source = evt.source

	if not source then
		return nil
	end

	local p = acquire()

	initProjectile(p, source, evt)

	PB.init(p)

	Sound.play(source.kind)

	projectiles[#projectiles + 1] = p

	return p
end

local function spawnDirect(source, target, context, speed, life)
	if not source then
		return nil
	end

	local p = acquire()

	initProjectile(p, source, {
		target = target,
		context = context,
		speed = speed,
		life = life,
	})

	PB.init(p)

	Sound.play(source.kind)

	projectiles[#projectiles + 1] = p

	return p
end

local function resolveSpawnProjectile(parent, evt)
	local newP = spawnEvent(evt)

	if not newP then
		return
	end

	if evt.angle ~= nil then
		local ang = evt.angle

		newP.angle = ang
		newP.rotation = ang

		newP.vx = cos(ang)
		newP.vy = sin(ang)

		if evt.lastTX and evt.lastTY then
			newP.lastTX = evt.lastTX
			newP.lastTY = evt.lastTY
		else
			newP.lastTX = newP.x + newP.vx * 10
			newP.lastTY = newP.y + newP.vy * 10
		end
	end

	if not evt.behaviors and parent and parent.behaviors then
		newP.behaviors = PB.buildChildBehaviors(parent.behaviors)
		PB.init(newP)
	end
end

local function resolveDamage(p, evt)
	local e = evt.target

	if not e or e.hp <= 0 then
		return
	end

	if p.ignoreTarget and e == p.ignoreTarget then
		return
	end

	local amount = evt.amount or 0

	if amount <= 0 then
		return
	end

	e.hp = e.hp - amount

	local t = p.sourceTower

	if t then
		t.damageDealt = (t.damageDealt or 0) + amount
		e.lastHitTower = t
	end

	if e.hitFlash <= 0 then
		e.hitFlash = 0.05
	end

	State.addDamage(p.sourceKind, amount, e.boss == true)
end

local function resolveImpulse(evt)
	local e = evt.target

	if e and not e.boss then
		Enemies.applyHitImpulse(e, evt.dx, evt.dy, evt.strength)
	end
end

local function resolveFX(evt)
	local kind = evt.kind

	if kind == "zap" then
		Effects.spawnZapEffect(evt.x, evt.y, evt.chain)
	elseif kind == "cannon_impact" then
		Effects.spawnCannonImpact(evt.x, evt.y, evt.r)
	elseif kind == "frost_burst" then
		Effects.spawnFrostBurst(evt.x, evt.y)
	elseif kind == "poison_splash" then
		Effects.spawnPoisonSplash(evt.x, evt.y)
	elseif kind == "lancer_hit" then
		Effects.spawnLancerHit(evt.x, evt.y)
	elseif kind == "plasma_hit" then
		Effects.spawnPlasmaHit(evt.x, evt.y, evt.vx or 0, evt.vy or 0)
	elseif kind == "zap_line" then
		Effects.spawnZapLine(evt.x1, evt.y1, evt.x2, evt.y2)
	else
		-- Fallback for custom effect ids without allocating a transient table.
		evt.id = kind
		Effects.spawnFX(evt)
		evt.id = nil
	end
end

local function resolveHit(p, evt)
	local hitCtx = evt.ctx
	if not hitCtx and (evt.origin or evt.hitX or evt.hitY) then
		hitCtx = evt
	end

	local res = PB.hit(p, evt.target, hitCtx)
	if res == "consume" then
		p._consumed = true
	end
end

local function resolveConsume(p)
	p._consumed = true
end

local eventDispatch = {
	spawn_projectile = resolveSpawnProjectile,
	damage = resolveDamage,
	impulse = function(_, evt)
		resolveImpulse(evt)
	end,
	fx = function(_, evt)
		resolveFX(evt)
	end,
	hit = resolveHit,
	consume = resolveConsume,
}

local function resolveEvents(p)
	local list = p.events
	if not list then
		return
	end

	local read = p.eventRead or 1
	local count = p.eventCount or 0

	while read <= count do
		local evt = list[read]
		list[read] = nil
		read = read + 1

		if evt and evt.id then
			local resolver = eventDispatch[evt.id]
			if resolver then
				resolver(p, evt)
			else
				-- Explicit fallback for dynamic/custom event ids.
				local onEvent = p.onEvent
				if onEvent then
					onEvent(p, evt)
				end
			end
		end

		releaseEvent(p, evt)
		count = p.eventCount or 0
	end

	p.eventRead = 1
	p.eventCount = 0
end

local function processHit(p)
	local hitTarget = p.hit

	if hitTarget and p.ignoreTarget and hitTarget == p.ignoreTarget then
		p.hit = nil
		return
	end

	-- allow nil target for impact-only hits
	if not hitTarget then
		local evt = takeEvent(p, "hit")
		evt.target = nil
		pushEvent(p, evt)
		return
	end

	if hitTarget.hp <= 0 then
		p.hit = nil
		return
	end

	p.hit = nil

	local id = hitTarget.id or hitTarget
	local multiHit = p.allowRepeatHits == true

	if not multiHit and projectileHasHit(p, id) then
		return
	end

	if not multiHit then
		markProjectileHit(p, id)
	end

	local evt = takeEvent(p, "hit")
	evt.target = hitTarget
	evt.origin = p.hitOrigin or "primary"
	pushEvent(p, evt)
end

local function spawn(t, e)
	spawnDirect(t, e)
end

local function update(dt)
	for i = #projectiles, 1, -1 do
		local p = projectiles[i]

		p.life = p.life - dt
		p.t = p.t + dt


		if p.life <= 0 then
			removeAt(i)
			goto continue
		end

		p._consumed = false

		local result = PB.update(p, dt)

		if p.hit then
			processHit(p)
		end

		resolveEvents(p)

		if result == "consume" or p._consumed then
			removeAt(i)
			goto continue
		end

		::continue::
	end
end

local function draw()
	for i = 1, #projectiles do
		local p = projectiles[i]

		local fadeStart = 0.2
		local lifeAlpha = 1

		if p.life < fadeStart then
			lifeAlpha = p.life / fadeStart
		end

		local a = min(1, p.t * 10) * lifeAlpha

		lg.push()
		lg.translate(p.x, p.y)
		lg.rotate(p.rotation or 0)

		PB.draw(p, a)

		lg.pop()
	end
end

local function clear()
	for i = #projectiles, 1, -1 do
		release(projectiles[i])
		projectiles[i] = nil
	end
end

local function load()
	for i = 1, 48 do
		local p = acquire()
		p.x = 0
		p.y = 0
		p.life = 0
		release(p)
	end
end

local function spawnFromContext(t, target, ctx, speed, life)
	return spawnDirect(t, target, ctx, speed, life)
end

return {
	projectiles = projectiles,
	spawn = spawn,
	spawnEvent = spawnEvent,
	spawnFromContext = spawnFromContext,
	update = update,
	draw = draw,
	clear = clear,
	load = load,
}
