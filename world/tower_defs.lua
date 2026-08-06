local Constants = require("core.constants")
local Theme = require("core.theme")

return {
	-- Role: control and runner/boss support. Low damage and modest scaling keep
	-- it from replacing damage towers, while long reach and growing slow uptime
	-- make it a force multiplier against fast enemies and durable targets.
	slow = {
		nameKey = "tower.slow",
		descKey = "towerDesc.slow",
		cost = 50,
		range = 4.25 * Constants.TILE,
		fireRate = 1.15,
		damage = 3,
		recoilStrength = Constants.TILE * 0.06,
		recoilDecay = 10,
		projSpeed = 370,
		turnSpeed = 10,
		color = Theme.tower.slow,
		canRotate = true,
		upgrade = {
			dmgMult = 1.2,
			rangeAdd = 0.14 * Constants.TILE,
			fireMult = 1.04,
			slowDurAdd = 0.45,
		},
		behaviors = {
			{id = "move_homing"},
			{id = "hit_damage"},
			{id = "apply_slow", data = {factor = 0.45, dur = 1.7 }},
			{id = "draw_slow"}
		}
	},

	-- Role: cheap single-target baseline. Medium range and highly reliable shots
	-- make it the efficient default for focused damage, while strong damage
	-- scaling rewards upgrades. It lacks crowd control, armor/shield utility,
	-- and splash.
	lancer = {
		nameKey = "tower.lancer",
		descKey = "towerDesc.lancer",
		cost = 60,
		range = 3.75 * Constants.TILE,
		fireRate = 2.15, -- shots/sec
		damage = 9,
		recoilStrength = Constants.TILE * 0.08,
		recoilDecay = 18,
		projSpeed = 520,
		turnSpeed = 18,
		color = Theme.tower.lancer,
		canRotate = true,
		upgrade = {
			dmgMult = 2.2,
			rangeAdd = 0.06 * Constants.TILE,
			fireMult = 1.08,
		},
		behaviors = {
			{id = "move_homing"},
			{id = "hit_circle", data = {radius = 12}},
			{id = "hit_damage"},
			{id = "lancer_hit_fx"},
			{id = "draw_lancer"}
		},
	},

	-- Role: attrition and regeneration counter. Weaker immediate hits are offset
	-- by high poison uptime and stack scaling, rewarding coverage on long paths
	-- and sustained pressure instead of burst kills.
	poison = {
		nameKey = "tower.poison",
		descKey = "towerDesc.poison",
		cost = 70,
		range = 3.55 * Constants.TILE,
		fireRate = 1.35,
		damage = 2,
		recoilStrength = Constants.TILE * 0.06,
		recoilDecay = 16,
		projSpeed = 360,
		turnSpeed = 11,
		color = Theme.tower.poison,
		canRotate = true,
		upgrade = {
			dmgMult = 1.35,
			rangeAdd = 0.05 * Constants.TILE,
			fireMult = 1.04,
			poisonDurAdd = 0.4,
			poisonDpsMult = 1.18,
			stackAdd = 1,
		},
		behaviors = {
			{id = "move_homing"},
			{id = "hit_circle", data = {radius = 12}},
			{id = "hit_damage"},
			{id = "apply_poison", data = {dps = 4, dur = 4.5, maxStacks = 8}},
			{id = "draw_poison"}
		}
	},

	-- Role: heavy burst and armor counter. High per-shot damage and splash punish
	-- packed or armored waves, but premium cost, short reach, and low fire rate
	-- leave it vulnerable to leaks. Slow, unguided shells make runner control a
	-- job for the Slow tower rather than letting the cannon cover every role.
	cannon = {
		nameKey = "tower.cannon",
		descKey = "towerDesc.cannon",
		cost = 90,
		range = 3.05 * Constants.TILE,
		fireRate = 0.68,
		damage = 32,
		recoilStrength = Constants.TILE * 0.12,
		recoilDecay = 14,
		projSpeed = 280,
		turnSpeed = 7,
		color = Theme.tower.cannon,
		canRotate = true,
		upgrade = {
			dmgMult = 2.35,
			rangeAdd = 0.04 * Constants.TILE,
			fireMult = 1.03,
			splashAdd = 5, -- increase AoE radius per upgrade
		},
		behaviors = {
			{id = "move_linear"},
			{id = "hit_circle", data = {radius = 12}},
			{id = "aoe_damage", data = {radius = 44}},
			{id = "draw_cannon" }
		}
	},

	-- Role: chain damage and shield counter. Multi-target jumps spread medium
	-- damage across shielded packs, with shield-specific amplification supplying
	-- its payoff. Low raw damage keeps it inefficient against isolated threats.
	shock = {
		nameKey = "tower.shock",
		descKey = "towerDesc.shock",
		cost = 95,
		range = 3.7 * Constants.TILE,
		fireRate = 1.05,
		damage = 6,
		recoilStrength = Constants.TILE * 0.03,
		recoilDecay = 5, -- Dramatic because the recoil is so small
		turnSpeed = 9,
		color = Theme.tower.shock,
		canRotate = true,
		upgrade = {
			dmgMult = 1.75,
			rangeAdd = 0.08 * Constants.TILE,
			fireMult = 1.08,
		},
		behaviors = {
			{id = "emit_on_target"},
			{id = "hit_chain", data = {jumps = 5, radius = 62, falloff = 0.82}},
			{id = "chain_zap_fx"}
		}
	},

	-- Role: premium sustained lane damage. Slow, infrequent projectiles trade
	-- immediate reliability for punishing repeated ticks when aimed along a path;
	-- slows keep enemies inside that coverage long enough to realize its damage.
	plasma = {
		nameKey = "tower.plasma",
		descKey = "towerDesc.plasma",
		cost = 120,
		range = 3.4 * Constants.TILE,
		fireRate = 0.72,
		damage = 5,
		recoilStrength = Constants.TILE * 0.14,
		recoilDecay = 18,
		projSpeed = 120,
		turnSpeed = 8,
		color = Theme.tower.plasma,
		canRotate = true,
		upgrade = {
			dmgMult = 1.7,
			rangeAdd = 0.05 * Constants.TILE,
			fireMult = 1.08,
		},
		behaviors = {
			{id = "move_linear", data = {dist = 330}},
			{id = "tick_damage", data = {radius = 16, rate = 0.14}},
			{id = "draw_plasma"}
		}
	},
}
