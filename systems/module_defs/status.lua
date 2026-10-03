return function(catalog)
	local add = function(id, def) catalog:add(id, def) end

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
add("poison_venom_burst", {
	nameKey = "module.poison_venom_burst",
	descKey = "moduleDesc.poison_venom_burst",
	category = "special",

	apply = function(ctx)
		ctx:addBehavior({
			id = "infect_spread",
			data = { radius = 56, stackMult = 1.0 }
		})
	end
})
add("poison_cull_weak", {
	nameKey = "module.poison_cull_weak",
	descKey = "moduleDesc.poison_cull_weak",
	category = "special",

	apply = function(ctx)
		ctx:addBehavior({
			id = "poison_cull_weak",
			data = { maxBonusStacks = 8, bonusPerStack = 0.075 }
		})
	end
})
add("poison_corrupt_strong", {
	nameKey = "module.poison_corrupt_strong",
	descKey = "moduleDesc.poison_corrupt_strong",
	category = "special",

	apply = function(ctx)
		ctx:addBehavior({
			id = "poison_corrupt_strong",
			data = { radius = 60, spreadStacks = 2, spreadDur = 1.25 }
		})
	end
})
add("poison_hemotoxin", {
	nameKey = "module.poison_hemotoxin",
	descKey = "moduleDesc.poison_hemotoxin",
	category = "special",

	apply = function(ctx)
		ctx:addBehavior({
			id = "poison_hemotoxin",
			data = { missingHpMult = 0.75 }
		})
	end
})
add("poison_pandemic", {
	nameKey = "module.poison_pandemic",
	descKey = "moduleDesc.poison_pandemic",
	category = "special",

	apply = function(ctx)
		ctx:addBehavior({
			id = "infect_spread",
			data = { radius = 64, stackMult = 0.65, loop = true }
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
			data = { count = 2 },
			noInherit = true,
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
end
