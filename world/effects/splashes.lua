-- Owns the splashes effect family lifecycle and pool configuration.
return function(runtime)
	local list, pool = runtime.Effects.splashes, runtime.pools.splashes
	local spawn = runtime.spawn.splashes
	local function reset(object)
		runtime.resetFields(object, {'x', 'y', 'r', 't', 'life'})
	end
	local function release(object)
		reset(object)
		pool[#pool + 1] = object
	end
	local ids = {}
	ids["cannon_impact"] = function(fx) return spawn(fx.x, fx.y, fx.r) end
	return {
		name = "splashes", list = list, pool = pool,
		capacity = 32, factory = runtime.emptyEffect, reserve = runtime.reservePool,
		spawn = spawn, ids = ids, update = runtime.update.splashes,
		draw = runtime.draw.splashes, drawOverlay = runtime.drawOverlay.splashes,
		reset = reset, release = release,
	}
end
