-- Owns the death effect family lifecycle and pool configuration.
return function(runtime)
	local list, pool = runtime.Effects.death, runtime.pools.death
	local spawn = runtime.spawn.death
	local function reset(object)
		runtime.resetFields(object, {'x', 'y', 'r', 't', 'life'})
	end
	local function release(object)
		reset(object)
		pool[#pool + 1] = object
	end
	local ids = {}
	return {
		name = "death", list = list, pool = pool,
		capacity = 32, factory = runtime.emptyEffect, reserve = runtime.reservePool,
		spawn = spawn, ids = ids, update = runtime.update.death,
		draw = runtime.draw.death, drawOverlay = runtime.drawOverlay.death,
		reset = reset, release = release,
	}
end
