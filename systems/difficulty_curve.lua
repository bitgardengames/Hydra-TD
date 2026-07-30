local Difficulty = require("systems.difficulty")

local DifficultyCurve = {}

-- Campaign tuning
DifficultyCurve.campaignEnd = 20
DifficultyCurve.campaignHpSlope = 1.03

-- Count and composition become the primary endless levers. A small compound
-- step per five-wave tier keeps durability relevant without runaway HP.
DifficultyCurve.endlessHpPerTier = 1.12
DifficultyCurve.endlessHpPerWave = 0.018

-- Enemy hp multiplier
function DifficultyCurve.getEnemyHpMultiplier(waveIndex)
	local campaignHp = 1 + DifficultyCurve.campaignEnd * DifficultyCurve.campaignHpSlope
	local endlessWave = math.max(0, waveIndex - DifficultyCurve.campaignEnd)
	local tier = endlessWave > 0 and math.floor((endlessWave - 1) / 5) or 0
	local baseHp = (waveIndex <= DifficultyCurve.campaignEnd)
		and (1 + waveIndex * DifficultyCurve.campaignHpSlope)
		or (campaignHp * (DifficultyCurve.endlessHpPerTier ^ tier)
			* (1 + endlessWave * DifficultyCurve.endlessHpPerWave))

	return baseHp * Difficulty.get().enemyHpBias
end

function DifficultyCurve.getEnemySpeedMultiplier(waveIndex)
	return Difficulty.get().enemySpeedBias
end

function DifficultyCurve.getBossHpMultiplier(waveIndex)
	-- Boss danger comes from faster add cycles and larger encounters in Waves.
	return Difficulty.get().bossHpBias * DifficultyCurve.getEnemyHpMultiplier(waveIndex) * 0.9
end

return DifficultyCurve
