local Difficulty = require("systems.difficulty")

local DifficultyCurve = {}

-- Campaign durability is a repeatable, local twenty-wave arc. Map progression is
-- deliberately shallow: Twin Loop (map 15) is 1.75x map one unless a designer
-- supplies an explicit hpScalar on a map definition.
DifficultyCurve.campaignEnd = 20
DifficultyCurve.campaignMidpoint = 10
DifficultyCurve.localStartHp = 1.0
-- Keep the opening wave approachable, then apply a steeper health ramp so each
-- new wave demands a more meaningful increase in tower damage.
DifficultyCurve.localMidHp = 3.5
DifficultyCurve.localEndHp = 5.25
DifficultyCurve.localExponent = 1.25
DifficultyCurve.mapIndexCap = 15
DifficultyCurve.finalMapHp = 1.75
DifficultyCurve.endlessHpCap = 48
DifficultyCurve.endlessSpeedCap = 1.75
DifficultyCurve.endlessRewardCap = 3.5

function DifficultyCurve.getEndlessScaling(waveIndex)
	local late = math.max(0, math.floor(tonumber(waveIndex) or 21) - DifficultyCurve.campaignEnd)
	-- Sub-linear, explicitly capped pressure prevents floating-point runaway while
	-- density is handled separately by the procedural composition budget.
	local root = math.sqrt(late)
	return {
		hp = math.min(DifficultyCurve.endlessHpCap, 1 + late * 0.115 + root * 0.16),
		speed = math.min(DifficultyCurve.endlessSpeedCap, 1 + late * 0.006),
		reward = math.min(DifficultyCurve.endlessRewardCap, 1 + root * 0.075),
		density = math.min(96, 38 + math.floor(root * 7)),
	}
end

function DifficultyCurve.getMapHpMultiplier(mapIndex, authoredScalar)
	if tonumber(authoredScalar) then return math.max(0.1, tonumber(authoredScalar)) end
	mapIndex = math.max(1, math.floor(tonumber(mapIndex) or 1))
	local progress = math.min(1, (mapIndex - 1) / (DifficultyCurve.mapIndexCap - 1))
	return 1 + (DifficultyCurve.finalMapHp - 1) * progress
end

function DifficultyCurve.getEnemyHpMultiplier(waveIndex, mapIndex, authoredScalar)
	waveIndex = math.max(1, math.floor(tonumber(waveIndex) or 1))
	local localWave = math.min(waveIndex, DifficultyCurve.campaignEnd)
	local localHp
	if localWave <= DifficultyCurve.campaignMidpoint then
		local progress = (localWave - 1) / (DifficultyCurve.campaignMidpoint - 1)
		localHp = DifficultyCurve.localStartHp
			+ (DifficultyCurve.localMidHp - DifficultyCurve.localStartHp)
				* (progress ^ DifficultyCurve.localExponent)
	else
		local progress = (localWave - DifficultyCurve.campaignMidpoint)
			/ (DifficultyCurve.campaignEnd - DifficultyCurve.campaignMidpoint)
		localHp = DifficultyCurve.localMidHp
			+ (DifficultyCurve.localEndHp - DifficultyCurve.localMidHp)
				* (progress ^ DifficultyCurve.localExponent)
	end
	local mapHp = DifficultyCurve.getMapHpMultiplier(mapIndex, authoredScalar)
	local endless = waveIndex > DifficultyCurve.campaignEnd and DifficultyCurve.getEndlessScaling(waveIndex).hp or 1
	return math.min(1e6, localHp * mapHp * Difficulty.get().enemyHpBias * endless)
end

function DifficultyCurve.getEnemySpeedMultiplier(waveIndex)
	local endless = (tonumber(waveIndex) or 1) > DifficultyCurve.campaignEnd
		and DifficultyCurve.getEndlessScaling(waveIndex).speed or 1
	return Difficulty.get().enemySpeedBias * endless
end

function DifficultyCurve.getBossHpMultiplier(waveIndex, mapIndex, authoredScalar)
	return Difficulty.get().bossHpBias
		* DifficultyCurve.getEnemyHpMultiplier(waveIndex, mapIndex, authoredScalar) * 0.9
end

return DifficultyCurve
