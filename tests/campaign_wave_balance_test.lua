-- Static campaign balance fixture for the five Grunt-only teaching maps.
-- Each tuple records { authored enemy count, last-spawn time, Normal scaled HP }.
local CampaignWaveDefs = require("systems.campaign_wave_defs")
local DifficultyCurve = require("systems.difficulty_curve")
local EnemyDefs = require("world.enemy_defs")

local fixtures = {
	riverbend = {
		mapIndex = 1, bossKind = "boss_summoner", maxRuntimeAdds = 34,
		{8, 6.30, 120.00}, {12, 7.92, 187.16}, {18, 11.04, 295.54}, {20, 9.12, 347.11},
		{24, 9.89, 441.00}, {26, 10.85, 505.98}, {28, 9.92, 576.87}, {30, 9.35, 653.79},
		{32, 8.85, 736.86}, {35, 11.24, 1254.85},
	},
	switchback = {
		mapIndex = 2, bossKind = "boss_summoner", maxRuntimeAdds = 34,
		{10, 8.01, 158.04}, {14, 9.36, 230.05}, {21, 12.86, 363.27}, {22, 10.08, 402.28},
		{26, 10.75, 503.34}, {28, 11.69, 574.09}, {30, 10.66, 651.18}, {32, 10.05, 734.73},
		{34, 9.48, 824.85}, {37, 11.80, 1373.28},
	},
	highpass = {
		mapIndex = 3, bossKind = "boss_summoner", maxRuntimeAdds = 34,
		{12, 9.57, 199.29}, {16, 10.80, 276.28}, {24, 14.68, 436.27}, {24, 11.04, 461.16},
		{28, 11.61, 569.62}, {30, 12.53, 646.37}, {32, 11.40, 729.91}, {34, 10.75, 820.35},
		{36, 10.02, 917.78}, {39, 12.46, 1496.91},
	},
	roundabout = {
		mapIndex = 4, bossKind = "boss_displacement", maxRuntimeAdds = 26,
		{14, 11.05, 243.75}, {18, 12.24, 325.86}, {27, 16.50, 514.56}, {26, 12.00, 523.76},
		{30, 12.47, 639.84}, {32, 13.37, 722.82}, {34, 12.14, 813.06}, {36, 11.41, 910.63},
		{38, 10.61, 1015.65}, {41, 13.12, 1696.83},
	},
	gauntlet = {
		mapIndex = 5, bossKind = "boss_suppression", maxRuntimeAdds = 18,
		{16, 12.60, 291.43}, {20, 13.68, 378.77}, {30, 18.32, 598.12}, {28, 12.96, 590.09},
		{32, 13.33, 713.99}, {34, 14.21, 803.44}, {36, 12.88, 900.62}, {38, 12.11, 1005.58},
		{40, 11.24, 1118.44}, {43, 13.64, 1889.93},
	},
}

local ACTIVE_ENEMY_CAP = 140
local function near(actual, expected)
	return math.abs(actual - expected) < 0.011
end

local function measure(groups, mapIndex, waveIndex, bossKind)
	local count, duration, hp = 0, 0, 0
	local enemyHpMult = DifficultyCurve.getEnemyHpMultiplier(waveIndex, mapIndex)
	local bossHpMult = DifficultyCurve.getBossHpMultiplier(waveIndex, mapIndex)
	for groupIndex, group in ipairs(groups) do
		count = count + group.count
		duration = duration + math.max(0, group.count - 1) * group.spacing
		if groupIndex > 1 then duration = duration + group.delay end
		local kind = group.kind == "boss" and bossKind or group.kind
		local hpMult = group.kind == "boss" and bossHpMult or enemyHpMult
		hp = hp + EnemyDefs[kind].hp * group.count * hpMult
	end
	return count, duration, hp
end

for mapId, fixture in pairs(fixtures) do
	local measured = {}
	for waveIndex = 1, 10 do
		local groups = assert(CampaignWaveDefs.get(mapId, waveIndex), mapId .. " missing wave " .. waveIndex)
		local count, duration, hp = measure(groups, fixture.mapIndex, waveIndex, fixture.bossKind)
		measured[waveIndex] = {count, duration, hp}
		local expected = fixture[waveIndex]
		assert(count == expected[1], string.format("%s wave %d count: %d ~= %d", mapId, waveIndex, count, expected[1]))
		assert(near(duration, expected[2]), string.format("%s wave %d duration: %.2f ~= %.2f", mapId, waveIndex, duration, expected[2]))
		assert(near(hp, expected[3]), string.format("%s wave %d scaled HP: %.2f ~= %.2f", mapId, waveIndex, hp, expected[3]))

		if waveIndex <= 9 then
			for _, group in ipairs(groups) do
				assert(group.kind == "grunt", string.format("%s introduces %s before Tank availability", mapId, group.kind))
			end
		end
	end

	local wave5 = measured[5]
	for waveIndex = 6, 9 do
		local wave = CampaignWaveDefs.get(mapId, waveIndex)
		-- A deliberate exception must live on the wave table, alongside the budget it changes.
		if not wave.encounterBudgetReason then
			local value = measured[waveIndex]
			assert(value[1] >= wave5[1] * 0.90, mapId .. " late-wave count regressed sharply")
			assert(value[2] >= wave5[2] * 0.80, mapId .. " late-wave spawn duration regressed sharply")
			assert(value[3] >= wave5[3] * 0.90, mapId .. " late-wave scaled HP regressed sharply")
		end
	end

	assert(#CampaignWaveDefs.get(mapId, 6) >= 2, mapId .. " wave 6 needs a stream plus staggered pack")
	assert(#CampaignWaveDefs.get(mapId, 8) >= 3 and #CampaignWaveDefs.get(mapId, 9) >= 3,
		mapId .. " density checks need overlapping pack cadence")
	local finalGroups = CampaignWaveDefs.get(mapId, 10)
	assert(finalGroups[1].kind == "boss" and #finalGroups >= 4, mapId .. " final needs boss plus three-part escort")
	assert(measured[10][1] + fixture.maxRuntimeAdds <= ACTIVE_ENEMY_CAP,
		mapId .. " authored escort plus runtime reinforcements exceeds active cap")
end
