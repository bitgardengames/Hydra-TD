local Constants = require("core.constants")
local Theme = require("core.theme")

-- Costs, output, and upgrade curves below are the checked-in simulated baseline.
-- Keep role tradeoffs intact and regenerate the balance fixtures after tuning.

local definitions = {
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
			tiers = {[2] = {dmgMult = 1.125, fireMult = 1.065, rangeAdd = 0.16 * Constants.TILE}},
			branches = {
				deep_freeze = {
					id = "deep_freeze",
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
					id = "cold_field",
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
			tiers = {[2] = {dmgMult = 1.425, fireMult = 1.0225, rangeAdd = 0.10 * Constants.TILE}},
			branches = {
				marksman = {
					id = "marksman",
					targetingPolicy = "durable_priority",
					tiers = {
						[2] = {dmgMult = 1.55, fireMult = 1.00, rangeAdd = 0.12 * Constants.TILE},
						[3] = {dmgMult = 2.10, fireMult = 1.02, rangeAdd = 0.24 * Constants.TILE},
						[4] = {dmgMult = 2.75, fireMult = 1.04, rangeAdd = 0.36 * Constants.TILE},
						[5] = {dmgMult = 3.50, fireMult = 1.06, rangeAdd = 0.48 * Constants.TILE},
					},
				},
				rupture = {
					id = "rupture",
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
			tiers = {[2] = {dmgMult = 1.215, fireMult = 1.065, rangeAdd = 0.09 * Constants.TILE}},
			branches = {
				virulent = {
					id = "virulent",
					tiers = {
					[2] = {dmgMult = 1.25, fireMult = 1.05, rangeAdd = 0.09 * Constants.TILE, poisonDPS = 6.0, poisonDuration = 5.0, poisonStackCap = 10, spreadRadius = 0, transferFraction = 0, recipientCap = 0},
					[3] = {dmgMult = 1.50, fireMult = 1.10, rangeAdd = 0.18 * Constants.TILE, poisonDPS = 7.0, poisonDuration = 5.5, poisonStackCap = 12, spreadRadius = 0, transferFraction = 0, recipientCap = 0},
					[4] = {dmgMult = 1.75, fireMult = 1.15, rangeAdd = 0.27 * Constants.TILE, poisonDPS = 8.5, poisonDuration = 6.0, poisonStackCap = 14, spreadRadius = 0, transferFraction = 0, recipientCap = 0},
					[5] = {dmgMult = 2.00, fireMult = 1.20, rangeAdd = 0.36 * Constants.TILE, poisonDPS = 10.0, poisonDuration = 6.5, poisonStackCap = 16, spreadRadius = 0, transferFraction = 0, recipientCap = 0},
					},
				},
				contagion = {
					id = "contagion",
					fireProfile = {
						{id = "move_homing"},
						{id = "hit_circle", data = {radius = 12}},
						{id = "hit_damage"},
						{id = "apply_poison", data = {dps = 4, dur = 4.5, maxStacks = 8}},
						{id = "infect_spread", data = {radius = 64, stackMult = 0.5, recipientCap = 3}},
						{id = "draw_poison"},
					},
					tiers = {
						[2] = {dmgMult = 1.18, fireMult = 1.08, rangeAdd = 0.09 * Constants.TILE, poisonDPS = 4.5, poisonDuration = 4.8, poisonStackCap = 9, spreadRadius = 64, transferFraction = 0.50, recipientCap = 3},
						[3] = {dmgMult = 1.35, fireMult = 1.16, rangeAdd = 0.18 * Constants.TILE, poisonDPS = 5.0, poisonDuration = 5.2, poisonStackCap = 10, spreadRadius = 76, transferFraction = 0.55, recipientCap = 3},
						[4] = {dmgMult = 1.52, fireMult = 1.24, rangeAdd = 0.27 * Constants.TILE, poisonDPS = 5.5, poisonDuration = 5.6, poisonStackCap = 11, spreadRadius = 88, transferFraction = 0.60, recipientCap = 4},
						[5] = {dmgMult = 1.70, fireMult = 1.32, rangeAdd = 0.36 * Constants.TILE, poisonDPS = 6.0, poisonDuration = 6.0, poisonStackCap = 12, spreadRadius = 104, transferFraction = 0.70, recipientCap = 5},
					},
				},
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
			tiers = {[2] = {dmgMult = 1.575, fireMult = 1.03, rangeAdd = 0.08 * Constants.TILE}},
			branches = {
				siege = {
					id = "siege",
					fireProfile = {
						{id = "move_to_target_point"},
						{id = "aoe_damage", data = {radius = 50, falloff = 0.68}},
						{id = "draw_cannon"},
					},
					tiers = {
						[2] = {dmgMult = 1.80, fireMult = 1.02, rangeAdd = 0.08 * Constants.TILE, splashRadius = 50, splashFalloff = 0.68},
						[3] = {dmgMult = 2.35, fireMult = 1.04, rangeAdd = 0.16 * Constants.TILE, splashRadius = 52, splashFalloff = 0.69},
						[4] = {dmgMult = 2.90, fireMult = 1.06, rangeAdd = 0.24 * Constants.TILE, splashRadius = 54, splashFalloff = 0.70},
						[5] = {dmgMult = 3.55, fireMult = 1.08, rangeAdd = 0.32 * Constants.TILE, splashRadius = 56, splashFalloff = 0.72},
					},
				},
				bombardment = {
					id = "bombardment",
					fireProfile = {
						{id = "move_to_target_point"},
						{id = "aoe_damage", data = {radius = 64, falloff = 0.72}},
						{id = "draw_cannon"},
					},
					tiers = {
						[2] = {dmgMult = 1.35, fireMult = 1.04, rangeAdd = 0.08 * Constants.TILE, splashRadius = 64, splashFalloff = 0.72},
						[3] = {dmgMult = 1.60, fireMult = 1.08, rangeAdd = 0.16 * Constants.TILE, splashRadius = 70, splashFalloff = 0.74},
						[4] = {dmgMult = 1.95, fireMult = 1.12, rangeAdd = 0.24 * Constants.TILE, splashRadius = 78, splashFalloff = 0.76},
						[5] = {dmgMult = 2.30, fireMult = 1.16, rangeAdd = 0.32 * Constants.TILE, splashRadius = 84, splashFalloff = 0.78},
					},
				},
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
			tiers = {[2] = {dmgMult = 1.325, fireMult = 1.04, rangeAdd = 0.11 * Constants.TILE}},
			branches = {
				capacitor = {
					id = "capacitor",
					fireProfile = {
						{id = "capacitor", data = {threshold = 4, dischargeMult = 1.0}},
						{id = "emit_on_target"},
						-- Two jumps means three total contacts. Discharge is deliberately
						-- resolved only on contact one during the initial tuning pass.
						{id = "hit_chain", data = {jumps = 2, radius = 62, falloff = 0.82}},
						{id = "chain_zap_fx"},
					},
					tiers = {
						[2] = {dmgMult = 1.45, fireMult = 1.02, rangeAdd = 0.11 * Constants.TILE, chainJumps = 2, chainRadius = 62, chainFalloff = 0.82, capacitorThreshold = 4, dischargeMult = 1.00},
						[3] = {dmgMult = 1.90, fireMult = 1.05, rangeAdd = 0.22 * Constants.TILE, chainJumps = 2, chainRadius = 64, chainFalloff = 0.83, capacitorThreshold = 4, dischargeMult = 1.05},
						[4] = {dmgMult = 2.35, fireMult = 1.08, rangeAdd = 0.33 * Constants.TILE, chainJumps = 2, chainRadius = 66, chainFalloff = 0.84, capacitorThreshold = 4, dischargeMult = 1.10},
						[5] = {dmgMult = 3.00, fireMult = 1.12, rangeAdd = 0.44 * Constants.TILE, chainJumps = 2, chainRadius = 68, chainFalloff = 0.85, capacitorThreshold = 3, dischargeMult = 1.20},
					},
				},
				forked_lightning = {
					id = "forked_lightning",
					fireProfile = {
						{id = "emit_on_target"},
						{id = "hit_chain", data = {jumps = 5, radius = 70, falloff = 0.88}},
						{id = "chain_zap_fx"},
					},
					tiers = {
						[2] = {dmgMult = 1.20, fireMult = 1.06, rangeAdd = 0.11 * Constants.TILE, chainJumps = 5, chainRadius = 70, chainFalloff = 0.88},
						[3] = {dmgMult = 1.47, fireMult = 1.12, rangeAdd = 0.22 * Constants.TILE, chainJumps = 6, chainRadius = 78, chainFalloff = 0.89},
						[4] = {dmgMult = 1.75, fireMult = 1.18, rangeAdd = 0.33 * Constants.TILE, chainJumps = 7, chainRadius = 86, chainFalloff = 0.90},
						[5] = {dmgMult = 2.15, fireMult = 1.24, rangeAdd = 0.44 * Constants.TILE, chainJumps = 8, chainRadius = 94, chainFalloff = 0.92},
					},
				},
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
			tiers = {[2] = {dmgMult = 1.265, fireMult = 1.055, rangeAdd = 0.09 * Constants.TILE}},
			branches = {
				accelerator = {
					id = "accelerator",
					fireProfile = {
						{id = "move_linear", data = {dist = 390}},
						{id = "tick_damage", data = {radius = 14, rate = 0.14}},
						{id = "draw_plasma"},
					},
					tiers = {
						[2] = {dmgMult = 1.35, fireMult = 1.05, rangeAdd = 0.09 * Constants.TILE, projSpeed = 140, travelDistance = 390, tickRadius = 14, tickRate = 0.14},
						[3] = {dmgMult = 1.65, fireMult = 1.10, rangeAdd = 0.18 * Constants.TILE, projSpeed = 155, travelDistance = 450, tickRadius = 14, tickRate = 0.14},
						[4] = {dmgMult = 2.05, fireMult = 1.15, rangeAdd = 0.27 * Constants.TILE, projSpeed = 175, travelDistance = 520, tickRadius = 13, tickRate = 0.14},
						[5] = {dmgMult = 2.55, fireMult = 1.20, rangeAdd = 0.36 * Constants.TILE, projSpeed = 200, travelDistance = 600, tickRadius = 12, tickRate = 0.14},
					},
				},
				overcharged = {
					id = "overcharged",
					fireProfile = {
						{id = "move_linear", data = {dist = 340}},
						{id = "tick_damage", data = {radius = 20, rate = 0.13}},
						{id = "draw_plasma"},
					},
					tiers = {
						[2] = {dmgMult = 1.18, fireMult = 1.06, rangeAdd = 0.09 * Constants.TILE, projSpeed = 112, travelDistance = 340, tickRadius = 20, tickRate = 0.13},
						[3] = {dmgMult = 1.40, fireMult = 1.13, rangeAdd = 0.18 * Constants.TILE, projSpeed = 106, travelDistance = 350, tickRadius = 24, tickRate = 0.12},
						[4] = {dmgMult = 1.68, fireMult = 1.20, rangeAdd = 0.27 * Constants.TILE, projSpeed = 100, travelDistance = 360, tickRadius = 28, tickRate = 0.11},
						[5] = {dmgMult = 2.00, fireMult = 1.28, rangeAdd = 0.36 * Constants.TILE, projSpeed = 94, travelDistance = 370, tickRadius = 32, tickRate = 0.10},
					},
				},
			},
		},
		behaviors = {
			{id = "move_linear", data = {dist = 330}},
			{id = "tick_damage", data = {radius = 16, rate = 0.14}},
			{id = "draw_plasma"}
		}
	},
}

require("systems.branch_tier_resolver").validate(definitions)
return definitions
