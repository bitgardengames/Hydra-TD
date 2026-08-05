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
		traits = {"fast"},
	},

	bulwark = {
		nameKey = "enemy.bulwark",
		descriptionKey = "enemy.bulwarkDescription",
		hp = 105 * mult, speed = 40, reward = 13, score = 30, radius = 14,
		armor = { flatReduction = 5, heavyMultiplier = 1.35, heavyThreshold = 14 },
		traits = {"armored"},
	},

	regenerator = {
		nameKey = "enemy.regenerator",
		descriptionKey = "enemy.regeneratorDescription",
		hp = 76 * mult, speed = 53, reward = 12, score = 28, radius = 12,
		regeneration = { hpPerSecond = 5 * mult, delay = 1.25 },
		modifiers = { poison = 1.25 },
		traits = {"regenerates"},
	},

	shieldbearer = {
		nameKey = "enemy.shieldbearer",
		descriptionKey = "enemy.shieldbearerDescription",
		hp = 72 * mult, speed = 50, reward = 14, score = 32, radius = 13,
		shield = { hp = 30 * mult, burstThreshold = 12, burstMultiplier = 1.6, chainMultiplier = 1.75 },
		traits = {"shielded"},
	},

	warcaller = {
		nameKey = "enemy.warcaller",
		descriptionKey = "enemy.warcallerDescription",
		hp = 68 * mult, speed = 48, reward = 16, score = 38, radius = 13,
		support = { radius = 92, speedMultiplier = 1.32, pulsePeriod = 1.2 },
		targetPriority = 34,
		traits = {"support"},
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
		traits = {"boss_summoner"},
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
		traits = {"boss_displacement"},
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
		traits = {"boss_suppression"},
	},
}
