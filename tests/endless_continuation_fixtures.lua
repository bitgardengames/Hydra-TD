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

local GameplayOutcome = require("systems.gameplay_outcome")
assert(GameplayOutcome.continueIntoEndless(), "final-wave victory should continue into Endless")

assert(state.mode == "game" and state.endless, "the completed run should return to gameplay in Endless mode")
assert(not state.gameOver and not state.victory, "terminal campaign state should be cleared")
assert(state.wave == 21 and state.waveLeaks == 0, "Endless should await the wave after the campaign finale")
assert(state.activeBoss == nil and state.activeBossKind == nil, "campaign boss state should not carry forward")
assert(state.inPrep and state.speed == 1, "the next wave should await player start at normal speed")

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
