-- Owns the zaps effect family lifecycle and pool configuration.
return function(runtime)
	local list, pool = runtime.Effects.zaps, runtime.pools.zaps
	local spawn = runtime.spawn.zaps
	local function reset(object)
		-- Zap release also returns every nested lightning segment to its pool.
		return runtime.releaseZap(object)
	end
	local release = reset
	local ids = {}
	ids["zap"] = function(fx) return spawn(fx.x, fx.y, fx.chain) end
	return {
		name = "zaps", list = list, pool = pool,
		capacity = 12, factory = runtime.zapEffect, reserve = runtime.reservePool,
		spawn = spawn, ids = ids, update = runtime.update.zaps,
		draw = runtime.draw.zaps, drawOverlay = runtime.drawOverlay.zaps,
		reset = reset, release = release,
	}
end
