-- Behavior implementations for the damage role.
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

					if ringBonus > 0 then
						local ringCap = coreDmg * b.ringOverlapCapMult
						ringBonus = min(ringBonus, ringCap)
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

for id, handlers in pairs(B) do register({ id = id, role = "damage", handlers = handlers }) end
end
