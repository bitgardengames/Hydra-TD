local ModuleDefs = {}
local Targeting = require("world.targeting")

--[[
	Module authoring hook contract (projectile behavior trigger model):
	- Behaviors may expose hook fns directly: on_shot, on_hit, on_kill, on_tick(dt), on_expire.
	- Legacy names are still honored by runtime compatibility mapping:
	  init -> on_shot, onHit -> on_hit, onKill -> on_kill, update -> on_tick, onExpire -> on_expire.
	- Optional per-behavior hook gating may be declared via behavior.hooks = {"on_hit", ...}.
	  If present, runtime executes only those hooks for that behavior.

	Hook payload contract:
	- on_shot(projectile, data)
	- on_tick(projectile, dt, data)
	- on_hit(projectile, enemy, data, ctx)
	- on_kill(projectile, enemy, data, ctx)
	- on_expire(projectile, data)

	Common ctx fields for hit/kill:
	- ctx.origin: "primary" | "secondary" (or custom origin strings)
	- ctx.hitX, ctx.hitY: optional impact override position
	- ctx.procFlags: table for per-hit-chain guardrails (set/get booleans)
	- ctx.procCooldowns: table namespace for per-target cooldown maps

	Guardrail expectation for chained effects:
	- Use projectile-scoped per-target cooldowns and/or ctx.procFlags to prevent
	  infinite loops in spawned/chained procs.
--]]

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
			data = { maxBonusStacks = 10, bonusPerStack = 0.09 }
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
			data = { radius = 64, spreadStacks = 2, spreadDur = 1.4 }
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
			data = { missingHpMult = 1.0 }
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
			data = { radius = 64, stackMult = 0.8, loop = true }
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
		local hasHitDetector = false
		for i = 1, #ctx.behaviors do
			local id = ctx.behaviors[i].id
			if id == "hit_circle" or id == "hit_line" or id == "instant_hit" or id == "emit_on_target" then
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
	{id = "apply_slow", data = {factor = 0.36, dur = 2.6}},
	{id = "shatter_bonus", data = {mult = 0.45}},
	{id = "draw_slow"},
})

addSpec("slow_frost_shards", "module.slow_frost_shards", "moduleDesc.slow_frost_shards", {
	{id = "move_homing"},
	{id = "hit_damage"},
	{id = "apply_slow", data = {factor = 0.65, dur = 1.1}},
	{id = "split_on_hit", data = {count = 1, dmgMult = 0.75}, noInherit = true},
	{id = "draw_slow"},
})

addSpec("slow_shatter", "module.slow_shatter", "moduleDesc.slow_shatter", {
	{id = "move_homing"},
	{id = "hit_damage"},
	{id = "apply_slow", data = {factor = 0.52, dur = 1.5}},
	{id = "shatter_bonus", data = {mult = 0.62}},
	{id = "draw_slow"},
})

addSpec("slow_snowball", "module.slow_snowball", "moduleDesc.slow_snowball", {
	{id = "move_homing"},
	{id = "pierce"},
	{id = "hit_damage"},
	{id = "apply_slow", data = {factor = 0.58, dur = 1.35}},
	{id = "snowball_ramp", data = {ramp = 0.24, cap = 3.4}},
	{id = "draw_slow"},
})

addSpec("slow_lead_freeze", "module.slow_lead_freeze", "moduleDesc.slow_lead_freeze", {
	{id = "move_homing"},
	{id = "hit_damage"},
	{id = "apply_slow", data = {factor = 0.46, dur = 1.9}},
	{id = "shatter_bonus", data = {mult = 1.0}},
	{id = "draw_slow"},
})

addSpec("slow_wide_chill", "module.slow_wide_chill", "moduleDesc.slow_wide_chill", {
	{id = "move_homing"},
	{id = "hit_damage"},
	{id = "apply_slow", data = {factor = 0.58, dur = 1.35}},
	{id = "aoe_damage", data = {radius = 42}},
	{id = "draw_slow"},
})

addSpec("slow_absolute_zero", "module.slow_absolute_zero", "moduleDesc.slow_absolute_zero", {
	{id = "move_homing"},
	{id = "hit_damage"},
	{id = "apply_slow", data = {factor = 0.22, dur = 1.1}},
	{id = "shatter_bonus", data = {mult = 1.1}},
	{id = "pierce", data = {maxHits = 2}},
	{id = "draw_slow"},
})

