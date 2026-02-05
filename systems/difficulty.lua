local Difficulty = {}

Difficulty.defs = {
	easy = {
		key = "easy",

		enemyHp = 0.75,
		enemySpeed = 0.95,

		bossHp = 0.75,

		startMoney = 140,
		startLives = 25,
		sellRefund = 0.85,
	},

	normal = {
		key = "normal",

		enemyHp = 1.0,
		enemySpeed = 1.0,

		bossHp = 1.0,

		startMoney = 120,
		startLives = 20,
		sellRefund = 0.75,
	},

	hard = {
		key = "hard",

		enemyHp = 1.25,
		enemySpeed = 1.05,

		bossHp = 1.25,

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