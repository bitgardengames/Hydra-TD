-- Behavior implementations for the emission role.
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
local beamVisitContext = {}
local function emissionRadiusVisitor(e, c, d2)
	if c.op == "nearest" then
		if e ~= c.exclude and d2 <= c.bestDistance then c.best, c.bestDistance = e, d2 end
	elseif c.op == "fork" then
		if e ~= c.from and not c.claimed[e] then
			local fork = c.forks[#c.forks + 1] or {}; fork.from, fork.to = c.from, e; c.forks[#c.forks + 1] = fork
			c.claimed[e] = true; local dmg=consumeChainDamageBudget(c.p,(c.p.damage or 0)*c.mult); if dmg>0 then emitDamage(c.p,e,dmg) end
			c.added=c.added+1; if c.added >= c.limit then return false end
		end
	elseif c.op == "poison" and e ~= c.exclude then
		e.poisonStacks=(e.poisonStacks or 0)+c.stacks; e.poisonTimer=max(e.poisonTimer or 0,1.5)
	elseif c.op == "beam" then
		local id=e.id or e
		if not c.cooldowns[id] then local evt=emitEvent(c.p,"hit"); evt.target=e; evt.origin="beam"; evt.hitX=c.x; evt.hitY=c.y; c.cooldowns[id]=c.rate end
	end
end
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

for id, handlers in pairs(B) do register({ id = id, role = "emission", handlers = handlers }) end
end
