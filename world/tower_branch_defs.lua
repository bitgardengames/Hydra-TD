local TowerBranchDefs = {}

--[[

	Rules:

	Upgrades offered on the same tier should offer a real gameplay choice, there shouldn't be an obvious winner
	All choices should be able to work with eachother - All upgrades in the tower tower must work together
	Any combination of projectile movement/fx/damage style should all work together
	Keep descriptions clear and plain right now in terms of what they do, redo descriptions to avoid unclear phrasing

	Towers should all keep their core identity, and not give it to other towers
	example;
	Slow should be the only tower that slows enemies
	Poison should be the only tower that poisons enemies
	Shock should be the only tower with chaining/zap
	Lancer is all single target, no direct AOE or DOTS (explosives or poison for example), splitting or piercing are perfectly okay though
	Plasma is the lane crushing damage ticker
	Cannon should be the only one that performs radius AoE like a generic explosion


	Feel free to change targeting, projectile movement, projectile behavior, damage dealing, etc - But always keep towers to their core fantasy
--]]

local defs = {
	slow = {
		[2] = {"slow_glacier_core", "slow_permafrost"},
		[3] = {"slow_frost_nova", "slow_shatterburst"},
		[4] = {"slow_cold_snap", "slow_black_ice"},
		[5] = {"slow_absolute_zero", "slow_hailstorm"},
	},

	lancer = {
		[2] = {"lancer_deadeye", "lancer_volley"},
		[3] = {"pierce", "lancer_ricochet"},
		[4] = {"target_low_hp", "target_farthest_progress"},
		[5] = {"lancer_rail_lance", "lancer_arc_lance"},
	},

	poison = {
		[2] = {"poison_blight", "poison_plague"},
		[3] = {"poison_neurotoxin", "infect_spread"},
		[4] = {"tick_damage", "growing_projectile"},
		[5] = {"spawn_orbitals", "infect_spread"},
	},

	cannon = {
		[2] = {"cannon_seige", "cannon_cluster"},
		[3] = {"cannon_aftershock", "split_on_hit"},
		[4] = {"target_farthest_range", "growing_projectile"},
		[5] = {"chain_hit", "spawn_orbitals"},
	},

	shock = {
		[2] = {"shock_storm", "chain_fork"},
		[3] = {"chain_hit", "chain_fork"},
		[4] = {"shock_overload", "target_farthest_progress"},
		[5] = {"spawn_orbitals", "chain_hit"},
	},

	plasma = {
		[2] = {"plasma_lance", "plasma_supernova"},
		[3] = {"move_boomerang", "orbit_shot"},
		[4] = {"move_spiral", "plasma_vortex"},
		[5] = {"tick_damage", "growing_projectile"},
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
