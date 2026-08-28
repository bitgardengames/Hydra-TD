-- Owns the zapLines effect family lifecycle and pool configuration.
return function(runtime)
	local list, pool = runtime.Effects.zapLines, runtime.pools.zapLines
	local spawn = runtime.spawn.zapLines
	local function reset(object)
		runtime.resetFields(object, {'x1', 'y1', 'x2', 'y2', 't', 'life'})
	end
	local function release(object)
		reset(object)
		pool[#pool + 1] = object
	end
	local ids = {}
	ids["zap_line"] = function(fx) return spawn(fx.x1, fx.y1, fx.x2, fx.y2) end
	return {
		name = "zapLines", list = list, pool = pool,
		capacity = 32, factory = runtime.emptyEffect, reserve = runtime.reservePool,
		spawn = spawn, ids = ids, update = runtime.update.zapLines,
		draw = runtime.draw.zapLines, drawOverlay = runtime.drawOverlay.zapLines,
		reset = reset, release = release,
	}
end
