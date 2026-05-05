local mult = 0.5

-- Modifiers here eventually would go hard

return {
	grunt = {
		nameKey = "enemy.grunt",
		hp = 30 * mult,
		speed = 70,
		reward = 7,
		score = 10,
		radius = 10,
	},

	tank = {
		nameKey = "enemy.tank",
		hp = 80 * mult,
		speed = 45,
		reward = 12,
		score = 22,
		radius = 12,
	},

	runner = {
		nameKey = "enemy.runner",
		hp = 22 * mult,
		speed = 95,
		reward = 8,
		score = 12,
		radius = 9,
	},

	boss = {
		nameKey = "enemy.boss",
		hp = 625 * mult,
		speed = 45,
		reward = 80,
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
