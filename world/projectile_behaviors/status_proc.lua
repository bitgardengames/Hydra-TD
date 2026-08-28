-- Behavior implementations for the status_proc role.
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
		local ringOverlapCapMult = data.ringOverlapCapMult or 0.45

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
				ringOverlapCapMult = ringOverlapCapMult,
			}},
		}
	end
}

B.slow_burst_cleave = {
	type = "damage",

	onHit = function(p, e, data)
		if not e or e.hp <= 0 then
			return
		end

		if not e.slowTimer or e.slowTimer <= 0 then
			return
		end

		local tower = p.sourceTower
		if not tower then
			return
		end

		data = data or {}
		local now = p.t or 0
		local cooldown = data.cooldown or 1.25
		local nextReady = tower._slowBurstCleaveReadyAt or 0
		if now < nextReady then
			return
		end
		tower._slowBurstCleaveReadyAt = now + cooldown

		local count = data.count or 5
		local dmgMult = data.dmgMult or 0.33
		local ringOffset = data.ringOffset or 14
		local travelDistance = data.travelDistance or 650
		local base = p.rotation or 0
		local step = (2 * pi) / count

		for i = 1, count do
			local ang = base + (i - 1) * step
			local spawnX = e.x + cos(ang) * ringOffset
			local spawnY = e.y + sin(ang) * ringOffset
			local evt = emitSpawnProjectile(p)
			evt.x = spawnX
			evt.y = spawnY
			evt.angle = ang
			evt.lastTX = spawnX + cos(ang) * travelDistance
			evt.lastTY = spawnY + sin(ang) * travelDistance
			evt.damage = (p.damage or 0) * dmgMult
			evt.source = tower
			evt.parent = p
			evt.ignoreTarget = e
			evt.splitGeneration = (p.splitGeneration or 0) + 1
		end
	end
}

B.lancer_overdrive = {
	onShot = function(p, data)
		local tower = p and p.sourceTower
		if not tower then
			return
		end

		data = data or {}
		local triggerEvery = max(1, floor(data.triggerEvery or 4))
		local nextHitIndex = (tower._lancerOverdriveHits or 0) + 1
		p._overdriveRound = (nextHitIndex % triggerEvery) == 0
	end,

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

B.chaos_bounce = {
	onHit = function(p, e, data)
		local ang = random() * (pi * 2)

		p.vx = cos(ang)
		p.vy = sin(ang)
		p.hit = nil
	end
}

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

B.plasma_conductor = {
	update = function(p, dt, data)
		p._conductRadius = data.radius or 42
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

		local nearby, nearbyCount = Spatial.queryCells(e.x, e.y, data.radius or 64, spatialQueryContext)
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

B.projectile_visual_scale = {
	init = function(p, data)
		if not data or not data.scale then
			return
		end

		p.visualScale = data.scale
	end
}

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

B.slow_aura = {
	on_shot = function(p, data)
		p._slowAuraTimer = 0
		p._slowAuraTick = data.tick or 0.28
		p._slowAuraRadius = data.radius or 56
	end,

	on_tick = function(p, dt, data)
		local tower = p.sourceTower
		if not tower then
			return
		end

		p._slowAuraTimer = (p._slowAuraTimer or 0) - dt
		if p._slowAuraTimer > 0 then
			return
		end

		local cx = tower.x
		local cy = tower.renderY or tower.y
		local radius = data.radius or p._slowAuraRadius or 56
		local slowDur = data.dur or 0.6
		local slowFactor = min(data.factor or 0.22, 0.9)
		local newFactor = 1 - slowFactor

		local nearby, nearbyCount = Spatial.queryCells(cx, cy, radius, spatialQueryContext)
		for i = 1, nearbyCount do
			local e = nearby[i]
			if e and e.hp > 0 then
				local dx = e.x - cx
				local dy = e.y - cy
				local rr = radius + (e.radius or 0)
				if dx * dx + dy * dy <= rr * rr then
					if not e.slowFactor or newFactor < e.slowFactor then
						e.slowFactor = newFactor
					end
					e.slowTimer = max(e.slowTimer or 0, slowDur)
					e.slowDuration = max(e.slowDuration or 0, slowDur)
				end
			end
		end

		local evt = emitFX(p, "frost_burst")
		evt.x = cx
		evt.y = cy
		evt.color = tower.color
		evt.scale = data.fxScale or 0.7

		p._slowAuraTimer = p._slowAuraTick or 0.28
	end
}

B.apply_poison = {
	onHit = function(p, e, data)
		if e and e.hp > 0 then
			e.poisonStacks = e.poisonStacks or 0
			e.poisonMaxStacks = max(e.poisonMaxStacks or 0, data.maxStacks)
			e.poisonDPS = max(e.poisonDPS or 0, data.dps)
			e.poisonRampPerTick = max(e.poisonRampPerTick or 0, data.rampPerTick or 0)
			e.poisonRampMax = max(e.poisonRampMax or 1, data.rampMax or 1)
			e.poisonRamp = max(e.poisonRamp or 1, 1)

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

for id, handlers in pairs(B) do register({ id = id, role = "status_proc", handlers = handlers }) end
end
