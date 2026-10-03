return function(catalog)
	local addSpec = function(...) catalog:addSpecialization(...) end

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
addSpec("slow_frost_aura", "module.slow_frost_aura", "moduleDesc.slow_frost_aura", {
	{id = "move_homing"},
	{id = "hit_damage", data = {mult = 0.88}},
	{id = "apply_slow", data = {factor = 0.4, dur = 1.0}},
	{id = "slow_aura", data = {factor = 0.2, dur = 0.7, radius = 54, tick = 0.3, fxScale = 0.62}, noInherit = true},
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
	{id = "shatter_bonus", data = {mult = 0.88}},
	{id = "pierce", data = {maxHits = 1}},
	{id = "draw_slow"},
})
addSpec("slow_hailstorm", "module.slow_hailstorm", "moduleDesc.slow_hailstorm", {
	{id = "move_homing"},
	{id = "hit_damage"},
	{id = "apply_slow", data = {factor = 0.54, dur = 1.4}},
	{id = "split_on_hit", data = {count = 3, spread = 0.26, dmgMult = 0.62}, noInherit = true},
	{id = "draw_slow"},
})
addSpec("slow_glacial_barrage", "module.slow_glacial_barrage", "moduleDesc.slow_glacial_barrage", {
	{id = "move_homing"},
	{id = "hit_damage", data = {mult = 0.85}},
	{id = "slow_burst_cleave", data = {cooldown = 1.35, count = 5, dmgMult = 0.31, ringOffset = 14, travelDistance = 700}, noInherit = true},
	{id = "apply_slow", data = {factor = 0.56, dur = 1.45}},
	{id = "draw_slow"},
})
addSpec("lancer_overdrive", "module.lancer_overdrive", "moduleDesc.lancer_overdrive", {
	{id = "move_homing"},
	{id = "hit_circle", data = {radius = 9}},
	{id = "hit_damage"},
	{id = "lancer_overdrive", data = {triggerEvery = 5, bonusDmgMult = 1.2}},
	{id = "lancer_hit_fx"},
	{id = "draw_lancer"},
})
addSpec("lancer_volley", "module.lancer_volley", "moduleDesc.lancer_volley", {
	{id = "move_homing"},
	{id = "hit_damage"},
	{id = "split_on_hit", data = {count = 2, spread = 0.28, dmgMult = 0.44}, noInherit = true},
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
	{id = "lancer_opening_strike", data = {triggerHpFrac = 0.8, bonusDmgMult = 0.55}},
	{id = "lancer_hit_fx"},
	{id = "draw_lancer"},
})
addSpec("lancer_sustained_barrage", "module.lancer_sustained_barrage", "moduleDesc.lancer_sustained_barrage", {
	{id = "move_homing"},
	{id = "hit_circle", data = {radius = 9}},
	{id = "hit_damage"},
	{id = "lancer_sustained_barrage", data = {cycleShots = 6, burstShots = 3, bonusDmgMult = 0.36}},
	{id = "lancer_hit_fx"},
	{id = "draw_lancer"},
})
addSpec("lancer_rail_lance", "module.lancer_rail_lance", "moduleDesc.lancer_rail_lance", {
	{id = "move_linear"},
	{id = "hit_circle", data = {radius = 9}},
	{id = "hit_damage"},
	{id = "pierce", data = {maxHits = 5}},
	{id = "lancer_rail_momentum", data = {perHitMult = 0.18, maxStacks = 4}},
	{id = "lancer_hit_fx"},
	{id = "draw_rail_lance"},
})
addSpec("poison_blight", "module.poison_blight", "moduleDesc.poison_blight", {
	{id = "move_homing"},
	{id = "hit_circle", data = {radius = 10}},
	{id = "hit_damage"},
	{id = "apply_poison", data = {dps = 1.9, dur = 2.4, maxStacks = 7, rampPerTick = 0.32, rampMax = 3.0}},
	{id = "draw_poison"},
})
addSpec("poison_plague", "module.poison_plague", "moduleDesc.poison_plague", {
	{id = "move_homing"},
	{id = "hit_circle", data = {radius = 12}},
	{id = "hit_damage"},
	{id = "apply_poison", data = {dps = 2.1, dur = 5.0, maxStacks = 10, rampPerTick = 0.12, rampMax = 1.7}},
	{id = "draw_poison"},
})
addSpec("poison_neurotoxin", "module.poison_neurotoxin", "moduleDesc.poison_neurotoxin", {
	{id = "move_homing"},
	{id = "hit_circle", data = {radius = 11}},
	{id = "hit_damage"},
	{id = "apply_poison", data = {dps = 3.8, dur = 2.2, maxStacks = 11}},
	{id = "poison_neurotoxin", data = {bonusStacks = 1, branchMaxStacks = 8, diminishAt = 6, highStackBonusMult = 0.5}},
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
	{id = "cannon_damage_scale", data = {mult = 0.78}},
	{id = "draw_cannon"},
}, {fireRateMult = 1.35})
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
	{id = "cannon_damage_scale", data = {mult = 0.66}},
	{id = "cannon_shockwave", data = {radius = 54, damageMult = 0.52, minFalloff = 0.34, impulse = 4.8}},
	{id = "draw_cannon"},
})
addSpec("cannon_long_fuse", "module.cannon_long_fuse", "moduleDesc.cannon_long_fuse", {
	{id = "move_homing"},
	{id = "hit_circle", data = {radius = 13}},
	{id = "aoe_damage", data = {radius = 54, falloff = 0.66}},
	{id = "cannon_damage_scale", data = {mult = 1.0}},
	{id = "cannon_long_fuse", data = {delay = 0.62, radius = 70, falloff = 0.54, damageMult = 0.72, ringRadius = 48, ringWidth = 18, ringDamageMult = 0.32, ringOverlapCapMult = 0.33, repeatHitMult = 0.5}},
	{id = "draw_cannon"},
})
addSpec("cannon_frontline_burst", "module.cannon_frontline_burst", "moduleDesc.cannon_frontline_burst", {
	{id = "move_homing"},
	{id = "hit_circle", data = {radius = 10}},
	{id = "aoe_damage", data = {radius = 36, falloff = 0.72}},
	{id = "split_on_hit", data = {count = 3, spread = 0.36, dmgMult = 0.5}, noInherit = true},
	{id = "draw_cannon"},
})
addSpec("cannon_mega_shell", "module.cannon_mega_shell", "moduleDesc.cannon_mega_shell", {
	{id = "move_homing"},
	{id = "hit_circle", data = {radius = 14}},
	{id = "aoe_damage", data = {radius = 78}},
	{id = "cannon_damage_scale", data = {mult = 2.05}},
	{id = "projectile_radius", data = {radius = 5.2}},
	{id = "projectile_visual_scale", data = {scale = 1.2}},
	{id = "draw_cannon"},
})
addSpec("cannon_carpet_fire", "module.cannon_carpet_fire", "moduleDesc.cannon_carpet_fire", {
	{id = "move_homing"},
	{id = "hit_circle", data = {radius = 11}},
	{id = "aoe_damage", data = {radius = 48}},
	{id = "cannon_damage_scale", data = {mult = 0.88}},
	{id = "cannon_carpet_fire", data = {delayA = 0.07, delayB = 0.14, spread = 0.14}},
	{id = "draw_cannon"},
})
addSpec("shock_storm_coil", "module.shock_storm_coil", "moduleDesc.shock_storm_coil", {
	{id = "emit_on_target"},
	{id = "hit_chain", data = {jumps = 5, radius = 62}},
	{id = "chain_zap_fx"},
})
addSpec("shock_overcharge", "module.shock_overcharge", "moduleDesc.shock_overcharge", {
	{id = "emit_on_target"},
	{id = "hit_chain", data = {jumps = 3, radius = 56, falloff = 0.94}},
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
	{id = "chain_static_surge", data = {bonusPerStack = 0.12, maxStacks = 6, fullStacks = 3, postFullScale = 0.45}},
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
	{id = "chain_static_surge", data = {bonusPerStack = 0.15, maxStacks = 7, fullStacks = 2, postFullScale = 0.6}},
	{id = "chain_endpoint_burst", data = {radius = 28, dmgMult = 0.35}},
	{id = "chain_zap_fx"},
})
addSpec("shock_thunderstorm", "module.shock_thunderstorm", "moduleDesc.shock_thunderstorm", {
	{id = "emit_on_target"},
	{id = "hit_chain", data = {jumps = 8, radius = 68, falloff = 0.86}},
	{id = "fork_chain", data = {radius = 50, dmgMult = 0.16, forksPerLink = 1}},
	{id = "chain_zap_fx"},
})
addSpec("shock_meltdown", "module.shock_meltdown", "moduleDesc.shock_meltdown", {
	{id = "emit_on_target"},
	{id = "hit_chain", data = {jumps = 4, radius = 54}},
	{id = "chain_endpoint_burst", data = {radius = 36, dmgMult = 0.36}},
	{id = "chain_zap_fx"},
})
addSpec("plasma_focused_core", "module.plasma_focused_core", "moduleDesc.plasma_focused_core", {
	{id = "move_linear", data = {dist = 330}},
	{id = "tick_damage", data = {radius = 9, rate = 0.08, impulse = 0.45}},
	{id = "projectile_radius", data = {radius = 3.8}},
	{id = "projectile_visual_scale", data = {scale = 0.9}},
	{id = "draw_plasma"},
})
addSpec("plasma_unstable_core", "module.plasma_unstable_core", "moduleDesc.plasma_unstable_core", {
	{id = "move_linear", data = {dist = 300}},
	{id = "tick_damage", data = {radius = 16, rate = 0.13, impulse = 0.45}},
	{id = "projectile_radius", data = {radius = 5.4}},
	{id = "projectile_visual_scale", data = {scale = 1.1}},
	{id = "draw_plasma"},
})
addSpec("plasma_boomerang_shot", "module.plasma_boomerang_shot", "moduleDesc.plasma_boomerang_shot", {
	{id = "move_boomerang", data = {dist = 190}},
	{id = "tick_damage", data = {radius = 12, rate = 0.11, impulse = 0.45}},
	{id = "draw_plasma"},
})
addSpec("plasma_spiral_drive", "module.plasma_spiral_drive", "moduleDesc.plasma_spiral_drive", {
	{id = "move_spiral", data = {amp = 15, freq = 7.5}},
	{id = "tick_damage", data = {radius = 12, rate = 0.11, impulse = 0.45}},
	{id = "draw_plasma"},
})
addSpec("plasma_thermal_tracking", "module.plasma_thermal_tracking", "moduleDesc.plasma_thermal_tracking", {
	{id = "move_linear", data = {dist = 330}},
	{id = "tick_damage", data = {radius = 10, rate = 0.08, impulse = 0.5}},
	{id = "projectile_radius", data = {radius = 4.2}},
	{id = "draw_plasma"},
})
addSpec("plasma_lane_sweep", "module.plasma_lane_sweep", "moduleDesc.plasma_lane_sweep", {
	{id = "move_linear", data = {dist = 300}},
	{id = "tick_damage", data = {radius = 17, rate = 0.125, impulse = 0.4}},
	{id = "projectile_radius", data = {radius = 6.2}},
	{id = "draw_plasma"},
})
addSpec("plasma_supernova", "module.plasma_supernova", "moduleDesc.plasma_supernova", {
	{id = "move_linear", data = {dist = 300}},
	{id = "tick_damage", data = {radius = 13, rate = 0.11, impulse = 0.45}},
	{id = "plasma_supernova_burst", data = {radius = 42, dmgMult = 1.85, triggerAt = 0.2}},
	{id = "draw_plasma"},
})
addSpec("plasma_growing_mass", "module.plasma_growing_mass", "moduleDesc.plasma_growing_mass", {
	{id = "move_linear", data = {dist = 300}},
	{id = "tick_damage", data = {radius = 12, rate = 0.1, impulse = 0.45}},
	{id = "growing_projectile", data = {scale = 2.55}},
	{id = "draw_plasma"},
})
end
