-- Dependency-free checks for the six authored chapter-four boss encounters.
-- Run from the repository root with: lua tests/chapter_four_boss_encounters_fixtures.lua
package.path = "./?.lua;./?/init.lua;" .. package.path

local Maps = require("world.map_defs")
local CampaignWaveDefs = require("systems.campaign_wave_defs")
local Resolver = require("systems.wave_resolver")

local expected = {
	frostgate = {"boss_aegis", "boss_phasewalker"},
	tidelock = {"boss_suppression", "boss_gatecrasher"},
	ashspiral = {"boss_ravager", "boss_phasewalker"},
}

local mapsById = {}
for _, map in ipairs(Maps) do mapsById[map.id] = map end

for mapId, pair in pairs(expected) do
	local map = assert(mapsById[mapId], "missing chapter-four map " .. mapId)
	for bossIndex, waveIndex in ipairs({10, 20}) do
		local wave = assert(CampaignWaveDefs.get(map, waveIndex))
		assert(wave.bossArchetype == pair[bossIndex],
			mapId .. " wave " .. waveIndex .. " must keep its explicit boss encounter")
	end
	assert(pair[1] ~= pair[2], mapId .. " must use two distinct boss archetypes")
end

local tidelock = mapsById.tidelock
local vanguard = assert(Resolver.resolveBossEncounterTemplate(tidelock, "boss_vanguard", 1))
assert(vanguard.flankKind == "runner" and vanguard.flankBurst == 3
	and vanguard.interval == 5.6 and vanguard.initialDelay == 2.2,
	"Tidelock's vanguard encounter must pressure its short return lanes")

local summoner = assert(Resolver.resolveBossEncounterTemplate(tidelock, "boss_summoner", 2))
assert(summoner.flankKind == "warcaller" and summoner.flankBurst == 2
	and summoner.interval == 6.4 and summoner.initialDelay == 3.0,
	"Tidelock's summoner encounter must test support target priority")

assert(Resolver.resolveBossEncounterTemplate(mapsById.frostgate, "boss_aegis", 1) == nil,
	"Frostgate's Aegis must rely on shield windows and its authored armored flank")
assert(Resolver.resolveBossEncounterTemplate(mapsById.ashspiral, "boss_ravager", 1) == nil,
	"Ash Spiral's Ravager must rely on its sprint and authored compressed flank")

print("chapter four boss encounter fixtures passed")
