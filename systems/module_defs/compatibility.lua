-- Legacy IDs retained for save compatibility.
return function(catalog)
	local registry = catalog.registry
	local aliases = {
		slow_permafrost = "slow_frost_shards",
		slow_frost_nova = "slow_shatter",
		slow_shatterburst = "slow_snowball",
		slow_cold_snap = "slow_lead_freeze",
		slow_black_ice = "slow_wide_chill",
		lancer_arc_lance = "lancer_focus_fire",
		cannon_seige = "cannon_siege_shells",
		cannon_cluster = "cannon_cluster_payload",
		cannon_aftershock = "cannon_shockwave",
		shock_storm = "shock_storm_coil",
		shock_conductor = "shock_forked_arc",
		shock_overload = "shock_overcharge",
		plasma_lance = "plasma_focused_core",
		plasma_vortex = "plasma_spiral_drive",
	}

	for id, targetId in pairs(aliases) do
		catalog:add(id, {
			nameKey = "module." .. id,
			descKey = "moduleDesc." .. id,
			category = id ~= "lancer_arc_lance" and "special" or nil,
			legacyAliasFor = targetId,
			apply = function(ctx)
				registry[targetId].apply(ctx)
			end,
		})
	end
end
