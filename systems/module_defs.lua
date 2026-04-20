local ModuleDefs = {}
local Targeting = require("world.targeting")

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

-- Bounce isn't working currently
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

-- Is it weird to give up the identity of poison/slow so easily?
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

-- Is it weird to give up the identity of poison/slow so easily?
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

add("pierce", {
	nameKey = "module.pierce",
	descKey = "moduleDesc.pierce",
	category = "damage",

	apply = function(ctx)
		ctx:replaceBehavior("move_homing", { id = "move_linear" })

		local hasHitDetector = false
		for i = 1, #ctx.behaviors do
			local id = ctx.behaviors[i].id
			if id == "hit_circle" or id == "instant_hit" or id == "emit_on_target" then
				hasHitDetector = true
				break
			end
		end

		if not hasHitDetector then
			ctx:addBehavior({ id = "hit_circle", data = { radius = 10 } })
		end

		ctx:addBehavior({ id = "pierce" })
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

-- Isn't this the same as the aoe module?
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

-- =========================
-- TARGETING
-- =========================

add("target_low_hp", {
	nameKey = "module.target_low_hp",
	descKey = "moduleDesc.target_low_hp",
	category = "targeting",
	targetMode = Targeting.MODES.LOW_HP,

	apply = function(_)
	end
})

add("target_farthest_progress", {
	nameKey = "module.target_farthest_progress",
	descKey = "moduleDesc.target_farthest_progress",
	category = "targeting",
	targetMode = Targeting.MODES.PROGRESS,

	apply = function(_)
	end
})

add("target_farthest_range", {
	nameKey = "module.target_farthest_range",
	descKey = "moduleDesc.target_farthest_range",
	category = "targeting",
	targetMode = Targeting.MODES.FARTHEST,

	apply = function(_)
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
		ctx:removeByType("movement")
		ctx:addBehavior({ id = "beam", data = { length = 200, width = 8, rate = 0.1 } }) -- can we make the width respect any other modifiers that should increase the thickness
	end
})

-- =========================
-- TOWER SPECIALIZATIONS
-- =========================

local function addSpec(id, nameKey, descKey, behaviors, targetMode)
	local function cloneBehaviors()
		local out = {}

		for i = 1, #behaviors do
			local src = behaviors[i]
			local copy = {id = src.id}

			if src.noInherit then
				copy.noInherit = true
			end

			if src.data then
				local data = {}
				for k, v in pairs(src.data) do
					data[k] = v
				end
				copy.data = data
			end

			out[#out + 1] = copy
		end

		return out
	end

	add(id, {
		nameKey = nameKey,
		descKey = descKey,
		category = "special",
		targetMode = targetMode,

		apply = function(ctx)
			ctx.behaviors = cloneBehaviors()
		end
	})
end

addSpec("slow_glacier_core", "module.slow_glacier_core", "moduleDesc.slow_glacier_core", {
	{id = "move_homing"},
	{id = "hit_damage"},
	{id = "apply_slow", data = {factor = 0.42, dur = 2.3}},
	{id = "draw_slow"},
})

addSpec("slow_permafrost", "module.slow_permafrost", "moduleDesc.slow_permafrost", {
	{id = "move_homing"},
	{id = "hit_damage"},
	{id = "apply_slow", data = {factor = 0.58, dur = 1.6}},
	{id = "aoe_damage", data = {radius = 34}},
	{id = "draw_slow"},
})

addSpec("slow_frost_nova", "module.slow_frost_nova", "moduleDesc.slow_frost_nova", {
	{id = "move_homing"},
	{id = "hit_damage"},
	{id = "apply_slow", data = {factor = 0.5, dur = 1.7}},
	{id = "spawn_static_field", data = {radius = 42}},
	{id = "draw_slow"},
})

addSpec("slow_shatterburst", "module.slow_shatterburst", "moduleDesc.slow_shatterburst", {
	{id = "move_homing"},
	{id = "hit_damage"},
	{id = "apply_slow", data = {factor = 0.52, dur = 1.4}},
	{id = "frost_shatter", data = {count = 6, dmgMult = 0.45}},
	{id = "draw_slow"},
})

addSpec("slow_cold_snap", "module.slow_cold_snap", "moduleDesc.slow_cold_snap", {
	{id = "move_homing"},
	{id = "hit_damage"},
	{id = "apply_slow", data = {factor = 0.5, dur = 1.5}},
	{id = "slow_pop"},
	{id = "draw_slow"},
}, Targeting.MODES.LOW_HP)

addSpec("slow_black_ice", "module.slow_black_ice", "moduleDesc.slow_black_ice", {
	{id = "move_homing"},
	{id = "hit_damage"},
	{id = "apply_slow", data = {factor = 0.46, dur = 2.0}},
	{id = "aoe_damage", data = {radius = 38}},
	{id = "draw_slow"},
}, Targeting.MODES.PROGRESS)

addSpec("slow_absolute_zero", "module.slow_absolute_zero", "moduleDesc.slow_absolute_zero", {
	{id = "move_homing"},
	{id = "hit_damage"},
	{id = "apply_slow", data = {factor = 0.4, dur = 2.4}},
	{id = "frost_shatter", data = {count = 8, dmgMult = 0.55}},
	{id = "spawn_static_field", data = {radius = 48}},
	{id = "draw_slow"},
})

addSpec("slow_hailstorm", "module.slow_hailstorm", "moduleDesc.slow_hailstorm", {
	{id = "move_homing"},
	{id = "hit_damage"},
	{id = "apply_slow", data = {factor = 0.56, dur = 1.4}},
	{id = "split_on_hit", data = {count = 2}, noInherit = true},
	{id = "slow_pop"},
	{id = "draw_slow"},
})

addSpec("lancer_deadeye", "module.lancer_deadeye", "moduleDesc.lancer_deadeye", {
	{id = "move_homing"},
	{id = "hit_circle", data = {radius = 9}},
	{id = "hit_damage"},
	{id = "lancer_hit_fx"},
	{id = "draw_lancer"},
}, Targeting.MODES.LOW_HP)

addSpec("lancer_volley", "module.lancer_volley", "moduleDesc.lancer_volley", {
	{id = "move_homing"},
	{id = "hit_damage"},
	{id = "split_on_hit", data = {count = 2}, noInherit = true},
	{id = "lancer_hit_fx"},
	{id = "draw_lancer"},
})

addSpec("lancer_arc_lance", "module.lancer_arc_lance", "moduleDesc.lancer_arc_lance", {
	{id = "move_homing"},
	{id = "hit_damage"},
	{id = "hit_chain", data = {jumps = 2, radius = 54}},
	{id = "lancer_hit_fx"},
	{id = "draw_lancer"},
})

addSpec("poison_blight", "module.poison_blight", "moduleDesc.poison_blight", {
	{id = "move_homing"},
	{id = "hit_circle", data = {radius = 10}},
	{id = "hit_damage"},
	{id = "apply_poison", data = {dps = 6.2, dur = 2.2, maxStacks = 7}},
	{id = "draw_poison"},
})

addSpec("poison_plague", "module.poison_plague", "moduleDesc.poison_plague", {
	{id = "move_homing"},
	{id = "hit_circle", data = {radius = 12}},
	{id = "hit_damage"},
	{id = "apply_poison", data = {dps = 2.6, dur = 2.2, maxStacks = 22}},
	{id = "draw_poison"},
})

addSpec("poison_neurotoxin", "module.poison_neurotoxin", "moduleDesc.poison_neurotoxin", {
	{id = "move_homing"},
	{id = "hit_circle", data = {radius = 11}},
	{id = "hit_damage"},
	{id = "apply_poison", data = {dps = 4.2, dur = 2.1, maxStacks = 10}},
	{id = "draw_poison"},
})

addSpec("cannon_seige", "module.cannon_seige", "moduleDesc.cannon_seige", {
	{id = "move_homing"},
	{id = "hit_circle", data = {radius = 12}},
	{id = "aoe_damage", data = {radius = 58}},
	{id = "draw_cannon"},
}, Targeting.MODES.FARTHEST)

addSpec("cannon_cluster", "module.cannon_cluster", "moduleDesc.cannon_cluster", {
	{id = "move_homing"},
	{id = "hit_circle", data = {radius = 10}},
	{id = "aoe_damage", data = {radius = 38}},
	{id = "split_on_hit", data = {count = 2}, noInherit = true},
	{id = "draw_cannon"},
})

addSpec("cannon_aftershock", "module.cannon_aftershock", "moduleDesc.cannon_aftershock", {
	{id = "move_homing"},
	{id = "hit_circle", data = {radius = 11}},
	{id = "aoe_damage", data = {radius = 44}},
	{id = "spawn_static_field", data = {radius = 52}},
	{id = "draw_cannon"},
})

addSpec("shock_storm", "module.shock_storm", "moduleDesc.shock_storm", {
	{id = "emit_on_target"},
	{id = "hit_chain", data = {jumps = 6, radius = 62}},
	{id = "chain_zap_fx"},
})

addSpec("shock_conductor", "module.shock_conductor", "moduleDesc.shock_conductor", {
	{id = "emit_on_target"},
	{id = "hit_chain", data = {jumps = 3, radius = 60}},
	{id = "spawn_static_field", data = {radius = 56}},
	{id = "chain_zap_fx"},
})

addSpec("shock_overload", "module.shock_overload", "moduleDesc.shock_overload", {
	{id = "emit_on_target"},
	{id = "hit_chain", data = {jumps = 3, radius = 56}},
	{id = "spawn_orbital_on_hit", data = {count = 2}, noInherit = true},
	{id = "chain_zap_fx"},
})

addSpec("plasma_lance", "module.plasma_lance", "moduleDesc.plasma_lance", {
	{id = "move_linear", data = {dist = 340}},
	{id = "tick_damage", data = {radius = 13, rate = 0.09}},
	{id = "draw_plasma"},
})

addSpec("plasma_supernova", "module.plasma_supernova", "moduleDesc.plasma_supernova", {
	{id = "move_linear", data = {dist = 300}},
	{id = "tick_damage", data = {radius = 15, rate = 0.12}},
	{id = "aoe_damage", data = {radius = 36}},
	{id = "draw_plasma"},
})

addSpec("plasma_vortex", "module.plasma_vortex", "moduleDesc.plasma_vortex", {
	{id = "move_spiral", data = {amp = 12, freq = 7}},
	{id = "tick_damage", data = {radius = 12, rate = 0.1}},
	{id = "growing_projectile", data = {scale = 1.8}},
	{id = "draw_plasma"},
})

return ModuleDefs
