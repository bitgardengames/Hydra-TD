local Difficulty = require("systems.difficulty")

local DifficultyCurve = {}

-- Campaign tuning
DifficultyCurve.campaignEnd = 20
DifficultyCurve.campaignHpSlope = 1.03

-- Endless tuning (exponential base per wave)
DifficultyCurve.endlessHpBase = 1.15

-- Enemy hp multiplier
function DifficultyCurve.getEnemyHpMultiplier(waveIndex)
	local campaignHp = 1 + DifficultyCurve.campaignEnd * DifficultyCurve.campaignHpSlope
	local baseHp = (waveIndex <= DifficultyCurve.campaignEnd)
		and (1 + waveIndex * DifficultyCurve.campaignHpSlope)
		or (campaignHp * (DifficultyCurve.endlessHpBase ^ (waveIndex - DifficultyCurve.campaignEnd)))

	return baseHp * Difficulty.get().enemyHpBias
end

function DifficultyCurve.getEnemySpeedMultiplier(waveIndex)
	return Difficulty.get().enemySpeedBias
end

function DifficultyCurve.getBossHpMultiplier(waveIndex)
	return Difficulty.get().bossHpBias * DifficultyCurve.getEnemyHpMultiplier(waveIndex)
end

return DifficultyCurve