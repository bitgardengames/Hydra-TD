local Difficulty = {}

Difficulty.defs = {
	easy = {
		key = "easy",

		-- Enemy baseline bias
		enemySpeedBias = 1.0,
		enemyHpBias = 0.91,
		bossHpBias = 0.91,

		-- Economy
		rewardBias = 1.05,

		-- Player affordances
		startMoney = 120,
		startLives = 25,
		sellRefund = 0.85,
	},

	normal = {
		key = "normal",

		enemySpeedBias = 1.0,
		enemyHpBias = 1.0,
		bossHpBias = 1.0,

		rewardBias = 1.0,

		startMoney = 120,
		startLives = 20,
		sellRefund = 0.75,
	},

	hard = {
		key = "hard",

		enemySpeedBias = 1.0,
		enemyHpBias = 1.1,
		bossHpBias = 1.1,

		rewardBias = 1.0,

		startMoney = 120,
		startLives = 15,
		sellRefund = 0.60,
	},

	--[[expert = {
		enemySpeedBias = 1.0,
		enemyHpBias = 1.09,
		bossHpBias = 1.09,

		rewardBias = 1.00,

		startMoney = 120,
		startLives = 10,
		sellRefund = 0.50,
	}]]
}

local default = "normal"
local active = default

function Difficulty.set(key)
	if Difficulty.defs[key] then
		active = key
	else
		active = default
	end
end

function Difficulty.get()
	return Difficulty.defs[active] or Difficulty.defs[default]
end

function Difficulty.key()
	return active
end

return Difficulty