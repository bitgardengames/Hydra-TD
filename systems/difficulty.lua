local Difficulty = {}

-- Difficulty changes durability and economy only. Starting cash and enemy
-- behavior stay consistent so campaign progression has the same rules on every
-- difficulty.
Difficulty.defs = {
	easy = {
		key = "easy",

		-- Enemy baseline bias
		enemySpeedBias = 1.0,
		enemyHpBias = 1.0,
		bossHpBias = 1.0,

		-- Economy
		rewardBias = 1.05,
		-- A clean clear rounds to $2 before milestone and boss modifiers.
		perfectWaveBonus = 1.5,

		-- Player affordances
		startMoney = 120,
		startLives = 25,
		sellRefund = 0.85,
	},

	normal = {
		key = "normal",

		enemySpeedBias = 1.0,
		enemyHpBias = 1.1,
		bossHpBias = 1.05,

		rewardBias = 1.0,
		-- A visible $2 clean-clear reward cushions imperfect purchasing without
		-- replacing kills as the income floor.
		perfectWaveBonus = 1.5,

		-- Supports either two entry towers or one premium opening investment.
		startMoney = 120,
		startLives = 20,
		sellRefund = 0.75,
	},

	hard = {
		key = "hard",

		enemySpeedBias = 1.0,
		enemyHpBias = 1.2,
		bossHpBias = 1.25,

		rewardBias = 0.95,
		perfectWaveBonus = 1.25,

		startMoney = 120,
		startLives = 15,
		sellRefund = 0.60,
	},
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
