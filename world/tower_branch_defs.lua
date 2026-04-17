local TowerBranchDefs = {}

local defs = {
	slow = {
		[2] = {"slow_glacier_core", "slow_permafrost"},
		[3] = {"apply_slow", "static_field"},
		[4] = {"aoe_damage", "chain_hit"},
		[5] = {"move_wave", "orbit_shot"},
	},
	lancer = {
		[2] = {"lancer_deadeye", "lancer_volley"},
		[3] = {"pierce", "chain_hit"},
		[4] = {"target_low_hp", "target_farthest_progress"},
		[5] = {"split_on_hit", "move_wave"},
	},
	poison = {
		[2] = {"poison_blight", "poison_plague"},
		[3] = {"apply_poison", "infect_spread"},
		[4] = {"apply_slow", "aoe_damage"},
		[5] = {"tick_damage", "spawn_orbitals"},
	},
	cannon = {
		[2] = {"cannon_seige", "cannon_cluster"},
		[3] = {"aoe_damage", "split_on_hit"},
		[4] = {"target_farthest_range", "static_field"},
		[5] = {"growing_projectile", "explode_on_hit"},
	},
	shock = {
		[2] = {"shock_storm", "shock_conductor"},
		[3] = {"chain_hit", "static_field"},
		[4] = {"target_farthest_progress", "target_low_hp"},
		[5] = {"spawn_orbitals", "apply_slow"},
	},
	plasma = {
		[2] = {"plasma_lance", "plasma_supernova"},
		[3] = {"tick_damage", "growing_projectile"},
		[4] = {"aoe_damage", "move_spiral"},
		[5] = {"beam_conversion", "explode_on_hit"},
	},
}

function TowerBranchDefs.getChoices(towerKind, level)
	local towerTree = defs[towerKind]
	if not towerTree then
		return nil
	end

	return towerTree[level]
end

function TowerBranchDefs.isValidChoice(towerKind, level, moduleId)
	local choices = TowerBranchDefs.getChoices(towerKind, level)
	if not choices then
		return false
	end

	for i = 1, #choices do
		if choices[i] == moduleId then
			return true
		end
	end

	return false
end

return TowerBranchDefs