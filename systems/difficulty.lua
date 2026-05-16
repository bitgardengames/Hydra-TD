local Difficulty = {}

local baseDef = {
	enemySpeedBias = 1.0,
	enemyHpBias = 1.0,
	bossHpBias = 1.0,
	rewardBias = 1.0,
	startMoney = 120,
	startLives = 20,
	sellRefund = 0.75,
}

local function makeDef(key, overrides)
	local def = { key = key }
	for k, v in pairs(baseDef) do
		def[k] = v
	end
	for k, v in pairs(overrides or {}) do
		def[k] = v
	end
	return def
end

Difficulty.defs = {
	easy = makeDef("easy", {
		enemyHpBias = 0.83,
		bossHpBias = 0.83,
		rewardBias = 1.05,
		startLives = 25,
		sellRefund = 0.85,
	}),

	normal = makeDef("normal", {
		enemyHpBias = 0.91,
		bossHpBias = 0.91,
	}),

	hard = makeDef("hard", {
		startLives = 15,
		sellRefund = 0.60,
	}),
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
