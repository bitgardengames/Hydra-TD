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
local radiusVisitContext = {}
local function statusRadiusVisitor(e, c)
	if e == c.exclude or (c.limit and c.hits >= c.limit) then return end
	if c.op == "poison" then
		e.poisonStacks = min((e.poisonStacks or 0) + c.stacks, e.poisonMaxStacks or math.huge)
		e.poisonDPS = max(e.poisonDPS or 0, c.source.poisonDPS or 0)
		e.poisonTimer = max(e.poisonTimer or 0, c.duration)
		e.poisonDuration = max(e.poisonDuration or 0, c.duration)
		e.poisonSource = c.projectile.sourceTower; c.hits = c.hits + 1
	else
		if not e.slowFactor or c.factor < e.slowFactor then e.slowFactor = c.factor end
		e.slowTimer = max(e.slowTimer or 0, c.duration)
		e.slowDuration = max(e.slowDuration or 0, c.duration)
	end
end
B.apply_slow = {
	hit = function(p, e, data)
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
	hit = function(p, e, data)
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

for id, handlers in pairs(B) do register(id, handlers) end
end
