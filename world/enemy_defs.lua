-- These are the actual wave-zero hit-point values. Wave and difficulty scaling
-- are applied once, at spawn time; literal values keep encounter budgets and
-- balance fixtures auditable without a hidden global multiplier. HP and kill
-- rewards use whole numbers so an authored count has a legible threat
-- and income budget in tools/balance/challenge_fixtures.py. Standard archetypes
-- pay $1 per three to six base effective durability, after mechanic weighting.

return {
	grunt = {
		nameKey = "enemy.grunt",
		hp = 17,
		speed = 70,
		reward = 5,
		score = 10,
		radius = 10,
	},

	tank = {
		nameKey = "enemy.tank",
		hp = 43,
		speed = 45,
		reward = 8,
		score = 22,
		radius = 12,
	},

	runner = {
		nameKey = "enemy.runner",
		hp = 14,
		speed = 95,
		reward = 4,
		score = 12,
		radius = 9,
		traits = {"fast"},
	},

	bulwark = {
		nameKey = "enemy.bulwark",
		descriptionKey = "enemy.bulwarkDescription",
		hp = 57, speed = 40, reward = 16, score = 30, radius = 14,
		armor = { flatReduction = 5, heavyMultiplier = 1.35, heavyThreshold = 14 },
		traits = {"armored"},
	},

	regenerator = {
		nameKey = "enemy.regenerator",
		descriptionKey = "enemy.regeneratorDescription",
		hp = 41, speed = 53, reward = 10, score = 28, radius = 12,
		regeneration = { hpPerSecond = 2.5, delay = 1.25 },
		modifiers = { poison = 1.25 },
		traits = {"regenerates"},
	},

	warcaller = {
		nameKey = "enemy.warcaller",
		descriptionKey = "enemy.warcallerDescription",
		hp = 41, speed = 48, reward = 10, score = 38, radius = 13,
		support = { radius = 92, speedMultiplier = 1.32, pulsePeriod = 1.2 },
		targetPriority = 34,
		traits = {"support"},
	},

	summoner = {
		nameKey = "enemy.summoner",
		descriptionKey = "enemy.summonerDescription",
		hp = 53, speed = 42, reward = 12, score = 44, radius = 14,
		summon = {
			kind = "runner", count = 2, period = 6.0, initialDelay = 2.5,
			stagger = 0.18, spacing = 9,
		},
		targetPriority = 38,
		traits = {"summons"},
	},

	boss = {
		nameKey = "enemy.boss",
		hp = 385,
		speed = 45,
		reward = 64,
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
		nameKey = "enemy.bossSummoner",
		hp = 341,
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
		nameKey = "enemy.bossDisplacement",
		hp = 385,
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
		nameKey = "enemy.bossSuppression",
		hp = 430,
		speed = 40,
		reward = 140,
		score = 500,
		radius = 20,
		boss = true,
		mechanicWeight = 1.65,
		mechanicPackage = "suppression_aura",
		suppression = {
			period = 20.0,
			duration = 5.0,
			initialDelay = 10.0,
			range = 240,
			projectileSpeed = 360,
		},
		traits = {"boss_suppression"},
	},

	-- New bosses keep the canonical 18px boss footprint; their identity comes
	-- from silhouette accents and one readable combat rule rather than size.
	boss_aegis = {
		nameKey = "enemy.bossAegis",
		hp = 430,
		speed = 43,
		reward = 128,
		score = 450,
		radius = 18,
		boss = true,
		mechanicWeight = 1.45,
		bossShield = { period = 6.0, duration = 2.0, initialDelay = 3.0, damageMultiplier = 0.45 },
		traits = {"boss_aegis"},
	},

	boss_ravager = {
		nameKey = "enemy.bossRavager",
		hp = 455,
		speed = 39,
		reward = 130,
		score = 470,
		radius = 18,
		boss = true,
		mechanicWeight = 1.4,
		enrage = { healthFraction = 0.45, speedMultiplier = 1.7 },
		traits = {"boss_ravager"},
	},
}
