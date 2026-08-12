-- These are the actual wave-zero hit-point values. Wave and difficulty scaling
-- are applied once, at spawn time; literal values keep encounter budgets and
-- balance fixtures auditable without a hidden global multiplier. HP, shields,
-- and kill rewards use whole numbers so an authored count has a legible threat
-- and income budget in tools/balance/challenge_fixtures.py. Standard archetypes
-- pay $1 per three to five base effective durability, after mechanic weighting.

return {
	grunt = {
		nameKey = "enemy.grunt",
		hp = 15,
		speed = 70,
		reward = 5,
		score = 10,
		radius = 10,
	},

	tank = {
		nameKey = "enemy.tank",
		hp = 41,
		speed = 45,
		reward = 8,
		score = 22,
		radius = 12,
	},

	runner = {
		nameKey = "enemy.runner",
		hp = 12,
		speed = 95,
		reward = 4,
		score = 12,
		radius = 9,
		traits = {"fast"},
	},

	bulwark = {
		nameKey = "enemy.bulwark",
		descriptionKey = "enemy.bulwarkDescription",
		hp = 55, speed = 40, reward = 14, score = 30, radius = 14,
		armor = { flatReduction = 5, heavyMultiplier = 1.35, heavyThreshold = 14 },
		traits = {"armored"},
	},

	regenerator = {
		nameKey = "enemy.regenerator",
		descriptionKey = "enemy.regeneratorDescription",
		hp = 37, speed = 53, reward = 10, score = 28, radius = 12,
		regeneration = { hpPerSecond = 2.5, delay = 1.25 },
		modifiers = { poison = 1.25 },
		traits = {"regenerates"},
	},

	shieldbearer = {
		nameKey = "enemy.shieldbearer",
		descriptionKey = "enemy.shieldbearerDescription",
		hp = 37, speed = 50, reward = 13, score = 32, radius = 13,
		-- Chain amplification rewards Shock against the barrier without raising its
		-- raw damage against isolated, unshielded targets such as bosses.
		shield = { hp = 16, burstThreshold = 12, burstMultiplier = 1.6, chainMultiplier = 2.4 },
		traits = {"shielded"},
	},

	warcaller = {
		nameKey = "enemy.warcaller",
		descriptionKey = "enemy.warcallerDescription",
		hp = 37, speed = 48, reward = 10, score = 38, radius = 13,
		support = { radius = 92, speedMultiplier = 1.32, pulsePeriod = 1.2 },
		targetPriority = 34,
		traits = {"support"},
	},

	summoner = {
		nameKey = "enemy.summoner",
		descriptionKey = "enemy.summonerDescription",
		hp = 50, speed = 42, reward = 12, score = 44, radius = 14,
		summon = { kind = "runner", count = 2, period = 6.0, initialDelay = 2.5, spacing = 9 },
		targetPriority = 38,
		traits = {"summons"},
	},

	boss = {
		nameKey = "enemy.boss",
		hp = 330,
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
		hp = 290,
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
		hp = 330,
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
		hp = 360,
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
