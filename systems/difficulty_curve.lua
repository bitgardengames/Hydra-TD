local Difficulty = require("systems.difficulty")

local DifficultyCurve = {}

-- Campaign tuning
DifficultyCurve.campaignEnd = 20
DifficultyCurve.campaignHpSlope = 0.86

-- Endless tuning
DifficultyCurve.endlessHpSlope = 1.20

-- Boss scaling
DifficultyCurve.bossExponent = 1.04

-- Enemy hp multiplier
function DifficultyCurve.getEnemyHpMultiplier(waveIndex)
	local d = Difficulty.get()

	local hpMult

	if waveIndex <= DifficultyCurve.campaignEnd then
		hpMult = 1 + waveIndex * DifficultyCurve.campaignHpSlope
	else
		local endlessWave = waveIndex - DifficultyCurve.campaignEnd
		local campaignHp = 1 + DifficultyCurve.campaignEnd * DifficultyCurve.campaignHpSlope

		hpMult = campaignHp + endlessWave * DifficultyCurve.endlessHpSlope
	end

	return hpMult * d.enemyHpBias
end

function DifficultyCurve.getEnemySpeedMultiplier(waveIndex)
	return Difficulty.get().enemySpeedBias
end

function DifficultyCurve.getBossHpMultiplier(waveIndex)
	local d = Difficulty.get()
	local hpMult = DifficultyCurve.getEnemyHpMultiplier(waveIndex)

	return d.bossHpBias * (hpMult ^ DifficultyCurve.bossExponent)
end

return DifficultyCurve