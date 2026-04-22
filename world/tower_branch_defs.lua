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
		[2] = {"slow_glacier_core", "slow_frost_shards"},
		[3] = {"slow_shatter", "slow_snowball"},
		[4] = {"slow_lead_freeze", "slow_wide_chill"},
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
		[3] = {"poison_neurotoxin", "poison_venom_burst"},
		[4] = {"poison_cull_weak", "poison_corrupt_strong"},
		[5] = {"poison_hemotoxin", "poison_pandemic"},
	},

	cannon = {
		[2] = {"cannon_seige", "cannon_cluster"},
		[3] = {"cannon_aftershock", "split_on_hit"},
		[4] = {"target_farthest_range", "growing_projectile"},
		[5] = {"chain_hit", "spawn_orbitals"},
	},

	shock = {
		[2] = {"shock_storm_coil", "shock_overcharge"},
		[3] = {"shock_forked_arc", "shock_static_surge"},
		[4] = {"shock_crowd_search", "shock_boss_focus"},
		[5] = {"shock_thunderstorm", "shock_meltdown"},
	},

	plasma = {
		[2] = {"plasma_focused_core", "plasma_unstable_core"},
		[3] = {"plasma_boomerang_shot", "plasma_spiral_drive"},
		[4] = {"plasma_thermal_tracking", "plasma_lane_sweep"},
		[5] = {"plasma_supernova", "plasma_growing_mass"},
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