addSpec("slow_hailstorm", "module.slow_hailstorm", "moduleDesc.slow_hailstorm", {
	{id = "move_homing"},
	{id = "hit_damage"},
	{id = "apply_slow", data = {factor = 0.54, dur = 1.4}},
	{id = "split_on_hit", data = {count = 2, spread = 0.42, dmgMult = 0.5}, noInherit = true},
	{id = "draw_slow"},
})

-- Legacy slow branch ids (save compatibility)
add("slow_permafrost", {
	nameKey = "module.slow_permafrost",
	descKey = "moduleDesc.slow_permafrost",
	category = "special",
	apply = function(ctx)
		ModuleDefs.slow_frost_shards.apply(ctx)
	end
})

add("slow_frost_nova", {
	nameKey = "module.slow_frost_nova",
	descKey = "moduleDesc.slow_frost_nova",
	category = "special",
	apply = function(ctx)
		ModuleDefs.slow_shatter.apply(ctx)
	end
})

add("slow_shatterburst", {
	nameKey = "module.slow_shatterburst",
	descKey = "moduleDesc.slow_shatterburst",
	category = "special",
	apply = function(ctx)
		ModuleDefs.slow_snowball.apply(ctx)
	end
})

add("slow_cold_snap", {
	nameKey = "module.slow_cold_snap",
	descKey = "moduleDesc.slow_cold_snap",
	category = "special",
	apply = function(ctx)
		ModuleDefs.slow_lead_freeze.apply(ctx)
	end
})

add("slow_black_ice", {
	nameKey = "module.slow_black_ice",
	descKey = "moduleDesc.slow_black_ice",
	category = "special",
	apply = function(ctx)
		ModuleDefs.slow_wide_chill.apply(ctx)
	end
})

addSpec("lancer_overdrive", "module.lancer_overdrive", "moduleDesc.lancer_overdrive", {
	{id = "move_homing"},
	{id = "hit_circle", data = {radius = 9}},
	{id = "hit_damage"},
	{id = "lancer_overdrive", data = {triggerEvery = 4, bonusDmgMult = 1.4}},
	{id = "lancer_hit_fx"},
	{id = "draw_lancer"},
})

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
	{id = "hit_chain", data = {jumps = 1, radius = 52}},
	{id = "lancer_hit_fx"},
	{id = "draw_lancer"},
})

addSpec("lancer_focus_fire", "module.lancer_focus_fire", "moduleDesc.lancer_focus_fire", {
	{id = "move_homing"},
	{id = "hit_circle", data = {radius = 9}},
	{id = "hit_damage"},
	{id = "lancer_focus_fire", data = {window = 1.1, perStackMult = 0.18, maxStacks = 4}},
	{id = "lancer_hit_fx"},
	{id = "draw_lancer"},
})

addSpec("lancer_opening_strike", "module.lancer_opening_strike", "moduleDesc.lancer_opening_strike", {
	{id = "move_homing"},
	{id = "hit_circle", data = {radius = 9}},
	{id = "hit_damage"},
	{id = "lancer_opening_strike", data = {triggerHpFrac = 0.8, bonusDmgMult = 0.65}},
	{id = "lancer_hit_fx"},
	{id = "draw_lancer"},
})

addSpec("lancer_sustained_barrage", "module.lancer_sustained_barrage", "moduleDesc.lancer_sustained_barrage", {
	{id = "move_homing"},
	{id = "hit_circle", data = {radius = 9}},
	{id = "hit_damage"},
	{id = "lancer_sustained_barrage", data = {cycleShots = 6, burstShots = 3, bonusDmgMult = 0.45}},
	{id = "lancer_hit_fx"},
	{id = "draw_lancer"},
})

addSpec("lancer_rail_lance", "module.lancer_rail_lance", "moduleDesc.lancer_rail_lance", {
	{id = "move_linear"},
	{id = "hit_circle", data = {radius = 9}},
	{id = "hit_damage"},
	{id = "pierce", data = {maxHits = 5}},
	{id = "lancer_rail_momentum", data = {perHitMult = 0.22, maxStacks = 4}},
	{id = "lancer_hit_fx"},
	{id = "draw_rail_lance"},
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
	{id = "apply_poison", data = {dps = 2.8, dur = 2.2, maxStacks = 16}},
	{id = "draw_poison"},
})

