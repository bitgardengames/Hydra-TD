local Constants = require("core.constants")
local Theme = require("core.theme")

-- Costs, output, and upgrade curves below are the checked-in simulated baseline.
-- Keep role tradeoffs intact and regenerate the balance fixtures after tuning.

return {
	-- Role: control and runner/boss support. Low damage and modest scaling keep
	-- it from replacing damage towers, while long reach and growing slow uptime
	-- make it a force multiplier against fast enemies and durable targets.
	slow = {
		nameKey = "tower.slow",
		descKey = "towerDesc.slow",
		cost = 50,
		range = 4.25 * Constants.TILE,
		fireRate = 1.2,
		damage = 3,
		recoilStrength = Constants.TILE * 0.06,
		recoilDecay = 10,
		projSpeed = 370,
		turnSpeed = 10,
		color = Theme.tower.slow,
		canRotate = true,
		upgrade = {
			base = {dmgMult = 1, fireMult = 1, rangeAdd = 0, slowDurAdd = 0},
			branches = {
				deep_freeze = {
					fireProfile = {
						{id = "move_homing"},
						{id = "hit_damage"},
						{id = "apply_slow", data = {factor = 0.58, dur = 1.7}},
						{id = "draw_slow"},
					},
					tiers = {
						[2] = {dmgMult = 1.15, fireMult = 1.05, rangeAdd = 0.18 * Constants.TILE, slowDurAdd = 0.55, slowFactor = 0.58},
						[3] = {dmgMult = 1.30, fireMult = 1.10, rangeAdd = 0.36 * Constants.TILE, slowDurAdd = 0.55, slowFactor = 0.63},
						[4] = {dmgMult = 1.45, fireMult = 1.15, rangeAdd = 0.54 * Constants.TILE, slowDurAdd = 0.55, slowFactor = 0.68},
						[5] = {dmgMult = 1.60, fireMult = 1.20, rangeAdd = 0.72 * Constants.TILE, slowDurAdd = 0.55, slowFactor = 0.72},
					},
				},
				cold_field = {
					fireProfile = {
						{id = "move_homing"},
						{id = "hit_damage"},
						{id = "apply_slow", data = {factor = 0.45, dur = 1.7}},
						{id = "slow_field", data = {radius = 62, life = 2.4, factor = 0.36, tick = 0.25, dur = 0.4}},
						{id = "draw_slow"},
					},
					tiers = {
						[2] = {dmgMult = 1.10, fireMult = 1.08, rangeAdd = 0.14 * Constants.TILE, slowDurAdd = 0.35, fieldRadius = 62, fieldLifetime = 2.4, fieldFactor = 0.36},
						[3] = {dmgMult = 1.20, fireMult = 1.16, rangeAdd = 0.28 * Constants.TILE, slowDurAdd = 0.70, fieldRadius = 68, fieldLifetime = 2.8, fieldFactor = 0.39},
						[4] = {dmgMult = 1.30, fireMult = 1.24, rangeAdd = 0.42 * Constants.TILE, slowDurAdd = 1.05, fieldRadius = 74, fieldLifetime = 3.2, fieldFactor = 0.42},
						[5] = {dmgMult = 1.40, fireMult = 1.32, rangeAdd = 0.56 * Constants.TILE, slowDurAdd = 1.40, fieldRadius = 82, fieldLifetime = 3.6, fieldFactor = 0.45},
					},
				},
			},
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
	-- scaling rewards upgrades. It lacks crowd control and splash, while its heavy hits retain
	-- focused utility against armor.
	lancer = {
		nameKey = "tower.lancer",
		descKey = "towerDesc.lancer",
		cost = 60,
		range = 3.75 * Constants.TILE,
		fireRate = 2.2, -- shots/sec
		damage = 9,
		recoilStrength = Constants.TILE * 0.08,
		recoilDecay = 18,
		projSpeed = 520,
		turnSpeed = 18,
		color = Theme.tower.lancer,
		canRotate = true,
		upgrade = {
			base = {dmgMult = 1, fireMult = 1, rangeAdd = 0},
			branches = {
				marksman = {
					targetingPolicy = "durable_priority",
					tiers = {
						[2] = {dmgMult = 1.55, fireMult = 1.00, rangeAdd = 0.12 * Constants.TILE},
						[3] = {dmgMult = 2.10, fireMult = 1.02, rangeAdd = 0.24 * Constants.TILE},
						[4] = {dmgMult = 2.75, fireMult = 1.04, rangeAdd = 0.36 * Constants.TILE},
						[5] = {dmgMult = 3.50, fireMult = 1.06, rangeAdd = 0.48 * Constants.TILE},
					},
				},
				rupture = {
					fireProfile = {
						{id = "move_linear"},
						{id = "hit_circle", data = {radius = 12}},
						{id = "hit_damage"},
						{id = "pierce", data = {maxHits = 2}},
						{id = "lancer_hit_fx"},
						{id = "draw_lancer"},
					},
					tiers = {
						[2] = {dmgMult = 1.30, fireMult = 1.045, rangeAdd = 0.08 * Constants.TILE, pierceMaxHits = 2},
						[3] = {dmgMult = 1.70, fireMult = 1.09, rangeAdd = 0.16 * Constants.TILE, pierceMaxHits = 3},
						[4] = {dmgMult = 2.15, fireMult = 1.135, rangeAdd = 0.24 * Constants.TILE, pierceMaxHits = 3},
						[5] = {dmgMult = 2.65, fireMult = 1.18, rangeAdd = 0.32 * Constants.TILE, pierceMaxHits = 4},
					},
				},
			},
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
		fireRate = 1.4,
		damage = 2,
		recoilStrength = Constants.TILE * 0.06,
		recoilDecay = 16,
		projSpeed = 360,
		turnSpeed = 11,
		color = Theme.tower.poison,
		canRotate = true,
		upgrade = {
			base = {dmgMult = 1, fireMult = 1, rangeAdd = 0},
			branches = {
				power = {tiers = {
					[2] = {dmgMult = 1.25, fireMult = 1.05, rangeAdd = 0.09 * Constants.TILE, poisonDurAdd = 0.4, poisonDpsMult = 1.18, stackAdd = 1},
					[3] = {dmgMult = 1.5, fireMult = 1.1, rangeAdd = 0.18 * Constants.TILE, poisonDurAdd = 0.8, poisonDpsMult = 1.3924, stackAdd = 2},
					[4] = {dmgMult = 1.75, fireMult = 1.15, rangeAdd = 0.27 * Constants.TILE, poisonDurAdd = 1.2, poisonDpsMult = 1.643032, stackAdd = 3},
					[5] = {dmgMult = 2, fireMult = 1.2, rangeAdd = 0.36 * Constants.TILE, poisonDurAdd = 1.6, poisonDpsMult = 1.9387778, stackAdd = 4},
				}},
				tempo = {tiers = {
					[2] = {dmgMult = 1.25, fireMult = 1.05, rangeAdd = 0.09 * Constants.TILE, poisonDurAdd = 0.4, poisonDpsMult = 1.18, stackAdd = 1},
					[3] = {dmgMult = 1.5, fireMult = 1.1, rangeAdd = 0.18 * Constants.TILE, poisonDurAdd = 0.8, poisonDpsMult = 1.3924, stackAdd = 2},
					[4] = {dmgMult = 1.75, fireMult = 1.15, rangeAdd = 0.27 * Constants.TILE, poisonDurAdd = 1.2, poisonDpsMult = 1.643032, stackAdd = 3},
					[5] = {dmgMult = 2, fireMult = 1.2, rangeAdd = 0.36 * Constants.TILE, poisonDurAdd = 1.6, poisonDpsMult = 1.9387778, stackAdd = 4},
				}},
			},
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
		fireRate = 0.7,
		-- At three targets, splash already gives this about twice the Lancer's
		-- total damage per second. Keep the shell to two Lancer hits so
		-- Cannon pays for that crowd damage with weaker single-target efficiency.
		damage = 14,
		recoilStrength = Constants.TILE * 0.12,
		recoilDecay = 14,
		projSpeed = 280,
		turnSpeed = 7,
		color = Theme.tower.cannon,
		canRotate = true,
		upgrade = {
			base = {dmgMult = 1, fireMult = 1, rangeAdd = 0},
			branches = {
				power = {tiers = {
					[2] = {dmgMult = 1.3625, fireMult = 1.03, rangeAdd = 0.08 * Constants.TILE, splashAdd = 5},
					[3] = {dmgMult = 1.725, fireMult = 1.06, rangeAdd = 0.16 * Constants.TILE, splashAdd = 10},
					[4] = {dmgMult = 2.0875, fireMult = 1.09, rangeAdd = 0.24 * Constants.TILE, splashAdd = 15},
					[5] = {dmgMult = 2.45, fireMult = 1.12, rangeAdd = 0.32 * Constants.TILE, splashAdd = 20},
				}},
				tempo = {tiers = {
					[2] = {dmgMult = 1.3625, fireMult = 1.03, rangeAdd = 0.08 * Constants.TILE, splashAdd = 5},
					[3] = {dmgMult = 1.725, fireMult = 1.06, rangeAdd = 0.16 * Constants.TILE, splashAdd = 10},
					[4] = {dmgMult = 2.0875, fireMult = 1.09, rangeAdd = 0.24 * Constants.TILE, splashAdd = 15},
					[5] = {dmgMult = 2.45, fireMult = 1.12, rangeAdd = 0.32 * Constants.TILE, splashAdd = 20},
				}},
			},
		},
		behaviors = {
			{id = "move_to_target_point"},
			{id = "aoe_damage", data = {radius = 44}},
			{id = "draw_cannon" }
		}
	},

	-- Role: chain damage. Multi-target jumps spread medium damage across packed
	-- waves. Low raw damage keeps it inefficient against isolated threats.
	shock = {
		nameKey = "tower.shock",
		descKey = "towerDesc.shock",
		cost = 95,
		range = 3.7 * Constants.TILE,
		fireRate = 1.1,
		damage = 8,
		recoilStrength = Constants.TILE * 0.03,
		recoilDecay = 5, -- Dramatic because the recoil is so small
		turnSpeed = 9,
		color = Theme.tower.shock,
		canRotate = true,
		upgrade = {
			base = {dmgMult = 1, fireMult = 1, rangeAdd = 0},
			branches = {
				power = {tiers = {
					[2] = {dmgMult = 1.275, fireMult = 1.05, rangeAdd = 0.11 * Constants.TILE},
					[3] = {dmgMult = 1.55, fireMult = 1.1, rangeAdd = 0.22 * Constants.TILE},
					[4] = {dmgMult = 1.825, fireMult = 1.15, rangeAdd = 0.33 * Constants.TILE},
					[5] = {dmgMult = 2.1, fireMult = 1.2, rangeAdd = 0.44 * Constants.TILE},
				}},
				tempo = {tiers = {
					[2] = {dmgMult = 1.275, fireMult = 1.05, rangeAdd = 0.11 * Constants.TILE},
					[3] = {dmgMult = 1.55, fireMult = 1.1, rangeAdd = 0.22 * Constants.TILE},
					[4] = {dmgMult = 1.825, fireMult = 1.15, rangeAdd = 0.33 * Constants.TILE},
					[5] = {dmgMult = 2.1, fireMult = 1.2, rangeAdd = 0.44 * Constants.TILE},
				}},
			},
		},
		behaviors = {
			{id = "emit_on_target"},
			{id = "hit_chain", data = {jumps = 4, radius = 62, falloff = 0.82}},
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
		fireRate = 0.75,
		damage = 4,
		recoilStrength = Constants.TILE * 0.14,
		recoilDecay = 18,
		projSpeed = 120,
		turnSpeed = 8,
		color = Theme.tower.plasma,
		canRotate = true,
		upgrade = {
			base = {dmgMult = 1, fireMult = 1, rangeAdd = 0},
			branches = {
				power = {tiers = {
					[2] = {dmgMult = 1.2875, fireMult = 1.0625, rangeAdd = 0.09 * Constants.TILE},
					[3] = {dmgMult = 1.575, fireMult = 1.125, rangeAdd = 0.18 * Constants.TILE},
					[4] = {dmgMult = 1.8625, fireMult = 1.1875, rangeAdd = 0.27 * Constants.TILE},
					[5] = {dmgMult = 2.15, fireMult = 1.25, rangeAdd = 0.36 * Constants.TILE},
				}},
				tempo = {tiers = {
					[2] = {dmgMult = 1.2875, fireMult = 1.0625, rangeAdd = 0.09 * Constants.TILE},
					[3] = {dmgMult = 1.575, fireMult = 1.125, rangeAdd = 0.18 * Constants.TILE},
					[4] = {dmgMult = 1.8625, fireMult = 1.1875, rangeAdd = 0.27 * Constants.TILE},
					[5] = {dmgMult = 2.15, fireMult = 1.25, rangeAdd = 0.36 * Constants.TILE},
				}},
			},
		},
		behaviors = {
			{id = "move_linear", data = {dist = 330}},
			{id = "tick_damage", data = {radius = 16, rate = 0.14}},
			{id = "draw_plasma"}
		}
	},
}
