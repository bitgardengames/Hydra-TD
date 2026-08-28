-- Owns the lancer effect family lifecycle and pool configuration.
return function(runtime)
	local list, pool = runtime.Effects.lancer, runtime.pools.lancer
	local spawn = runtime.spawn.lancer
	local function reset(object)
		runtime.resetFields(object, {'x', 'y', 'vx', 'vy', 'len', 't', 'life'})
	end
	local function release(object)
		reset(object)
		pool[#pool + 1] = object
	end
	local ids = {}
	ids["lancer_hit"] = function(fx) return spawn(fx.x, fx.y) end
	return {
		name = "lancer", list = list, pool = pool,
		capacity = 192, factory = runtime.emptyEffect, reserve = runtime.reservePool,
		spawn = spawn, ids = ids, update = runtime.update.lancer,
		draw = runtime.draw.lancer, drawOverlay = runtime.drawOverlay.lancer,
		reset = reset, release = release,
	}
end
