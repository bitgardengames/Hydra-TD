local TowerBranchDefs = {}

local defs = {
	slow = {
		[2] = {"slow_glacier_core", "slow_permafrost"},
		[3] = {"slow_frost_nova", "slow_shatterburst"},
		[4] = {"slow_cold_snap", "slow_black_ice"},
		[5] = {"slow_absolute_zero", "slow_hailstorm"},
	},

	lancer = {
		[2] = {"lancer_deadeye", "split_on_hit"},
		[3] = {"pierce", "chain_hit"},
		[4] = {"target_low_hp", "target_farthest_progress"},
		[5] = {"split_on_hit", "beam_conversion"},
	},

	poison = {
		[2] = {"poison_blight", "poison_plague"},
		[3] = {"infect_spread", "apply_slow"},
		[4] = {"aoe_damage", "tick_damage"},
		[5] = {"spawn_orbitals", "growing_projectile"},
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
		[4] = {"fork_chain", "apply_slow"},
		[5] = {"spawn_orbitals", "tick_damage"},
	},

	plasma = {
		[2] = {"plasma_lance", "plasma_supernova"},
		[3] = {"beam_conversion", "growing_projectile"},
		[4] = {"move_spiral", "aoe_damage"},
		[5] = {"tick_damage", "explode_on_hit"},
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
