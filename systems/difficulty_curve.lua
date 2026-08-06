local Difficulty = require("systems.difficulty")

local DifficultyCurve = {}

-- Each authored map is a complete ten-wave arc. Durability starts at the
-- literal enemy definition on wave one and eases upward to the final exam.
DifficultyCurve.campaignEnd = 10
DifficultyCurve.campaignStartHp = 1.0
DifficultyCurve.campaignEndHp = 3.25
DifficultyCurve.campaignExponent = 1.35

-- Count and composition become the primary endless levers. A small compound
-- step per five-wave tier keeps durability relevant without runaway HP.
DifficultyCurve.endlessHpPerTier = 1.12
DifficultyCurve.endlessHpPerWave = 0.018

function DifficultyCurve.getEnemyHpMultiplier(waveIndex)
	waveIndex = math.max(1, tonumber(waveIndex) or 1)
	local endlessWave = math.max(0, waveIndex - DifficultyCurve.campaignEnd)
	local tier = endlessWave > 0 and math.floor((endlessWave - 1) / 5) or 0
	local progress = math.min(1, (waveIndex - 1) / (DifficultyCurve.campaignEnd - 1))
	local campaignHp = DifficultyCurve.campaignStartHp
		+ (DifficultyCurve.campaignEndHp - DifficultyCurve.campaignStartHp)
			* (progress ^ DifficultyCurve.campaignExponent)
	local baseHp = waveIndex <= DifficultyCurve.campaignEnd and campaignHp
		or (DifficultyCurve.campaignEndHp * (DifficultyCurve.endlessHpPerTier ^ tier)
			* (1 + endlessWave * DifficultyCurve.endlessHpPerWave))

	return baseHp * Difficulty.get().enemyHpBias
end

function DifficultyCurve.getEnemySpeedMultiplier(_waveIndex)
	return Difficulty.get().enemySpeedBias
end

function DifficultyCurve.getBossHpMultiplier(waveIndex)
	-- Boss danger comes from faster add cycles and larger encounters in Waves.
	return Difficulty.get().bossHpBias * DifficultyCurve.getEnemyHpMultiplier(waveIndex) * 0.9
end

return DifficultyCurve
