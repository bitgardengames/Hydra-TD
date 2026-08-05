-- Run abilities are deliberately plain data so new abilities can be added without
-- changing the selection, targeting, or cooldown UI.
local AbilityDefs = {
	meteor = {
		id = "meteor",
		nameKey = "ability.meteor.name",
		descKey = "ability.meteor.desc",
		cooldown = 35,
		targeting = "point",
		effect = {kind = "damage_area", radius = 82, damage = 85},
		upgradedEffect = {kind = "damage_area", radius = 96, damage = 115},
	},
	frost_nova = {
		id = "frost_nova",
		nameKey = "ability.frostNova.name",
		descKey = "ability.frostNova.desc",
		cooldown = 28,
		targeting = "point",
		effect = {kind = "slow_area", radius = 105, factor = 0.35, duration = 5},
		upgradedEffect = {kind = "slow_area", radius = 120, factor = 0.28, duration = 6.5},
	},
}

AbilityDefs.order = {"meteor", "frost_nova"}

return AbilityDefs
