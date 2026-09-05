local CampaignWaveDefs = require("systems.campaign_wave_defs")
local DifficultyCurve = require("systems.difficulty_curve")
local Util = require("core.util")

local Resolver = {}

function Resolver.getWave(map, waveNumber)
	return CampaignWaveDefs.get(map, waveNumber)
end

local biomeBossArchetypes = {
	default = {"boss_summoner", "boss_vanguard", "boss_suppression", "boss_aegis", "boss_ravager", "boss_phasewalker", "boss_gatecrasher"},
	autumn = {"boss_vanguard", "boss_aegis", "boss_suppression", "boss_ravager", "boss_gatecrasher", "boss_phasewalker", "boss_summoner"},
	drylands = {"boss_suppression", "boss_ravager", "boss_vanguard", "boss_gatecrasher", "boss_phasewalker", "boss_aegis", "boss_summoner"},
	winter = {"boss_aegis", "boss_summoner", "boss_phasewalker", "boss_suppression", "boss_gatecrasher", "boss_ravager", "boss_vanguard"},
	highlands = {"boss_ravager", "boss_gatecrasher", "boss_phasewalker", "boss_vanguard", "boss_summoner", "boss_aegis", "boss_suppression"},
}
local mapBossOverrides = {
	roundabout = {[1] = "boss_vanguard", [2] = "boss_summoner"},
	gauntlet = {[1] = "boss_suppression", [2] = "boss_vanguard"},
	terrace = {[1] = "boss_summoner", [2] = "boss_suppression"},
}
local encounterTemplates = {
	boss_vanguard = {flankKind="runner", flankBurst=2, interval=6.5, initialDelay=3, maxAliveAdds=14, maxTotalAdds=26, addHpMult=.95, addSpdMult=1.15},
	boss_summoner = {flankKind="grunt", flankBurst=4, interval=5.8, initialDelay=2.4, maxAliveAdds=20, maxTotalAdds=34, addHpMult=.9, addSpdMult=1},
}
local biomeEncounterOverrides = {
	autumn = {boss_vanguard={flankBurst=3, interval=5.7, addSpdMult=1.2}, boss_summoner={flankBurst=5, interval=5, maxTotalAdds=38}},
	drylands = {boss_vanguard={initialDelay=2.3, maxAliveAdds=12}, boss_summoner={flankKind="runner", flankBurst=3, interval=6.8}},
	winter = {boss_vanguard={interval=7.4, addSpdMult=1.05}, boss_summoner={flankBurst=4, interval=6.2, addHpMult=1}},
	highlands = {boss_vanguard={flankKind="runner", flankBurst=2, interval=5.9}, boss_summoner={flankKind="runner", flankBurst=4, interval=5.4}},
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
	Util.copyNonNilInto(resolved, base)
	Util.copyNonNilInto(resolved, overrides and overrides[bossKind])
	Util.copyNonNilInto(resolved, mapEncounters and mapEncounters[bossKind])
	Util.copyNonNilInto(resolved, mapEncounters and mapEncounters[bossIndex])
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
		groups[i] = Util.shallowCopyInto({}, group)
		if group.kind == "boss" then
			groups[i].kind = wave.bossArchetype or Resolver.getBossByArchetype(map, bossIndex)
		end
	end
	return groups
end

return Resolver
