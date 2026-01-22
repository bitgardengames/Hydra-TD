local Difficulty = {}

Difficulty.defs = {
	easy = {
		key = "easy",

		enemyHp = 0.85,
		enemySpeed = 0.90,

		bossHp = 0.85,
		bossAdds = 0.80,

		startMoney = 140,
		startLives = 25,
		sellRefund = 0.85,
	},

	normal = {
		key = "normal",

		enemyHp = 1.0,
		enemySpeed = 1.0,

		bossHp = 1.0,
		bossAdds = 1.0,

		startMoney = 120,
		startLives = 20,
		sellRefund = 0.75,
	},

	hard = {
		key = "hard",

		enemyHp = 1.15,
		enemySpeed = 1.10,

		bossHp = 1.15,
		bossAdds = 1.20,

		startMoney = 110,
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