local Difficulty = {}

Difficulty.defs = {
	easy = {
		key = "easy",

		-- Enemy baseline bias
		enemyPressureBias = 0.85,
		enemySpeedBias = 1.0,
		enemyHpBias = 0.85,
		bossHpBias = 0.85,

		-- Player affordances
		startMoney = 120,
		startLives = 25,
		sellRefund = 0.85,
	},

	normal = {
		key = "normal",

		enemyPressureBias = 0.93,
		enemySpeedBias = 1.0,
		enemyHpBias = 0.93,
		bossHpBias = 0.93,

		startMoney = 120,
		startLives = 20,
		sellRefund = 0.75,
	},

	hard = {
		key = "hard",

		enemyPressureBias = 1.0,
		enemySpeedBias = 1.0,
		enemyHpBias = 1.07,
		bossHpBias = 1.07,

		startMoney = 120,
		startLives = 15,
		sellRefund = 0.60,
	},

	--[[expert = {
		enemyPressureBias = 1.08,
		enemySpeedBias = 1.0,
		enemyHpBias = 1.12,
		bossHpBias = 1.12,

		startMoney = 120,
		startLives = 10,
		sellRefund = 0.50,
	}]]
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