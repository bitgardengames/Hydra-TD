local TowerDefs = require("world.tower_defs")
local ModuleDefs = require("systems.module_defs")

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
		[3] = {"slow_snowball", "slow_frost_aura"},
		[4] = {"slow_lead_freeze", "slow_wide_chill"},
		[5] = {"slow_absolute_zero", "slow_glacial_barrage"},
	},

	lancer = {
		[2] = {"lancer_overdrive", "lancer_volley"},
		[3] = {"pierce", "lancer_ricochet"},
		[4] = {"lancer_sustained_barrage", "lancer_opening_strike"},
		[5] = {"lancer_rail_lance", "lancer_focus_fire"},
	},

	poison = {
		[2] = {"poison_blight", "poison_plague"},
		[3] = {"poison_neurotoxin", "poison_venom_burst"},
		[4] = {"poison_cull_weak", "poison_corrupt_strong"},
		[5] = {"poison_hemotoxin", "poison_pandemic"},
	},

	cannon = {
		[2] = {"cannon_siege_shells", "cannon_rapid_mortar"},
		[3] = {"cannon_cluster_payload", "cannon_shockwave"},
		[4] = {"cannon_long_fuse", "cannon_frontline_burst"},
		[5] = {"cannon_mega_shell", "cannon_carpet_fire"},
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

local function flattenChoices(towerTree)
	local list = {}

	for level = 2, 5 do
		local choices = towerTree[level]
		if choices then
			for i = 1, #choices do
				list[#list + 1] = choices[i]
			end
		end
	end

	return list
end

local function validateAndSync()
	local missingRefs = {}

	for towerKind, towerTree in pairs(defs) do
		local towerDef = TowerDefs[towerKind]
		assert(towerDef, ("[TowerBranchDefs] missing tower def for '%s'"):format(towerKind))

		local flattened = flattenChoices(towerTree)
		towerDef.upgradeChoices = flattened

		for i = 1, #flattened do
			local moduleId = flattened[i]
			if not ModuleDefs[moduleId] then
				missingRefs[#missingRefs + 1] = ("%s (tower=%s)"):format(moduleId, towerKind)
			end
		end

		if towerDef.upgradeChoices then
			local isBranchModule = {}
			for i = 1, #flattened do
				isBranchModule[flattened[i]] = true
			end

			for i = 1, #towerDef.upgradeChoices do
				local moduleId = towerDef.upgradeChoices[i]
				assert(isBranchModule[moduleId],
					("[TowerBranchDefs] orphan module '%s' in %s.upgradeChoices"):format(moduleId, towerKind))
			end
		end
	end

	assert(#missingRefs == 0,
		"[TowerBranchDefs] missing module defs for branch choices: " .. table.concat(missingRefs, ", "))
end

validateAndSync()

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
