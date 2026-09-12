local CampaignWaveDefs = require("systems.campaign_wave_defs")
local DifficultyCurve = require("systems.difficulty_curve")
local Util = require("core.util")

local Resolver = {}

function Resolver.getWave(map, waveNumber)
	return CampaignWaveDefs.get(map, waveNumber)
end

local bossArchetypes = {
	"boss_summoner", "boss_suppression", "boss_ravager", "boss_phasewalker", "boss_gatecrasher",
}
local encounterTemplates = {
	boss_summoner = {flankKind="grunt", flankBurst=4, interval=5.8, initialDelay=2.4, maxAliveAdds=20, maxTotalAdds=34, addHpMult=0.9, addSpdMult=1},
}

function Resolver.getBossByArchetype(_, bossIndex)
	return bossArchetypes[((bossIndex - 1) % #bossArchetypes) + 1]
end

function Resolver.resolveBossEncounterTemplate(_, bossKind)
	local base = encounterTemplates[bossKind]
	if not base then return nil end
	local resolved = {}
	Util.copyNonNilInto(resolved, base)
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
