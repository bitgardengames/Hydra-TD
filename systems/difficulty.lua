local Difficulty = {}

Difficulty.defs = {
	easy = {
		key = "easy",

		-- Enemy baseline bias
		enemyHpBias = 0.75,
		enemySpeedBias = 0.95,
		bossHpBias = 0.75,

		-- Player affordances
		startMoney = 140,
		startLives = 25,
		sellRefund = 0.85,
	},

	normal = {
		key = "normal",

		enemyHpBias = 1.0,
		enemySpeedBias = 1.0,
		bossHpBias = 1.0,

		startMoney = 120,
		startLives = 20,
		sellRefund = 0.75,
	},

	hard = {
		key = "hard",

		enemyHpBias = 1.25,
		enemySpeedBias = 1.05,
		bossHpBias = 1.25,

		startMoney = 100,
		startLives = 15,
		sellRefund = 0.60,
	},
}

Difficulty.default = "normal"

local active = Difficulty.default

function Difficulty.set(key)
	if Difficulty.defs[key] then
		active = key
	else
		active = Difficulty.default
	end
end

function Difficulty.get()
	return Difficulty.defs[active] or Difficulty.defs[Difficulty.default]
end

function Difficulty.key()
	return active
end

return Difficulty