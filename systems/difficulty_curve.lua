local Difficulty = require("systems.difficulty")

local DifficultyCurve = {}

-- Campaign tuning
DifficultyCurve.campaignEnd = 20
DifficultyCurve.campaignHpSlope = 0.97

-- Endless tuning (exponential base per wave)
DifficultyCurve.endlessHpBase = 1.055 -- 1.05 = gentle, 1.07 = aggressive

-- Enemy hp multiplier
function DifficultyCurve.getEnemyHpMultiplier(waveIndex)
	local d = Difficulty.get()

	local hpMult

	if waveIndex <= DifficultyCurve.campaignEnd then
		hpMult = 1 + waveIndex * DifficultyCurve.campaignHpSlope
	else
		local endlessWave = waveIndex - DifficultyCurve.campaignEnd
		local campaignHp = 1 + DifficultyCurve.campaignEnd * DifficultyCurve.campaignHpSlope

		hpMult = campaignHp * (DifficultyCurve.endlessHpBase ^ endlessWave)
	end

	return hpMult * d.enemyHpBias
end

function DifficultyCurve.getEnemySpeedMultiplier(waveIndex)
	return Difficulty.get().enemySpeedBias
end

function DifficultyCurve.getBossHpMultiplier(waveIndex)
	local d = Difficulty.get()
	local hpMult = DifficultyCurve.getEnemyHpMultiplier(waveIndex)

	return d.bossHpBias * hpMult
end

return DifficultyCurve