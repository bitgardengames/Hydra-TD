local mult = 1

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

		modifiers = {
			--slow = 0.5, -- 50% slow effectiveness (movement speed)
			--poison = 1.25, -- +25% poison damage taken
		}
	},
}