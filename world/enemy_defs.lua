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

	regenerator = {
		nameKey = "enemy.regenerator",
		hp = 48 * mult,
		speed = 58,
		reward = 12,
		score = 28,
		radius = 11,
		regen = {
			rate = 3.0 * mult,
			delay = 0.8,
		},
	},

	stitcher = {
		nameKey = "enemy.stitcher",
		hp = 64 * mult,
		speed = 50,
		reward = 16,
		score = 40,
		radius = 12,
		regen = {
			rate = 5.5 * mult,
			delay = 1.15,
		},
	},

	shielder = {
		nameKey = "enemy.shielder",
		hp = 42 * mult,
		speed = 52,
		reward = 13,
		score = 32,
		radius = 12,
		shield = {
			fraction = 0.55,
			damageReduction = 0.18,
		},
	},

	aegis_runner = {
		nameKey = "enemy.aegisRunner",
		hp = 26 * mult,
		speed = 88,
		reward = 10,
		score = 24,
		radius = 10,
		shield = {
			fraction = 0.35,
			damageReduction = 0.12,
		},
	},

	bastion = {
		nameKey = "enemy.bastion",
		hp = 58 * mult,
		speed = 38,
		reward = 18,
		score = 46,
		radius = 14,
		shield = {
			fraction = 0.9,
			damageReduction = 0.25,
			regenRate = 4.0 * mult,
			regenDelay = 2.4,
		},
	},

	bulwark_mender = {
		nameKey = "enemy.bulwarkMender",
		hp = 54 * mult,
		speed = 46,
		reward = 20,
		score = 54,
		radius = 13,
		regen = {
			rate = 3.8 * mult,
			delay = 1.0,
		},
		shield = {
			fraction = 0.5,
			damageReduction = 0.2,
			regenRate = 2.8 * mult,
			regenDelay = 2.0,
		},
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
