return {
	grunt = {
		nameKey = "enemy.grunt",
		hp = 42,
		speed = 70,
		reward = 6,
		score = 10,
		radius = 10,
	},

	tank = {
		nameKey = "enemy.tank",
		hp = 120,
		speed = 45,
		reward = 12,
		score = 22,
		radius = 12,
	},

	runner = {
		nameKey = "enemy.runner",
		hp = 28,
		speed = 95,
		reward = 6,
		score = 12,
		radius = 9,
	},

	splitter = {
		nameKey = "enemy.splitter",
		hp = 70,
		speed = 60,
		reward = 10,
		score = 18,
		radius = 11,
		split = {
			count = 2,
			child = "child",
			childHpMult = 0.6,
			childSpdMult = 1.1,
		}
	},

	child = {
		nameKey = "enemy.splitter",
		hp = 30,
		speed = 95,
		reward = 0,
		score = 12,
		radius = 9,
	},

	boss = {
		nameKey = "enemy.boss",
		hp = 2900,
		speed = 45,
		reward = 75,
		score = 300,
		radius = 18,
		boss = true,

		modifiers = {
			slow = 0.5, -- 50% slow effectiveness (movement speed)
		--	poison = 1.25, -- +25% poison damage taken
		}
	},
}