local Difficulty = require("systems.difficulty")

local DifficultyCurve = {}

-- Campaign durability is a repeatable, local ten-wave arc. Map progression is
-- deliberately shallow: Twin Loop (map 15) is 1.75x map one unless a designer
-- supplies an explicit hpScalar on a map definition.
DifficultyCurve.campaignEnd = 10
DifficultyCurve.localStartHp = 1.0
DifficultyCurve.localEndHp = 1.62
DifficultyCurve.localExponent = 1.25
DifficultyCurve.mapIndexCap = 15
DifficultyCurve.finalMapHp = 1.75

function DifficultyCurve.getMapHpMultiplier(mapIndex, authoredScalar)
	if tonumber(authoredScalar) then return math.max(0.1, tonumber(authoredScalar)) end
	mapIndex = math.max(1, math.floor(tonumber(mapIndex) or 1))
	local progress = math.min(1, (mapIndex - 1) / (DifficultyCurve.mapIndexCap - 1))
	return 1 + (DifficultyCurve.finalMapHp - 1) * progress
end

function DifficultyCurve.getEnemyHpMultiplier(waveIndex, mapIndex, authoredScalar)
	waveIndex = math.max(1, math.floor(tonumber(waveIndex) or 1))
	local localWave = math.min(waveIndex, DifficultyCurve.campaignEnd)
	local progress = (localWave - 1) / (DifficultyCurve.campaignEnd - 1)
	local localHp = DifficultyCurve.localStartHp
		+ (DifficultyCurve.localEndHp - DifficultyCurve.localStartHp)
			* (progress ^ DifficultyCurve.localExponent)
	local mapHp = DifficultyCurve.getMapHpMultiplier(mapIndex, authoredScalar)
	return localHp * mapHp * Difficulty.get().enemyHpBias
end

function DifficultyCurve.getEnemySpeedMultiplier(_waveIndex)
	return Difficulty.get().enemySpeedBias
end

function DifficultyCurve.getBossHpMultiplier(waveIndex, mapIndex, authoredScalar)
	return Difficulty.get().bossHpBias
		* DifficultyCurve.getEnemyHpMultiplier(waveIndex, mapIndex, authoredScalar) * 0.9
end

return DifficultyCurve
