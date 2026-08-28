-- Owns the placePuffs effect family lifecycle and pool configuration.
return function(runtime)
	local list, pool = runtime.Effects.placePuffs, runtime.pools.placePuffs
	local spawn = runtime.spawn.placePuffs
	local function reset(object)
		runtime.resetFields(object, {'x', 'y', 'vx', 'vy', 'r', 't', 'life'})
	end
	local function release(object)
		reset(object)
		pool[#pool + 1] = object
	end
	local ids = {}
	return {
		name = "placePuffs", list = list, pool = pool,
		capacity = 330, factory = runtime.emptyEffect, reserve = runtime.reservePool,
		spawn = spawn, ids = ids, update = runtime.update.placePuffs,
		draw = runtime.draw.placePuffs, drawOverlay = runtime.drawOverlay.placePuffs,
		reset = reset, release = release,
	}
end
