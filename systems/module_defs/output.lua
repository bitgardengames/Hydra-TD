return function(catalog)
	local add = function(id, def) catalog:add(id, def) end

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
		local found = false

		ctx:modifyBehavior("hit_chain", function(data)
			data.jumps = (data.jumps or 0) + 2
			data.radius = (data.radius or 56) + 12
			found = true
		end)

		if not found then
			ctx:addBehavior({
				id = "hit_chain",
				data = { jumps = 3, radius = 72 }
			})
		end
	end
})
add("chain_fork", {
	nameKey = "module.chain_fork",
	descKey = "moduleDesc.chain_fork",
	category = "damage",

	apply = function(ctx)
		ctx:addBehavior({
			id = "fork_chain",
			data = {radius = 52, dmgMult = 0.35}
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
add("pierce", {
	nameKey = "module.pierce",
	descKey = "moduleDesc.pierce",
	category = "damage",

	apply = function(ctx)
		local hasHitDetector = false
		for i = 1, #ctx.behaviors do
			local id = ctx.behaviors[i].id
			if ProjectileBehaviorRegistry.getRole(id) == "collision" then
				hasHitDetector = true
				break
			end
		end

		if not hasHitDetector then
			ctx:addBehavior({ id = "hit_circle", data = { radius = 10 } })
		end

		ctx:addBehavior({
			id = "pierce",
			data = { maxHits = 3 }
		})
	end
})
add("lancer_ricochet", {
	nameKey = "module.lancer_ricochet",
	descKey = "moduleDesc.lancer_ricochet",
	category = "damage",

	apply = function(ctx)
		ctx:addBehavior({
			id = "lancer_ricochet",
			data = { radius = 96 }
		})
	end
})
add("explode_on_hit", {
	nameKey = "module.explode",
	descKey = "moduleDesc.explode",
	category = "damage",

	apply = function(ctx)
		ctx:addBehavior({
			id = "explode_on_hit",
			data = { radius = 48 }
		})
	end
})
add("target_low_hp", {
	nameKey = "module.target_low_hp",
	descKey = "moduleDesc.target_low_hp",
	category = "damage",

	apply = function(ctx)
		ctx:addBehavior({
			id = "lancer_opening_strike",
			data = { triggerHpFrac = 0.45, bonusDmgMult = 0.9 }
		})
	end
})
add("target_farthest_progress", {
	nameKey = "module.target_farthest_progress",
	descKey = "moduleDesc.target_farthest_progress",
	category = "damage",

	apply = function(ctx)
		ctx:addBehavior({
			id = "aoe_damage",
			data = { radius = 34, falloff = 0.84 }
		})
	end
})
add("target_farthest_range", {
	nameKey = "module.target_farthest_range",
	descKey = "moduleDesc.target_farthest_range",
	category = "damage",

	apply = function(ctx)
		ctx:addBehavior({
			id = "cannon_carpet_fire",
			data = { delayA = 0.12, delayB = 0.24, spread = 0.16 }
		})
	end
})
add("target_high_hp", {
	nameKey = "module.target_high_hp",
	descKey = "moduleDesc.target_high_hp",
	category = "damage",

	apply = function(ctx)
		ctx:addBehavior({
			id = "poison_corrupt_strong",
			data = { triggerHpFrac = 0.65, splashRadius = 42, splashDps = 4.2, splashDur = 1.9, splashMaxStacks = 5 }
		})
	end
})
add("beam_conversion", {
	nameKey = "module.beam",
	descKey = "moduleDesc.beam",
	category = "special",

	apply = function(ctx)
		ctx.output = "beam"
		ctx:removeByType("movement")
		ctx:addBehavior({ id = "beam", data = { length = 200, width = 8, rate = 0.1 } }) -- can we make the width respect any other modifiers that should increase the thickness
	end
})
end
