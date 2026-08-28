-- Owns the explosions effect family lifecycle and pool configuration.
return function(runtime)
	local list, pool = runtime.Effects.explosions, runtime.pools.explosions
	local spawn = runtime.spawn.explosions
	local function reset(object)
		runtime.resetFields(object, {'x', 'y', 'vx', 'vy', 'r', 't', 'life', 'type'})
	end
	local function release(object)
		reset(object)
		pool[#pool + 1] = object
	end
	local ids = {}
	return {
		name = "explosions", list = list, pool = pool,
		capacity = 349, factory = runtime.emptyEffect, reserve = runtime.reservePool,
		spawn = spawn, ids = ids, update = runtime.update.explosions,
		draw = runtime.draw.explosions, drawOverlay = runtime.drawOverlay.explosions,
		reset = reset, release = release,
	}
end
