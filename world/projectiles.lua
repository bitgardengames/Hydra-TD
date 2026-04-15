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

local function acquire()
	local p = pool[#pool]

	if p then
		pool[#pool] = nil

		return p
	end

	return {}
end

local function release(p)
	for k in pairs(p) do
		p[k] = nil
	end

	pool[#pool + 1] = p
end

local function removeAt(i)
	local p = projectiles[i]

	release(p)

	projectiles[i] = projectiles[#projectiles]
	projectiles[#projectiles] = nil
end

local function spawnEvent(evt)
	local source = evt.source

	if not source then
		return nil
	end

	local p = acquire()

	p.x = evt.x or source.x
	p.y = evt.y or source.renderY or source.y

	p.r = evt.r or 4.5
	p.baseR = p.r
	p.scale = evt.scale or 1

	p.life = evt.life or 3
	p.t = 0

	p.sourceTower = source
	p.sourceKind = source.kind

	p.speed = evt.speed or source.projSpeed or 0
	p.damage = evt.damage or source.damage or 0

	p.target = evt.target
	p.ignoreTarget = evt.ignoreTarget

	p.angle = evt.angle or source.angle or 0
	p.rotation = p.angle

	p.vx = evt.vx
	p.vy = evt.vy

	p.hit = nil
	p.events = nil
	p._consumed = false

	p.hitSet = {}
	p.hitCooldowns = {}

	p.hitRadius = evt.hitRadius or p.r
	p.hitRadius2 = p.hitRadius * p.hitRadius

	if p.target then
		p.lastTX = p.target.x
		p.lastTY = p.target.y
	elseif evt.lastTX and evt.lastTY then
		p.lastTX = evt.lastTX
		p.lastTY = evt.lastTY
	elseif p.vx and p.vy then
		p.lastTX = p.x + p.vx * 10
		p.lastTY = p.y + p.vy * 10
	else
		p.lastTX = p.x + cos(p.angle) * 10
		p.lastTY = p.y + sin(p.angle) * 10
	end

	if evt.context then
		p.behaviors = evt.context.behaviors
	else
		local ctx = Modules.buildContext(source)
		p.behaviors = ctx.behaviors
	end

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

		newP.lastTX = newP.x + newP.vx * 10
		newP.lastTY = newP.y + newP.vy * 10
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

local function resolveFX(evt, p)
	local c = evt.color

	if not c and p and p.sourceTower and p.sourceTower.color then
		c = p.sourceTower.color
	end

	Effects.spawnFX({
		id = evt.kind,
		x = evt.x,
		y = evt.y,
		r = evt.r,
		vx = evt.vx,
		vy = evt.vy,
		x1 = evt.x1,
		y1 = evt.y1,
		x2 = evt.x2,
		y2 = evt.y2,
		chain = evt.chain,
		color = c
	})
end

local function resolveEvents(p)
	while p.events and #p.events > 0 do
		local list = p.events
		p.events = nil

		for i = 1, #list do
			local evt = list[i]

			if evt and evt.id then
				if evt.id == "spawn_projectile" then
					resolveSpawnProjectile(p, evt)
				elseif evt.id == "damage" then
					resolveDamage(p, evt)
				elseif evt.id == "impulse" then
					resolveImpulse(evt)
				elseif evt.id == "fx" then
					resolveFX(evt, p)
				elseif evt.id == "hit" then
					local res = PB.hit(p, evt.target)

					if res == "consume" then
						p._consumed = true
					end
				elseif evt.id == "consume" then
					p._consumed = true
				end
			end
		end
	end
end

local function processHit(p)
	local hitTarget = p.hit

	if hitTarget and p.ignoreTarget and hitTarget == p.ignoreTarget then
		p.hit = nil
		return
	end

	-- allow nil target for impact-only hits
	if not hitTarget then
		pushEvent(p, {id = "hit", target = nil})
		resolveEvents(p)
		return
	end

	if hitTarget.hp <= 0 then
		p.hit = nil
		return
	end

	p.hit = nil

	local id = hitTarget.id or hitTarget
	local multiHit = p.allowRepeatHits == true

	if not multiHit and p.hitSet[id] then
		return
	end

	if not multiHit then
		p.hitSet[id] = true
	end

	pushEvent(p, {
		id = "hit",
		target = hitTarget
	})

	resolveEvents(p)
end

local function updateHitCooldowns(p, dt)
	local cds = p.hitCooldowns

	if not cds then
		return
	end

	for id, t in pairs(cds) do
		t = t - dt

		if t <= 0 then
			cds[id] = nil
		else
			cds[id] = t
		end
	end
end

local function spawn(t, e)
	spawnEvent({
		source = t,
		target = e
	})
end

local function update(dt)
	for i = #projectiles, 1, -1 do
		local p = projectiles[i]

		p.life = p.life - dt
		p.t = p.t + dt

		updateHitCooldowns(p, dt)

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

local function spawnFromContext(t, target, ctx, overrides)
	return spawnEvent({
		source = t,
		target = target,
		behaviors = ctx.behaviors,

		-- allow overrides (beam uses this)
		speed = overrides and overrides.speed,
		life = overrides and overrides.life,
	})
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