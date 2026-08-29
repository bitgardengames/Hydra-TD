local CampaignWaveDefs = require("systems.campaign_wave_defs")
local DifficultyCurve = require("systems.difficulty_curve")

local Resolver = {}

local endlessRoster = {"grunt", "runner", "tank", "bulwark", "regenerator", "warcaller"}

function Resolver.seededValue(seed, wave, slot)
	local n = (math.floor(tonumber(seed) or 1) % 2147483647 + wave * 48271 + slot * 69621) % 2147483647
	n = (n * 16807) % 2147483647
	return n
end

function Resolver.generateEndlessWave(waveNumber, seed)
	waveNumber = math.max(21, math.floor(tonumber(waveNumber) or 21))
	local scaling = DifficultyCurve.getEndlessScaling(waveNumber)
	local boss = waveNumber % 10 == 0
	local groupCount = boss and 4 or (2 + Resolver.seededValue(seed, waveNumber, 1) % 3)
	local remaining, groups = scaling.density, {}
	if boss then
		groups[1] = {kind = "boss", count = 1, spacing = 0, delay = 0}
		remaining = remaining - 1
	end
	for slot = #groups + 1, groupCount do
		local slotsLeft = groupCount - slot + 1
		local count = slot == groupCount and remaining
			or math.max(4, math.floor(remaining / slotsLeft) + (Resolver.seededValue(seed, waveNumber, slot) % 7) - 3)
		count = math.min(count, remaining - (slotsLeft - 1) * 4, 40)
		local elite = waveNumber % 5 == 0 and slot == (boss and 2 or 1)
		groups[#groups + 1] = {
			kind = endlessRoster[(Resolver.seededValue(seed, waveNumber, slot + 9) % #endlessRoster) + 1],
			count = count, spacing = math.max(0.16, 0.48 - (waveNumber - 20) * 0.002),
			delay = slot == 1 and 0 or 0.35, eliteTrait = elite and "veteran" or nil,
			hpMult = elite and 1.65 or nil, spdMult = elite and 1.12 or nil,
			rewardMult = scaling.reward,
		}
		remaining = remaining - count
	end
	local count = 0
	for _, group in ipairs(groups) do count = count + group.count end
	return {boss = boss, count = count, groups = groups, procedural = true}
end

function Resolver.getWave(map, waveNumber, endless, seed)
	if endless and waveNumber > DifficultyCurve.campaignEnd then
		return Resolver.generateEndlessWave(waveNumber, seed)
	end
	return CampaignWaveDefs.get(map, waveNumber)
end

local biomeBossArchetypes = {
	default = {"boss_summoner", "boss_displacement", "boss_suppression", "boss_aegis", "boss_ravager"},
	autumn = {"boss_displacement", "boss_aegis", "boss_suppression", "boss_ravager", "boss_summoner"},
	drylands = {"boss_suppression", "boss_ravager", "boss_displacement", "boss_aegis", "boss_summoner"},
	winter = {"boss_aegis", "boss_summoner", "boss_suppression", "boss_ravager", "boss_displacement"},
	highlands = {"boss_ravager", "boss_displacement", "boss_summoner", "boss_aegis", "boss_suppression"},
}
local mapBossOverrides = {
	roundabout = {[1] = "boss_displacement", [2] = "boss_summoner"},
	gauntlet = {[1] = "boss_suppression", [2] = "boss_displacement"},
	terrace = {[1] = "boss_summoner", [2] = "boss_suppression"},
}
local encounterTemplates = {
	boss_displacement = {flankKind="runner", flankBurst=2, interval=6.5, initialDelay=3, maxAliveAdds=14, maxTotalAdds=26, addHpMult=.95, addSpdMult=1.15},
	boss_summoner = {flankKind="grunt", flankBurst=4, interval=5.8, initialDelay=2.4, maxAliveAdds=20, maxTotalAdds=34, addHpMult=.9, addSpdMult=1},
}
local biomeEncounterOverrides = {
	autumn = {boss_displacement={flankBurst=3, interval=5.7, addSpdMult=1.2}, boss_summoner={flankBurst=5, interval=5, maxTotalAdds=38}},
	drylands = {boss_displacement={initialDelay=2.3, maxAliveAdds=12}, boss_summoner={flankKind="runner", flankBurst=3, interval=6.8}},
	winter = {boss_displacement={interval=7.4, addSpdMult=1.05}, boss_summoner={flankBurst=4, interval=6.2, addHpMult=1}},
	highlands = {boss_displacement={flankKind="runner", flankBurst=2, interval=5.9}, boss_summoner={flankKind="runner", flankBurst=4, interval=5.4}},
}

function Resolver.getBossByArchetype(map, bossIndex)
	local override = map and mapBossOverrides[map.id]
	if override and override[bossIndex] then return override[bossIndex] end
	local roster = biomeBossArchetypes[(map and map.biome) or "default"] or biomeBossArchetypes.default
	return roster[((bossIndex - 1) % #roster) + 1]
end

function Resolver.resolveBossEncounterTemplate(map, bossKind, bossIndex)
	local base = encounterTemplates[bossKind]
	if not base then return nil end
	local overrides = biomeEncounterOverrides[(map and map.biome) or "default"]
	local mapEncounters = map and map.waves and map.waves.encounters
	local resolved = {}
	local function merge(layer)
		for key, value in pairs(layer or {}) do
			if value ~= nil then resolved[key] = value end
		end
	end
	merge(base)
	merge(overrides and overrides[bossKind])
	merge(mapEncounters and mapEncounters[bossKind])
	merge(mapEncounters and mapEncounters[bossIndex])
	return resolved
end

function Resolver.getWaveMultipliers(waveNumber, mapIndex, map, isBoss)
	local scalar = map and map.hpScalar
	local hp = isBoss and DifficultyCurve.getBossHpMultiplier(waveNumber, mapIndex, scalar)
		or DifficultyCurve.getEnemyHpMultiplier(waveNumber, mapIndex, scalar)
	return hp, DifficultyCurve.getEnemySpeedMultiplier(waveNumber)
end

function Resolver.resolveWaveGroups(wave, map, waveNumber)
	if not wave.groups then return nil end
	local bossIndex = math.max(1, math.floor(waveNumber / 10))
	local groups = {}
	for i, group in ipairs(wave.groups) do
		groups[i] = {}
		for key, value in pairs(group) do groups[i][key] = value end
		if group.kind == "boss" then
			groups[i].kind = wave.bossArchetype or Resolver.getBossByArchetype(map, bossIndex)
		end
	end
	return groups
end

return Resolver
