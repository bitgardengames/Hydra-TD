-- Owns the presentation effect family lifecycle and pool configuration.
return function(runtime)
	local list, pool = runtime.Effects.presentation, runtime.pools.presentation
	local spawn = runtime.spawn.presentation
	local function reset(object)
		runtime.resetFields(object, {'kind', 't', 'life', 'x', 'y', 'path', 'particles'})
	end
	local function release(object)
		reset(object)
		pool[#pool + 1] = object
	end
	local ids = {}
	return {
		name = "presentation", list = list, pool = pool,
		capacity = 0, factory = runtime.emptyEffect, reserve = runtime.reservePool,
		spawn = spawn, ids = ids, update = runtime.update.presentation,
		draw = runtime.draw.presentation, drawOverlay = runtime.drawOverlay.presentation,
		reset = reset, release = release,
	}
end
