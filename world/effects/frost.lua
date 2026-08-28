-- Owns the frost effect family lifecycle and pool configuration.
return function(runtime)
	local list, pool = runtime.Effects.frost, runtime.pools.frost
	local spawn = runtime.spawn.frost
	local function reset(object)
		runtime.resetFields(object, {'x', 'y', 'vx', 'vy', 'r', 'rot', 'vr', 't', 'life'})
	end
	local function release(object)
		reset(object)
		pool[#pool + 1] = object
	end
	local ids = {}
	ids["frost_burst"] = function(fx) return spawn(fx.x, fx.y) end
	return {
		name = "frost", list = list, pool = pool,
		capacity = 288, factory = runtime.emptyEffect, reserve = runtime.reservePool,
		spawn = spawn, ids = ids, update = runtime.update.frost,
		draw = runtime.draw.frost, drawOverlay = runtime.drawOverlay.frost,
		reset = reset, release = release,
	}
end
