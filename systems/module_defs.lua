local ModuleDefs = {}

-- helper for cleaner modules
local function add(id, def)
	def.id = id
	ModuleDefs[id] = def
end

-- =========================
-- MOVEMENT
-- =========================

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

-- =========================
-- DAMAGE
-- =========================

add("split_on_hit", {
	nameKey = "module.split",
	descKey = "moduleDesc.split",
	category = "damage",

	apply = function(ctx)
		ctx:addBehavior({
			id = "split_on_hit",
			data = { count = 2 },
			noInherit = true
		})
	end
})

add("chain_hit", {
	nameKey = "module.chain",
	descKey = "moduleDesc.chain",
	category = "damage",

	apply = function(ctx)
		ctx:addBehavior({
			id = "hit_chain",
			data = { jumps = 3, radius = 72 }
		})
	end
})

add("aoe_damage", {
	nameKey = "module.aoe",
	descKey = "moduleDesc.aoe",
	category = "damage",

	apply = function(ctx)
		ctx:addBehavior({
			id = "aoe_damage",
			data = { radius = 48 }
		})
	end
})

add("tick_damage", {
	nameKey = "module.tick",
	descKey = "moduleDesc.tick",
	category = "damage",

	apply = function(ctx)
		ctx:addBehavior({
			id = "tick_damage",
			data = { radius = 16, rate = 0.2 }
		})
	end
})

add("growing_projectile", {
	nameKey = "module.growth",
	descKey = "moduleDesc.growth",
	category = "damage",

	apply = function(ctx)
		ctx:addBehavior({
			id = "growing_projectile",
			data = { scale = 2.2 }
		})
	end
})

add("chaos_bounce", {
	nameKey = "module.bounce",
	descKey = "moduleDesc.bounce",
	category = "damage",

	apply = function(ctx)
		ctx:addBehavior({ id = "chaos_bounce" })
	end
})

-- =========================
-- UTILITY / SYNERGY
-- =========================

add("apply_slow", {
	nameKey = "module.slow",
	descKey = "moduleDesc.slow",
	category = "utility",

	apply = function(ctx)
		ctx:addBehavior({
			id = "apply_slow",
			data = { factor = 0.5, dur = 1.2 }
		})
	end
})

add("apply_poison", {
	nameKey = "module.poison",
	descKey = "moduleDesc.poison",
	category = "utility",

	apply = function(ctx)
		ctx:addBehavior({
			id = "apply_poison",
			data = { dps = 4, dur = 2, maxStacks = 6 }
		})
	end
})

add("infect_spread", {
	nameKey = "module.infect",
	descKey = "moduleDesc.infect",
	category = "utility",

	apply = function(ctx)
		ctx:addBehavior({
			id = "infect_spread",
			data = { radius = 48 }
		})
	end
})

add("spawn_orbitals", {
	nameKey = "module.orbital_spawn",
	descKey = "moduleDesc.orbital_spawn",
	category = "utility",

	apply = function(ctx)
		ctx:addBehavior({
			id = "spawn_orbital_on_hit",
			data = { count = 2 }
		})
	end
})

add("static_field", {
	nameKey = "module.static",
	descKey = "moduleDesc.static",
	category = "utility",

	apply = function(ctx)
		ctx:addBehavior({
			id = "spawn_static_field",
			data = { radius = 48 }
		})
	end
})

-- =========================
-- SPECIAL (SPICY)
-- =========================

add("beam_conversion", {
	nameKey = "module.beam",
	descKey = "moduleDesc.beam",
	category = "special",

	apply = function(ctx)
		ctx.output = "beam"
		ctx:removeBehavior("move_homing")
		ctx:removeBehavior("instant_hit")
		ctx:addBehavior({ id = "beam", data = { length = 200, width = 8, rate = 0.1 } }) -- can we make the width respect any other modifiers that should increase the thickness
	end
})

return ModuleDefs