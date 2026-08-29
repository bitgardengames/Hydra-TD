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
local radiusVisitContext = {}
local chainDamageMetadata = { chain = true }
local function radiusVisitor(e, c, d2)
	local p, op = c.p, c.op
	if op == "aoe" then
		local t = 1 - d2 / c.r2
		emitDamage(p, e, p.damage * (c.falloff + (1 - c.falloff) * t), c.damageMetadata); emitImpulse(p, e, p.x, p.y, 3.2)
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
	onHit = function(p, e, data)
		if not e or e.hp <= 0 then
			return
		end

		local dmg = getStat(p, "damage", 0)
		emitDamage(p, e, dmg, data)
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
		radiusVisitContext.damageMetadata = data
		Spatial.visitRadius(p.x, p.y, radius, radiusVisitor, radiusVisitContext, spatialQueryContext, Spatial.radiusOptions.default)

		local evt = emitFX(p, "cannon_impact")
		evt.x = p.x
		evt.y = p.y
		evt.r = radius -- ALSO scaled for visuals
		evt.color = p.sourceTower and p.sourceTower.color
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
				emitDamage(p, current, dealt, chainDamageMetadata)
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
