local Constants = require("core.constants")
local Theme = require("core.theme")

return {
	slow = {
		nameKey = "tower.slow",
		descKey = "towerDesc.slow",
		cost = 50,
		range = 3.8 * Constants.TILE,
		fireRate = 1.4,
		damage = 6,
		recoilStrength = Constants.TILE * 0.06,
		recoilDecay = 10,
		projSpeed = 370,
		turnSpeed = 10,
		color = Theme.tower.slow,
		canRotate = true,
		upgrade = {
			dmgMult = 2.2,
			rangeAdd = 0.1 * Constants.TILE,
			fireMult = 1.0, -- 1.04
			slowDurAdd = 0.35,
		},
		upgradeChoices = {
			"slow_glacier_core",
			"slow_frost_shards",
			"slow_shatter",
		},
		behaviors = {
			{id = "move_homing"},
			{id = "hit_damage"},
			{id = "apply_slow", data = {factor = 0.5, dur = 1.5 }},
			{id = "draw_slow"}
		}
	},

	lancer = {
		nameKey = "tower.lancer",
		descKey = "towerDesc.lancer",
		cost = 55,
		range = 3.9 * Constants.TILE,
		fireRate = 2.0, -- shots/sec
		damage = 10,
		recoilStrength = Constants.TILE * 0.08,
		recoilDecay = 18,
		projSpeed = 460,
		turnSpeed = 15,
		color = Theme.tower.lancer,
		canRotate = true,
		upgrade = {
			dmgMult = 2.2,
			rangeAdd = 0.08 * Constants.TILE,
			fireMult = 1.0, -- 1.03
		},
		upgradeChoices = {
			"lancer_deadeye",
			"lancer_volley",
			"lancer_ricochet",
			"lancer_rail_lance",
			"lancer_arc_lance",
		},
		behaviors = {
			{id = "move_homing"},
			{id = "hit_circle", data = {radius = 10 }},
			{id = "hit_damage"},
			{id = "lancer_hit_fx"},
			{id = "draw_lancer"}
		},
	},

	poison = {
		nameKey = "tower.poison",
		descKey = "towerDesc.poison",
		cost = 60,
		range = 3.6 * Constants.TILE,
		fireRate = 1.6,
		damage = 5,
		recoilStrength = Constants.TILE * 0.06,
		recoilDecay = 16,
		projSpeed = 360,
		turnSpeed = 11,
		color = Theme.tower.poison,
		canRotate = true,
		upgrade = {
			dmgMult = 2.2,
			rangeAdd = 0.06 * Constants.TILE,
			fireMult = 1.0, -- 1.02
			poisonDurAdd = 0.25,
			poisonDpsMult = 1.10,
			stackAdd = 1,
		},
		upgradeChoices = {
			"poison_blight",
			"poison_plague",
			"poison_neurotoxin",
		},
		behaviors = {
			{id = "move_homing"},
			{id = "hit_circle", data = {radius = 12}},
			{id = "hit_damage"},
			{id = "apply_poison", data = {dps = 4, dur = 2, maxStacks = 10}},
			{id = "draw_poison"}
		}
	},

	cannon = {
		nameKey = "tower.cannon",
		descKey = "towerDesc.cannon",
		cost = 65,
		range = 3.2 * Constants.TILE,
		fireRate = 0.85,
		damage = 19,
		recoilStrength = Constants.TILE * 0.12,
		recoilDecay = 14,
		projSpeed = 320,
		turnSpeed = 8,
		color = Theme.tower.cannon,
		canRotate = true,
		upgrade = {
			dmgMult = 2.2,
			rangeAdd = 0.08 * Constants.TILE,
			fireMult = 1.0, -- 1.05
			splashAdd = 4, -- increase AoE radius per upgrade
		},
		upgradeChoices = {
			"cannon_siege_shells",
			"cannon_rapid_mortar",
			"cannon_cluster_payload",
		},
		behaviors = {
			{id = "move_homing"},
			{id = "hit_circle", data = {radius = 12 }},
			{id = "aoe_damage", data = {radius = 48 }},
			{id = "draw_cannon" }
		}
	},

	shock = {
		nameKey = "tower.shock",
		descKey = "towerDesc.shock",
		cost = 70,
		range = 3.5 * Constants.TILE,
		fireRate = 1.2,
		damage = 9,
		recoilStrength = Constants.TILE * 0.03,
		recoilDecay = 5, -- Dramatic because the recoil is so small
		turnSpeed = 9,
		color = Theme.tower.shock,
		canRotate = true,
		upgrade = {
			dmgMult = 2.2,
			rangeAdd = 0.06 * Constants.TILE,
			fireMult = 1.0, -- 1.04
		},
		upgradeChoices = {
			"shock_storm_coil",
			"shock_overcharge",
			"shock_forked_arc",
		},
		behaviors = {
			{id = "emit_on_target"},
			{id = "hit_chain", data = {jumps = 4, radius = 56}},
			{id = "chain_zap_fx"}
		}
	},

	plasma = {
		nameKey = "tower.plasma",
		descKey = "towerDesc.plasma",
		cost = 75,
		range = 3.5 * Constants.TILE,
		fireRate = 0.7,
		damage = 3,
		recoilStrength = Constants.TILE * 0.14,
		recoilDecay = 18,
		projSpeed = 140,
		turnSpeed = 8,
		color = Theme.tower.plasma,
		canRotate = true,
		upgrade = {
			dmgMult = 2.2,
			rangeAdd = 0.08 * Constants.TILE,
			fireMult = 1.0,
		},
		upgradeChoices = {
			"plasma_lance",
			"plasma_supernova",
			"plasma_vortex",
		},
		behaviors = {
			{id = "move_linear", data = {dist = 300}},
			{id = "tick_damage", data = {radius = 12, rate = 0.1}},
			{id = "draw_plasma"}
		}
	},
}
