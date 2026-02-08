local Difficulty = require("systems.difficulty")

local DifficultyCurve = {}

-- Campaign tuning
DifficultyCurve.campaignEnd = 20
DifficultyCurve.campaignSlope = 0.12

-- Endless tuning
DifficultyCurve.endlessSlope = 0.12
DifficultyCurve.endlessExponent = 1.38

-- Boss scaling
DifficultyCurve.bossExponent = 1.20

-- Returns a monotonic difficulty scalar for a given wave index
function DifficultyCurve.getScalar(waveIndex)
	local d = Difficulty.get()

	if waveIndex <= DifficultyCurve.campaignEnd then
		return d.enemyHpBias * (1 + waveIndex * DifficultyCurve.campaignSlope)
	end

	local endlessWave = waveIndex - DifficultyCurve.campaignEnd

	local campaignScalar = d.enemyHpBias * (1 + DifficultyCurve.campaignEnd * DifficultyCurve.campaignSlope)

	return campaignScalar + (endlessWave ^ DifficultyCurve.endlessExponent) * DifficultyCurve.endlessSlope
end

-- Helpers
function DifficultyCurve.getEnemyHpMultiplier(waveIndex)
	return DifficultyCurve.getScalar(waveIndex)
end

function DifficultyCurve.getEnemySpeedMultiplier(waveIndex)
	return Difficulty.get().enemySpeedBias
end

function DifficultyCurve.getBossHpMultiplier(waveIndex)
	local d = Difficulty.get()
	local scalar = DifficultyCurve.getScalar(waveIndex)

	return d.bossHpBias * (scalar ^ DifficultyCurve.bossExponent)
end

return DifficultyCurve