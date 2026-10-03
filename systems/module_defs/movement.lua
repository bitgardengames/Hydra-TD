return function(catalog)
	local add = function(id, def) catalog:add(id, def) end

add("move_linear", {
	nameKey = "module.move_linear",
	descKey = "moduleDesc.move_linear",
	category = "movement",

	apply = function(ctx)
		ctx:replaceBehavior("move_homing", { id = "move_linear" })
	end
})
add("move_boomerang", {
	nameKey = "module.move_boomerang",
	descKey = "moduleDesc.move_boomerang",
	category = "movement",

	apply = function(ctx)
		ctx:addBehavior({ id = "move_boomerang", data = { dist = 180 } })
	end
})
add("move_wave", {
	nameKey = "module.move_wave",
	descKey = "moduleDesc.move_wave",
	category = "movement",

	apply = function(ctx)
		ctx:addBehavior({ id = "move_wave", data = { amp = 18, freq = 6 } })
	end
})
add("move_spiral", {
	nameKey = "module.move_spiral",
	descKey = "moduleDesc.move_spiral",
	category = "movement",

	apply = function(ctx)
		ctx:addBehavior({ id = "move_spiral", data = { amp = 12, freq = 8 } })
	end
})
add("orbit_shot", {
	nameKey = "module.orbit",
	descKey = "moduleDesc.orbit",
	category = "movement",

	apply = function(ctx)
		ctx:addBehavior({ id = "move_orbit", data = { radius = 48, speed = 4 } })
	end
})
add("suspend_shot", {
	nameKey = "module.suspend",
	descKey = "moduleDesc.suspend",
	category = "movement",

	apply = function(ctx)
		ctx:addBehavior({
			id = "move_suspend",
			data = { delay = 0.25 }
		})
	end
})
end
