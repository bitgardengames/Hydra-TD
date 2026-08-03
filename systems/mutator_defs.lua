-- Data only: runtime code consumes these fields through systems.mutators.
local Defs = {
	order = {
		"limited_arsenal", "tower_limit", "lean_economy", "no_resale",
		"swift_horde", "rapid_abilities", "empowered_affixes",
	},

	limited_arsenal = {
		nameKey = "mutators.limited_arsenal.name",
		descriptionKey = "mutators.limited_arsenal.description",
		restrictedTowerKinds = {"plasma", "poison"},
		compatibilityGroup = "tower_rules",
	},
	tower_limit = {
		nameKey = "mutators.tower_limit.name",
		descriptionKey = "mutators.tower_limit.description",
		towerCap = 12,
		compatibilityGroup = "tower_rules",
	},
	lean_economy = {
		nameKey = "mutators.lean_economy.name",
		descriptionKey = "mutators.lean_economy.description",
		startingCurrencyMultiplier = 0.7,
		compatibilityGroup = "economy_rules",
	},
	no_resale = {
		nameKey = "mutators.no_resale.name",
		descriptionKey = "mutators.no_resale.description",
		sellingDisabled = true,
		compatibilityGroup = "economy_rules",
	},
	swift_horde = {
		nameKey = "mutators.swift_horde.name",
		descriptionKey = "mutators.swift_horde.description",
		enemySpeedMultiplier = 1.2,
	},
	rapid_abilities = {
		nameKey = "mutators.rapid_abilities.name",
		descriptionKey = "mutators.rapid_abilities.description",
		abilityRechargeMultiplier = 0.65,
	},
	empowered_affixes = {
		nameKey = "mutators.empowered_affixes.name",
		descriptionKey = "mutators.empowered_affixes.description",
		affixPowerMultiplier = 1.5,
	},
}

return Defs
