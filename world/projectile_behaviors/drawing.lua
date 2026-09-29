-- Behavior implementations for the drawing role.
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
B.draw_rail_lance = {
	draw = function(p, a)
		local w = p.r * 3.0
		local h = p.r * 0.9

		lg.setColor(1,1,1,a)
		lg.rectangle("fill", -w/2, -h/2, w, h, h, h)
	end
}

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

B.draw_lancer = {
	draw = function(p, a)
		local rx = p.r * (6 / 4.5)
		local ry = p.r * (3 / 4.5)

		local r, g, b
		if p._overdriveRound then
			r, g, b = 1.0, 0.58, 0.14
		else
			r, g, b = getProjectileColor(p, {0.97, 0.97, 0.97})
		end
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
		local visualScale = p.visualScale or 1
		local displayR = p.r * visualScale
		local outer = displayR * (8 / 4.5) + pulse * (1.2 / 4.5) * displayR
		local inner = displayR * (4.5 / 4.5) + pulse * (0.6 / 4.5) * displayR

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

for id, handlers in pairs(B) do register({ id = id, role = "drawing", handlers = handlers }) end
end
