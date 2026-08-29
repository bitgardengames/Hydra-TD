-- Behavior implementations for the damage role.
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
local radiusVisitContext = {}
local function radiusVisitor(e, c, d2)
	local p, op = c.p, c.op
	if op == "aoe" then
		local t = 1 - d2 / c.r2
		emitDamage(p, e, p.damage * (c.falloff + (1 - c.falloff) * t)); emitImpulse(p, e, p.x, p.y, 3.2)
	elseif op == "shock" then
		local t = 1 - d2 / c.r2
		emitDamage(p, e, (p.damage or 0) * c.mult * (c.falloff + (1-c.falloff)*t)); emitImpulse(p,e,p.x,p.y,c.impulse)
	elseif op == "slow_pop" then emitDamage(p,e,(p.damage or 0)*0.5)
	elseif op == "supernova" or op == "endpoint" then emitDamage(p,e,c.damage)
	elseif op == "nearest" then
		if (not c.visited or not c.visited[e]) and d2 < c.bestDistance then c.best, c.bestDistance = e, d2 end
	elseif op == "delayed" then
		local b=c.b; local core=(p.damage or 0)*b.damageMult*(b.falloff+(1-b.falloff)*(1-d2/c.r2)); local bonus=0
		if d2>=c.inner2 and d2<=c.outer2 then bonus=(p.damage or 0)*b.ringDamageMult end
		if bonus>0 then bonus=min(bonus,core*b.ringOverlapCapMult) end
		local total=core+bonus; if p.longFuseHitSet and p.longFuseHitSet[e.id] then total=total*b.repeatHitMult end
		emitDamage(p,e,total); emitImpulse(p,e,p.x,p.y,4.2)
	elseif op == "tick" then
		emitDamage(p,e,p.damage or 0)
		if c.data and c.data.impulse and c.data.impulse > 0 then emitImpulse(p,e,p.x,p.y,c.data.impulse) end
		local id=e.id or e; local active=p.getHitCooldownExpiry and p.getHitCooldownExpiry(p,id)
		if not active then local evt=emitEvent(p,"hit"); evt.target=e; evt.origin=p.hitOrigin or "primary"; if p.setHitCooldownExpiry then p.setHitCooldownExpiry(p,id,c.data.hitRate or .35) else p.hitCooldowns[id]=c.data.hitRate or .35 end end
		local fx=emitFX(p,"plasma_hit"); fx.x=p.x; fx.y=p.y; fx.vx=p.vx or 0; fx.vy=p.vy or 0; fx.color=p.sourceTower and p.sourceTower.color
	end
end
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
		radiusVisitContext.p, radiusVisitContext.op = p, "aoe"
		radiusVisitContext.r2, radiusVisitContext.falloff = r2, falloff
		Spatial.visitRadius(p.x, p.y, radius, radiusVisitor, radiusVisitContext, spatialQueryContext, Spatial.radiusOptions.default)

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

		radiusVisitContext.p, radiusVisitContext.op = p, "shock"
		radiusVisitContext.r2, radiusVisitContext.mult = r2, damageMult
		radiusVisitContext.falloff, radiusVisitContext.impulse = minFalloff, impulse
		Spatial.visitRadius(p.x, p.y, radius, radiusVisitor, radiusVisitContext,
			spatialQueryContext, Spatial.radiusOptions.living)
	end
}

B.cannon_damage_scale = {
	init = function(p, data)
		p.damage = (p.damage or 0) * (data.mult or 1)
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
			ringOverlapCapMult = data.ringOverlapCapMult or 0.45,
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

		radiusVisitContext.p, radiusVisitContext.op, radiusVisitContext.b = p, "delayed", b
		radiusVisitContext.r2, radiusVisitContext.inner2, radiusVisitContext.outer2 = r2, ringInner2, ringOuter2
		Spatial.visitRadius(p.x, p.y, radius, radiusVisitor, radiusVisitContext,
			spatialQueryContext, Spatial.radiusOptions.living)

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
		local chain = p._retained.chain
		clearArray(chain)
		p._chain = chain

		local visited = p._retained.chainVisited
		clearMap(visited)
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

			radiusVisitContext.op, radiusVisitContext.visited = "nearest", visited
			radiusVisitContext.best, radiusVisitContext.bestDistance = nil, bestDist
			Spatial.visitRadius(current.x, current.y, radius, radiusVisitor, radiusVisitContext,
				spatialQueryContext, Spatial.radiusOptions.living)
			nextTarget = radiusVisitContext.best

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

B.chain_static_surge = {
	type = "damage",

	onHit = function(p, e, data)
		if not p._chain then return end
		data = data or {}

		local bonusPerStack = data.bonusPerStack or 0.2
		local maxStacks = data.maxStacks or 6
		local fullStacks = max(1, data.fullStacks or 3)
		local postFullScale = data.postFullScale or 0.5
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

				local effectiveSteps
				if stacks <= fullStacks then
					effectiveSteps = stacks - 1
				else
					local earlySteps = fullStacks - 1
					local lateSteps = stacks - fullStacks
					effectiveSteps = earlySteps + (lateSteps * postFullScale)
				end

				local extraMult = effectiveSteps * bonusPerStack
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
		local endpoints = p._retained.endpointScratch
		clearMap(endpoints)

		local hasOutgoing = p._retained.hasOutgoingScratch
		clearMap(hasOutgoing)

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

				radiusVisitContext.p, radiusVisitContext.op = p, "endpoint"
				radiusVisitContext.damage = (p.damage or 0) * dmgMult
				Spatial.visitRadius(target.x, target.y, radius, radiusVisitor, radiusVisitContext,
					spatialQueryContext, Spatial.radiusOptions.living)
			end
		end
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

		radiusVisitContext.op, radiusVisitContext.visited = "nearest", nil
		radiusVisitContext.best, radiusVisitContext.bestDistance = nil, r2
		Spatial.visitRadius(p.x, p.y, radius, radiusVisitor, radiusVisitContext,
			spatialQueryContext, Spatial.radiusOptions.living)
		local best = radiusVisitContext.best

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

B.slow_pop = {
	onHit = function(p, e)
		if not e or e.hp <= 0 then
			return
		end

		if e.slowTimer and e.slowTimer > 0 then
			local radius = 28
			radiusVisitContext.p, radiusVisitContext.op = p, "slow_pop"
			Spatial.visitRadius(e.x, e.y, radius, radiusVisitor, radiusVisitContext, spatialQueryContext, Spatial.radiusOptions.default)

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

		radiusVisitContext.p, radiusVisitContext.op, radiusVisitContext.damage = p, "supernova", dmg
		Spatial.visitRadius(p.x, p.y, radius, radiusVisitor, radiusVisitContext, spatialQueryContext, Spatial.radiusOptions.livingCollision)

		local evt = emitFX(p, "plasma_hit")
		evt.x = p.x
		evt.y = p.y
		evt.color = p.sourceTower and p.sourceTower.color

		return "consume"
	end
}

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
		radiusVisitContext.p, radiusVisitContext.op = p, "tick"
		radiusVisitContext.data = data
		Spatial.visitRadius(p.x, p.y, radius, radiusVisitor, radiusVisitContext,
			spatialQueryContext, Spatial.radiusOptions.livingCollision)

		t.timer = t.rate
	end
}

-- =========================
-- VISUALS (NOW MODULAR)
-- =========================

for id, handlers in pairs(B) do register({ id = id, role = "damage", handlers = handlers }) end
end
