local ModuleDefs = require("systems.module_defs")

local TalentDefs = {}

-- The run budget and thresholds are deliberately independent of save data.  Each
-- old branch choice remains the module id that implements its combat behaviour.
local branches = {
	slow = {{"slow_glacier_core", "slow_frost_shards"}, {"slow_snowball", "slow_frost_aura"}, {"slow_lead_freeze", "slow_wide_chill"}, {"slow_absolute_zero", "slow_glacial_barrage"}},
	lancer = {{"lancer_overdrive", "lancer_volley"}, {"pierce", "lancer_ricochet"}, {"lancer_sustained_barrage", "lancer_opening_strike"}, {"lancer_rail_lance", "lancer_focus_fire"}},
	poison = {{"poison_blight", "poison_plague"}, {"poison_neurotoxin", "poison_venom_burst"}, {"poison_cull_weak", "poison_corrupt_strong"}, {"poison_hemotoxin", "poison_pandemic"}},
	cannon = {{"cannon_siege_shells", "cannon_rapid_mortar"}, {"cannon_cluster_payload", "cannon_shockwave"}, {"cannon_long_fuse", "cannon_frontline_burst"}, {"cannon_mega_shell", "cannon_carpet_fire"}},
	shock = {{"shock_storm_coil", "shock_overcharge"}, {"shock_forked_arc", "shock_static_surge"}, {"shock_crowd_search", "shock_boss_focus"}, {"shock_thunderstorm", "shock_meltdown"}},
	plasma = {{"plasma_focused_core", "plasma_unstable_core"}, {"plasma_boomerang_shot", "plasma_spiral_drive"}, {"plasma_thermal_tracking", "plasma_lane_sweep"}, {"plasma_supernova", "plasma_growing_mass"}},
}

local byId, byTower = {}, {}
for towerKind, tiers in pairs(branches) do
	byTower[towerKind] = {}
	for tier, choices in ipairs(tiers) do
		for column, moduleId in ipairs(choices) do
			assert(ModuleDefs[moduleId], "missing talent module: " .. moduleId)
			local node = {
				id = moduleId, moduleId = moduleId, towerKind = towerKind,
				cost = 1, maxRank = 1, prerequisites = {},
				requiredPointsSpent = tier - 1,
				position = {x = column, y = tier},
				choiceGroup = towerKind .. "_tier_" .. tier,
			}
			byId[node.id] = node
			byTower[towerKind][#byTower[towerKind] + 1] = node
		end
	end
end

TalentDefs.byId = byId
TalentDefs.byTower = byTower
function TalentDefs.get(id) return byId[id] end
function TalentDefs.getForTower(kind) return byTower[kind] or {} end

return TalentDefs
