local mult = 0.5

-- Modifiers here eventually would go hard

return {
	grunt = {
		nameKey = "enemy.grunt",
		hp = 30 * mult,
		speed = 70,
		reward = 5,
		score = 10,
		radius = 10,
	},

	tank = {
		nameKey = "enemy.tank",
		hp = 80 * mult,
		speed = 45,
		reward = 10,
		score = 22,
		radius = 12,
	},

	runner = {
		nameKey = "enemy.runner",
		hp = 22 * mult,
		speed = 95,
		reward = 6,
		score = 12,
		radius = 9,
	},


	overcharger = {
		nameKey = "enemy.overcharger",
		hp = 20 * mult,
		speed = 64,
		reward = 9,
		score = 18,
		radius = 10,
		hasteRadius = 145,
		hasteDuration = 2.0,
		hasteCooldown = 6.2,
		hasteSpeedMultiplier = 1.35,
		hasteMaxSpeedMult = 1.7,
	},

	jammer = {
		nameKey = "enemy.jammer",
		hp = 18 * mult,
		speed = 72,
		reward = 7,
		score = 16,
		radius = 10,
		jamRadius = 115,
		jamDuration = 2.2,
		jamCooldown = 6.5,
		jamTelegraph = 0.8,
	},


	leech_beacon = {
		nameKey = "enemy.leech_beacon",
		hp = 42 * mult,
		speed = 52,
		reward = 22,
		score = 48,
		radius = 13,
		linkRange = 220,
		linkDuration = 3.6,
		linkCooldown = 12.0,
		fireRateMultiplier = 0.45,
	},

	projector = {
		nameKey = "enemy.projector",
		hp = 26 * mult,
		speed = 42,
		reward = 11,
		score = 20,
		radius = 11,
		shieldRadius = 130,
		shieldAmount = 22,
		shieldDuration = 3.8,
		shieldCooldown = 6.0,
	},

	boss = {
		nameKey = "enemy.boss",
		hp = 625 * mult,
		speed = 45,
		reward = 70,
		score = 300,
		radius = 18,
		boss = true,
		mechanicWeight = 1.0,
		counterplay = {
			telegraph = 1.4,
			weakPhase = 2.0,
			exposedWindow = 1.6,
		},

		modifiers = {
			--slow = 0.5, -- 50% slow effectiveness (movement speed)
			--poison = 1.25, -- +25% poison damage taken
		}
	},

	boss_summoner = {
		nameKey = "enemy.boss",
		hp = 560 * mult,
		speed = 42,
		reward = 110,
		score = 380,
		radius = 18,
		boss = true,
		mechanicWeight = 1.35,
		mechanicPackage = "summoner",
		counterplay = {
			telegraph = 2.2,
			weakPhase = 2.8,
			exposedWindow = 2.1,
		},
		ability = {
			name = "add_wave",
			telegraph = 2.2,
			weakPhase = 2.8,
			exposedWindow = 2.1,
		},
	},

	boss_displacement = {
		nameKey = "enemy.boss",
		hp = 640 * mult,
		speed = 48,
		reward = 125,
		score = 430,
		radius = 19,
		boss = true,
		mechanicWeight = 1.5,
		mechanicPackage = "displacement",
		counterplay = {
			telegraph = 1.7,
			weakPhase = 2.4,
			exposedWindow = 2.4,
		},
		ability = {
			name = "shockwave_dash",
			telegraph = 1.7,
			weakPhase = 2.4,
			exposedWindow = 2.4,
		},
	},

	boss_suppression = {
		nameKey = "enemy.boss",
		hp = 700 * mult,
		speed = 40,
		reward = 140,
		score = 500,
		radius = 20,
		boss = true,
		mechanicWeight = 1.65,
		mechanicPackage = "suppression_aura",
		counterplay = {
			telegraph = 2.4,
			weakPhase = 2.2,
			exposedWindow = 2.8,
		},
		ability = {
			name = "silence_aura",
			telegraph = 2.4,
			weakPhase = 2.2,
			exposedWindow = 2.8,
		},
	},
}
