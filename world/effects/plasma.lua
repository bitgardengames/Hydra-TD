-- Owns the plasmaParticles effect family lifecycle and pool configuration.
return function(runtime)
	local list, pool = runtime.Effects.plasmaParticles, runtime.pools.plasmaParticles
	local spawn = runtime.spawn.plasmaParticles
	local function reset(object)
		runtime.resetFields(object, {'x', 'y', 'vx', 'vy', 'drag', 'r', 't', 'life'})
	end
	local function release(object)
		reset(object)
		pool[#pool + 1] = object
	end
	local ids = {}
	ids["plasma_hit"] = function(fx) return spawn(fx.x, fx.y, fx.vx or 0, fx.vy or 0) end
	return {
		name = "plasmaParticles", list = list, pool = pool,
		capacity = 256, factory = runtime.emptyEffect, reserve = runtime.reservePool,
		spawn = spawn, ids = ids, update = runtime.update.plasmaParticles,
		draw = runtime.draw.plasmaParticles, drawOverlay = runtime.drawOverlay.plasmaParticles,
		reset = reset, release = release,
	}
end