addSpec("poison_neurotoxin", "module.poison_neurotoxin", "moduleDesc.poison_neurotoxin", {
	{id = "move_homing"},
	{id = "hit_circle", data = {radius = 11}},
	{id = "hit_damage"},
	{id = "apply_poison", data = {dps = 3.8, dur = 2.2, maxStacks = 11}},
	{id = "poison_neurotoxin", data = {bonusStacks = 2}},
	{id = "draw_poison"},
})

addSpec("cannon_siege_shells", "module.cannon_siege_shells", "moduleDesc.cannon_siege_shells", {
	{id = "move_homing"},
	{id = "hit_circle", data = {radius = 13}},
	{id = "aoe_damage", data = {radius = 70, falloff = 0.6}},
	{id = "cannon_damage_scale", data = {mult = 1.45}},
	{id = "draw_cannon"},
})

addSpec("cannon_rapid_mortar", "module.cannon_rapid_mortar", "moduleDesc.cannon_rapid_mortar", {
	{id = "move_homing"},
	{id = "hit_circle", data = {radius = 9}},
	{id = "aoe_damage", data = {radius = 40, falloff = 0.84}},
	{id = "cannon_damage_scale", data = {mult = 0.72}},
	{id = "draw_cannon"},
})

addSpec("cannon_cluster_payload", "module.cannon_cluster_payload", "moduleDesc.cannon_cluster_payload", {
	{id = "move_homing"},
	{id = "hit_circle", data = {radius = 10}},
	{id = "aoe_damage", data = {radius = 40}},
	{id = "split_on_hit", data = {count = 3, spread = 0.5, dmgMult = 0.5}, noInherit = true},
	{id = "draw_cannon"},
})

addSpec("cannon_shockwave", "module.cannon_shockwave", "moduleDesc.cannon_shockwave", {
	{id = "move_homing"},
	{id = "hit_circle", data = {radius = 11}},
	{id = "aoe_damage", data = {radius = 40, falloff = 0.72}},
	{id = "cannon_damage_scale", data = {mult = 0.60}},
	{id = "cannon_shockwave", data = {radius = 54, damageMult = 0.62, minFalloff = 0.34, impulse = 4.8}},
	{id = "draw_cannon"},
})

addSpec("cannon_long_fuse", "module.cannon_long_fuse", "moduleDesc.cannon_long_fuse", {
	{id = "move_homing"},
	{id = "hit_circle", data = {radius = 13}},
	{id = "aoe_damage", data = {radius = 54, falloff = 0.66}},
	{id = "cannon_damage_scale", data = {mult = 1.0}},
	{id = "cannon_long_fuse", data = {delay = 0.5, radius = 88, falloff = 0.5, damageMult = 1.6, ringRadius = 56, ringWidth = 24, ringDamageMult = 1.15}},
	{id = "draw_cannon"},
})

addSpec("cannon_frontline_burst", "module.cannon_frontline_burst", "moduleDesc.cannon_frontline_burst", {
	{id = "move_homing"},
	{id = "hit_circle", data = {radius = 10}},
	{id = "aoe_damage", data = {radius = 36, falloff = 0.72}},
	{id = "split_on_hit", data = {count = 3, spread = 0.36, dmgMult = 0.46}, noInherit = true},
	{id = "draw_cannon"},
})

addSpec("cannon_mega_shell", "module.cannon_mega_shell", "moduleDesc.cannon_mega_shell", {
	{id = "move_homing"},
	{id = "hit_circle", data = {radius = 14}},
	{id = "aoe_damage", data = {radius = 78}},
	{id = "cannon_damage_scale", data = {mult = 2.05}},
	{id = "draw_cannon"},
})

