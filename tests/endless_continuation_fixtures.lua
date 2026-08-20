-- Dependency-free regression fixture for continuing a final-wave victory.

local state = {
	mode = "victory",
	gameOver = true,
	victory = true,
	endless = false,
	wave = 20,
	waveLeaks = 0,
	activeBoss = {kind = "campaign_boss"},
	activeBossKind = "campaign_boss",
	inPrep = false,
	speed = 0.35,
}

local function module(name, value)
	package.loaded[name] = value
end

module("core.state", state)
module("core.save", {})
module("world.map_defs", {})
module("systems.difficulty", {})
module("systems.achievements", {})
module("systems.sound", {})
module("core.localization", {})
module("core.game_speed", {
	reset = function()
		state.speed = 1
	end,
})
module("systems.difficulty_curve", {campaignEnd = 10})
module("systems.campaign_wave_defs", {})

package.loaded["systems.wave_builder"] = nil
local WaveBuilder = require("systems.wave_builder")

-- Endless rules are selected by five-wave circuits, not incidental divisibility.
local first = WaveBuilder.getEndlessRules(11)
assert(first.id == "rapid_deployment" and first.milestoneNumber == 1,
	"the first circuit should announce Rapid Deployment")
assert(first.nextMilestoneWave == 15 and not first.milestone,
	"UI metadata should point at the explicit wave-15 milestone")
local firstAgain = WaveBuilder.getEndlessRules(11)
assert(firstAgain.id == first.id and firstAgain.nextMilestoneWave == first.nextMilestoneWave,
	"milestone selection must be deterministic")

local milestone = WaveBuilder.build(15, nil, true)
assert(milestone.boss and milestone.endlessRules.milestone,
	"every fifth Endless wave should be an explicit boss milestone")
assert(milestone.endlessRules.nameKey == "endless.rules.bossMilestone.name",
	"milestones should expose a localized UI-facing rule name")

local secondCircuit = WaveBuilder.build(16, nil, true)
assert(secondCircuit.endlessRules.id == "heavy_column",
	"the pressure rule should rotate after a milestone")
assert(secondCircuit.endlessRules.descriptionKey and secondCircuit.composition,
	"normal Endless waves should expose rule copy and a shared-roster composition")
for _, kind in ipairs(secondCircuit.composition) do
	assert(kind == "grunt" or kind == "runner" or kind == "tank" or kind == "bulwark"
		or kind == "regenerator" or kind == "warcaller" or kind == "summoner",
		"Endless must remix only campaign enemy kinds")
end

local GameplayOutcome = require("systems.gameplay_outcome")
assert(GameplayOutcome.continueIntoEndless(), "final-wave victory should continue into Endless")

assert(state.mode == "game" and state.endless, "the completed run should return to gameplay in Endless mode")
assert(not state.gameOver and not state.victory, "terminal campaign state should be cleared")
assert(state.wave == 21 and state.waveLeaks == 0, "Endless should await the wave after the campaign finale")
assert(state.activeBoss == nil and state.activeBossKind == nil, "campaign boss state should not carry forward")
assert(state.inPrep and state.speed == 1, "the next wave should await player start at normal speed")
assert(state.endlessRules.identityKey == "endless.identity",
	"continuation should surface the Milestone Circuit identity")
assert(state.endlessRules.ruleNameKey == "endless.rules.rapidDeployment.name"
	and state.endlessRules.nextMilestoneWave == 25,
	"continuation UI metadata should describe the active deterministic circuit")

local flawlessBonuses = 0
local presentations = {}

-- Model one gameplay-outcome update: completed-wave effects only run after a
-- started wave finishes. The continuation helper must leave the new wave in prep.
local function updateOutcome()
	if state.mode ~= "game" then return end
	if not state.inPrep then
		presentations[#presentations + 1] = "wave_cleared"
		if state.waveLeaks == 0 then
			flawlessBonuses = flawlessBonuses + 1
		end
	end
end

updateOutcome()
assert(flawlessBonuses == 0, "continuing must not award the final campaign wave twice")
assert(#presentations == 0, "continuing must not present wave_cleared for the final wave twice")
assert(state.wave == 21 and state.inPrep, "the next Endless wave should still await player start")

print("endless continuation fixtures passed")
