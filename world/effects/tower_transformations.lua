-- Owns the towerTransformations effect family lifecycle and pool configuration.
return function(runtime)
	local list, pool = runtime.Effects.towerTransformations, runtime.pools.towerTransformations
	local spawn = runtime.spawn.towerTransformations
	local function reset(object)
		runtime.resetFields(object, {'x', 'y', 't', 'life', 'color', 'range', 'cadencePulse', 'finalTier', 'particles'})
	end
	local function release(object)
		reset(object)
		pool[#pool + 1] = object
	end
	local ids = {}
	return {
		name = "towerTransformations", list = list, pool = pool,
		capacity = 0, factory = runtime.emptyEffect, reserve = runtime.reservePool,
		spawn = spawn, ids = ids, update = runtime.update.towerTransformations,
		draw = runtime.draw.towerTransformations, drawOverlay = runtime.drawOverlay.towerTransformations,
		reset = reset, release = release,
	}
end
