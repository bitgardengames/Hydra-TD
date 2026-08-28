-- Owns the poison effect family lifecycle and pool configuration.
return function(runtime)
	local list, pool = runtime.Effects.poison, runtime.pools.poison
	local spawn = runtime.spawn.poison
	local function reset(object)
		runtime.resetFields(object, {'x', 'y', 'vx', 'vy', 'drag', 'dragMultiplier', 'r', 't', 'life'})
	end
	local function release(object)
		reset(object)
		pool[#pool + 1] = object
	end
	local ids = {}
	ids["poison_splash"] = function(fx) return spawn(fx.x, fx.y) end
	return {
		name = "poison", list = list, pool = pool,
		capacity = 224, factory = runtime.emptyEffect, reserve = runtime.reservePool,
		spawn = spawn, ids = ids, update = runtime.update.poison,
		draw = runtime.draw.poison, drawOverlay = runtime.drawOverlay.poison,
		reset = reset, release = release,
	}
end