addSpec("cannon_carpet_fire", "module.cannon_carpet_fire", "moduleDesc.cannon_carpet_fire", {
	{id = "move_homing"},
	{id = "hit_circle", data = {radius = 11}},
	{id = "aoe_damage", data = {radius = 48}},
	{id = "cannon_damage_scale", data = {mult = 0.82}},
	{id = "cannon_carpet_fire", data = {delayA = 0.07, delayB = 0.14, spread = 0.14}},
	{id = "draw_cannon"},
})

-- Legacy cannon branch ids (save compatibility)
add("cannon_seige", {
	nameKey = "module.cannon_seige",
	descKey = "moduleDesc.cannon_seige",
	category = "special",
	targetMode = Targeting.MODES.FARTHEST,
	apply = function(ctx)
		ModuleDefs.cannon_siege_shells.apply(ctx)
	end
})

add("cannon_cluster", {
	nameKey = "module.cannon_cluster",
	descKey = "moduleDesc.cannon_cluster",
	category = "special",
	apply = function(ctx)
		ModuleDefs.cannon_cluster_payload.apply(ctx)
	end
})

add("cannon_aftershock", {
	nameKey = "module.cannon_aftershock",
	descKey = "moduleDesc.cannon_aftershock",
	category = "special",
	apply = function(ctx)
		ModuleDefs.cannon_shockwave.apply(ctx)
	end
})

addSpec("shock_storm_coil", "module.shock_storm_coil", "moduleDesc.shock_storm_coil", {
	{id = "emit_on_target"},
	{id = "hit_chain", data = {jumps = 7, radius = 62}},
	{id = "chain_zap_fx"},
})

addSpec("shock_overcharge", "module.shock_overcharge", "moduleDesc.shock_overcharge", {
	{id = "emit_on_target"},
	{id = "hit_chain", data = {jumps = 2, radius = 54, falloff = 0.92}},
	{id = "chain_zap_fx"},
})

addSpec("shock_forked_arc", "module.shock_forked_arc", "moduleDesc.shock_forked_arc", {
	{id = "emit_on_target"},
	{id = "hit_chain", data = {jumps = 4, radius = 56}},
	{id = "fork_chain", data = {radius = 54, dmgMult = 0.35, forksPerLink = 2}},
	{id = "chain_zap_fx"},
})

addSpec("shock_static_surge", "module.shock_static_surge", "moduleDesc.shock_static_surge", {
	{id = "emit_on_target"},
	{id = "hit_chain", data = {jumps = 4, radius = 56}},
	{id = "chain_static_surge", data = {bonusPerStack = 0.2, maxStacks = 6}},
	{id = "chain_zap_fx"},
})

addSpec("shock_crowd_search", "module.shock_crowd_search", "moduleDesc.shock_crowd_search", {
	{id = "emit_on_target"},
	{id = "hit_chain", data = {jumps = 7, radius = 64}},
	{id = "fork_chain", data = {radius = 54, dmgMult = 0.30, forksPerLink = 2}},
	{id = "chain_zap_fx"},
})

addSpec("shock_boss_focus", "module.shock_boss_focus", "moduleDesc.shock_boss_focus", {
	{id = "emit_on_target"},
	{id = "hit_chain", data = {jumps = 3, radius = 56, falloff = 0.94}},
	{id = "chain_static_surge", data = {bonusPerStack = 0.28, maxStacks = 8}},
	{id = "chain_endpoint_burst", data = {radius = 28, dmgMult = 0.35}},
	{id = "chain_zap_fx"},
})

addSpec("shock_thunderstorm", "module.shock_thunderstorm", "moduleDesc.shock_thunderstorm", {
	{id = "emit_on_target"},
	{id = "hit_chain", data = {jumps = 10, radius = 68, falloff = 0.9}},
	{id = "fork_chain", data = {radius = 50, dmgMult = 0.22, forksPerLink = 1}},
	{id = "chain_zap_fx"},
})

addSpec("shock_meltdown", "module.shock_meltdown", "moduleDesc.shock_meltdown", {
	{id = "emit_on_target"},
	{id = "hit_chain", data = {jumps = 5, radius = 58}},
	{id = "chain_endpoint_burst", data = {radius = 32, dmgMult = 0.48}},
	{id = "chain_zap_fx"},
})

