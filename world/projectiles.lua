local State = require("core.state")
local Enemies = require("world.enemies")
local Effects = require("world.effects")
local Sound = require("systems.sound")
local PB = require("world.projectile_behaviors")
local ProjectileProfiles = require("world.projectile_profiles")
local Util = require("core.util")
local RunStats = require("systems.run_stats")
local Save = require("core.save")
local Floaters = require("ui.floaters")

local projectiles = {}
local pool = {}

local lg = love.graphics
local min = math.min
local cos = math.cos
local sin = math.sin

local pushEvent = PB.pushEvent
local takeEvent = PB.takeEvent

local function releaseEvent(p, evt)
	if not evt then
		return
	end

	Util.clearTable(evt)

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
			Util.clearTable(hitSet)
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

	local retained = {
		hitSet = {},
		hitCooldowns = {},
		events = {},
		defaultHitCtx = {},
		eventPool = {},
		eventPoolCount = 0,
		chain = {},
		chainVisited = {},
	}

	return { _retained = retained }
end

local function resetReusableState(p)
	local retained = p._retained

	-- Unresolved events are still owned by this projectile. Return each one to
	-- its event pool before making the queue available to the next shot.
	for i = p.eventRead or 1, p.eventCount or 0 do
		local evt = retained.events[i]
		retained.events[i] = nil
		releaseEvent(p, evt)
	end

	Util.clearTable(retained.hitCooldowns)
	Util.clearTable(retained.defaultHitCtx)
	retained.eventPoolCount = p._eventPoolCount or retained.eventPoolCount

	-- Projectile fields are shot-owned unless they live in the retained
	-- container. Clearing the table itself keeps newly introduced behavior state
	-- from leaking merely because this cleanup forgot to enumerate it.
	for key in pairs(p) do
		if key ~= "_retained" then
			p[key] = nil
		end
	end
end

local function release(p)
	resetReusableState(p)

	pool[#pool + 1] = p
end

local function removeAt(i)
	local p = projectiles[i]

	release(p)

	projectiles[i] = projectiles[#projectiles]
	projectiles[#projectiles] = nil
end

local function initProjectile(p, source, target)
	local retained = p._retained

	p.hitSet = retained.hitSet
	p.hitCooldowns = retained.hitCooldowns
	p.events = retained.events
	p.eventRead = 1
	p.eventCount = 0
	p._defaultHitCtx = retained.defaultHitCtx
	p._eventPool = retained.eventPool
	p._eventPoolCount = retained.eventPoolCount

	p.x = source.x
	p.y = source.renderY or source.y

	p.r = 4.5
	p.baseR = p.r
	p.scale = 1

	p.life = 3
	p.t = 0

	p.sourceTower = source
	p.sourceKind = source.kind

	p.speed = source.projSpeed or 0
	p.damage = source.damage or 0

	p.hitOrigin = "primary"

	p.target = target
	p.targetID = p.target and p.target.id or nil
	p.angle = source.angle or 0
	p.rotation = p.angle

	p._consumed = false
	p.hasHit = projectileHasHit
	p.markHit = markProjectileHit
	p.getHitCooldownExpiry = getHitCooldownExpiry
	p.setHitCooldownExpiry = setHitCooldownExpiry

	nextHitSetStamp(p)
	p._defaultHitCtx.origin = p.hitOrigin

	p.hitRadius = p.r
	p.hitRadius2 = p.hitRadius * p.hitRadius

	if p.target then
		p.lastTX = p.target.x
		p.lastTY = p.target.y
	else
		p.lastTX = p.x + cos(p.angle) * 10
		p.lastTY = p.y + sin(p.angle) * 10
	end

	p.behaviors = ProjectileProfiles.get(source)
	PB.compileHooks(p)

	return p
end

local function createProjectile(source, target)
	if not source then
		return nil
	end

	local p = acquire()
	initProjectile(p, source, target)

	PB.init(p)
	Sound.play(source.kind)
	projectiles[#projectiles + 1] = p

	return p
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

	local dealt, absorbed = Enemies.applyDamage(e, amount, {
		sourceKind = p.sourceKind,
		chain = evt.chain == true,
		armorHeavy = evt.armorHeavy == true,
	})
	local effectiveDamage = dealt + absorbed

	local t = p.sourceTower

	if t then
		t.damageDealt = (t.damageDealt or 0) + effectiveDamage
		e.lastHitTower = t
	end

	if e.hitFlash <= 0 then
		e.hitFlash = 0.05
	end

	State.addDamage(p.sourceKind, effectiveDamage, e.boss == true)
	RunStats.recordDamage(t, effectiveDamage)
	if effectiveDamage > 0 and (not Save.data or Save.data.settings.showDamageNumbers ~= false) then
		Floaters.add(e.x, e.y - (e.radius or 10), tostring(math.floor(effectiveDamage + 0.5)), 1, 0.82, 0.45)
	end
	local highDamage = effectiveDamage >= math.max(40, (e.maxHp or 0) * 0.12)
	if highDamage then
		Effects.shake(e.boss and 4 or 2.5)
	end
end

local function resolveImpulse(evt)
	local e = evt.target

	if e and not e.boss then
		Enemies.applyHitImpulse(e, evt.dx, evt.dy, evt.strength)
	end
end

local function resolveFX(evt)
	-- Reuse the pooled event as the FX payload while preserving the id needed by
	-- the event dispatcher until this event is returned to its pool.
	local eventID = evt.id
	evt.id = evt.kind
	Effects.spawnFX(evt)
	evt.id = eventID
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
	return createProjectile(t, e)
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

return {
	projectiles = projectiles,
	spawn = spawn,
	update = update,
	draw = draw,
	clear = clear,
	load = load,
}