-- Legacy shock branch ids (save compatibility)
add("shock_storm", {
	nameKey = "module.shock_storm",
	descKey = "moduleDesc.shock_storm",
	category = "special",
	apply = function(ctx)
		ModuleDefs.shock_storm_coil.apply(ctx)
	end
})

add("shock_conductor", {
	nameKey = "module.shock_conductor",
	descKey = "moduleDesc.shock_conductor",
	category = "special",
	apply = function(ctx)
		ModuleDefs.shock_forked_arc.apply(ctx)
	end
})

add("shock_overload", {
	nameKey = "module.shock_overload",
	descKey = "moduleDesc.shock_overload",
	category = "special",
	apply = function(ctx)
		ModuleDefs.shock_overcharge.apply(ctx)
	end
})

addSpec("plasma_focused_core", "module.plasma_focused_core", "moduleDesc.plasma_focused_core", {
	{id = "move_linear", data = {dist = 330}},
	{id = "tick_damage", data = {radius = 9, rate = 0.08, impulse = 0.45}},
	{id = "projectile_radius", data = {radius = 3.8}},
	{id = "draw_plasma"},
})

addSpec("plasma_unstable_core", "module.plasma_unstable_core", "moduleDesc.plasma_unstable_core", {
	{id = "move_linear", data = {dist = 300}},
	{id = "tick_damage", data = {radius = 16, rate = 0.14, impulse = 0.45}},
	{id = "projectile_radius", data = {radius = 5.4}},
	{id = "draw_plasma"},
})

addSpec("plasma_boomerang_shot", "module.plasma_boomerang_shot", "moduleDesc.plasma_boomerang_shot", {
	{id = "move_boomerang", data = {dist = 190}},
	{id = "tick_damage", data = {radius = 12, rate = 0.11, impulse = 0.45}},
	{id = "draw_plasma"},
})

addSpec("plasma_spiral_drive", "module.plasma_spiral_drive", "moduleDesc.plasma_spiral_drive", {
	{id = "move_spiral", data = {amp = 15, freq = 7.5}},
	{id = "tick_damage", data = {radius = 12, rate = 0.12, impulse = 0.45}},
	{id = "draw_plasma"},
})

addSpec("plasma_thermal_tracking", "module.plasma_thermal_tracking", "moduleDesc.plasma_thermal_tracking", {
	{id = "move_linear", data = {dist = 360}},
	{id = "tick_damage", data = {radius = 10, rate = 0.08, impulse = 0.5}},
	{id = "projectile_radius", data = {radius = 4.2}},
	{id = "draw_plasma"},
})

addSpec("plasma_lane_sweep", "module.plasma_lane_sweep", "moduleDesc.plasma_lane_sweep", {
	{id = "move_linear", data = {dist = 290}},
	{id = "tick_damage", data = {radius = 17, rate = 0.14, impulse = 0.4}},
	{id = "projectile_radius", data = {radius = 6.2}},
	{id = "draw_plasma"},
})

addSpec("plasma_supernova", "module.plasma_supernova", "moduleDesc.plasma_supernova", {
	{id = "move_linear", data = {dist = 300}},
	{id = "tick_damage", data = {radius = 13, rate = 0.12, impulse = 0.45}},
	{id = "plasma_supernova_burst", data = {radius = 42, dmgMult = 2.2, triggerAt = 0.2}},
	{id = "draw_plasma"},
})

addSpec("plasma_growing_mass", "module.plasma_growing_mass", "moduleDesc.plasma_growing_mass", {
	{id = "move_linear", data = {dist = 340}},
	{id = "tick_damage", data = {radius = 12, rate = 0.095, impulse = 0.45}},
	{id = "growing_projectile", data = {scale = 2.75}},
	{id = "draw_plasma"},
})

-- Legacy plasma branch ids (save compatibility)
add("plasma_lance", {
	nameKey = "module.plasma_lance",
	descKey = "moduleDesc.plasma_lance",
	category = "special",
	apply = function(ctx)
		ModuleDefs.plasma_focused_core.apply(ctx)
	end
})

add("plasma_vortex", {
	nameKey = "module.plasma_vortex",
	descKey = "moduleDesc.plasma_vortex",
	category = "special",
	apply = function(ctx)
		ModuleDefs.plasma_spiral_drive.apply(ctx)
	end
})

return ModuleDefs
