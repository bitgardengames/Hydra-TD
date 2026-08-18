-- Dependency-free defeat transition fixtures. Run from the repository root with Lua/LuaJIT.

local sourceFiles = {
	main = "main.lua",
	enemies = "world/enemies.lua",
}

local function read(path)
	local file = assert(io.open(path, "r"))
	local contents = file:read("*a")
	file:close()
	return contents
end

local mainSource = read(sourceFiles.main)
local enemiesSource = read(sourceFiles.enemies)
assert(mainSource:find('GameplayOutcome.defeat(L("game.outOfLives"))', 1, true),
	"normal out-of-lives handling should use the shared defeat transition")
for _, reset in ipairs({
	"State.endT = 0",
	"State.endReady = false",
	"State.endTitle = nil",
	"State.endReason = nil",
	"State.previousCompletionDifficulty = nil",
	"State.wasFirstClear = false",
	"State.unlockedTowersThisVictory = {}",
	"State.unlockedRewardsThisVictory = {}",
	"State.unlockedAbilitiesThisVictory = {}",
}) do
	assert(mainSource:find(reset, 1, true), "resetGame should clear run outcome state: " .. reset)
end
assert(enemiesSource:find('beginGameOver(L("game.bossBreach"))', 1, true),
	"a boss breach should retain its specific defeat cause")
assert(enemiesSource:find("GameplayOutcome.defeat(reason)", 1, true),
	"enemy defeat causes should route through the shared transition")
assert(not mainSource:find('State.mode = "game_over"', 1, true),
	"main must not bypass the game-over screen lifecycle")
assert(not enemiesSource:find('State.mode = "game_over"', 1, true),
	"enemies must not bypass the game-over screen lifecycle")

local state = {
	mode = "game",
	lives = 1,
	gameOver = false,
	victory = true,
	worldMapIndex = 1,
}
local recordCalls = 0
local achievementCalls = 0
local enterCalls = 0
local recap = {}
local playedSounds = {}
local playedMusic = {}

local function module(name, value)
	package.loaded[name] = value
end

module("core.state", state)
module("core.save", {
	data = {mapStats = {riverbend = {completedDifficulty = "normal"}}},
	recordMapResult = function(mapId, difficulty, completed)
		recordCalls = recordCalls + 1
		assert(mapId == "riverbend" and difficulty == "hard" and completed == false,
			"defeat should record the current map, difficulty, and failed result")
	end,
})
module("world.map_defs", {{id = "riverbend"}})
module("systems.difficulty", {key = function() return "hard" end})
module("systems.achievements", {onGameOver = function() achievementCalls = achievementCalls + 1 end})
module("systems.sound", {
	play = function(name) playedSounds[#playedSounds + 1] = name end,
	playMusic = function(name) playedMusic[#playedMusic + 1] = name end,
})
module("core.localization", setmetatable({}, {
	__call = function(_, key) return key end,
}))
module("ui.menu.menu", {
	set = function(mode)
		state.mode = mode
		enterCalls = enterCalls + 1
		-- Model Screen.enter rebuilding data from the just-finalized state.
		recap = {
			reason = state.endReason,
			lives = state.lives,
			gameOver = state.gameOver,
			rewards = state.unlockedRewardsThisVictory,
			previousCompletionDifficulty = state.previousCompletionDifficulty,
		}
	end,
})

local GameplayOutcome = require("systems.gameplay_outcome")
local causes = {"game.outOfLives", "game.bossBreach"}

for _, cause in ipairs(causes) do
	state.mode = "game"
	state.lives = 1
	state.gameOver = false
	state.victory = true
	recap = {stale = true}

	assert(GameplayOutcome.defeat(cause), "the first defeat transition should run")
	assert(state.mode == "game_over" and state.gameOver and not state.victory,
		"defeat should establish the terminal state")
	assert(state.endReason == cause and recap.reason == cause and recap.stale == nil,
		"Screen.enter data should be rebuilt with the current defeat cause")
	assert(recap.lives == 0 and recap.gameOver,
		"the rebuilt run recap should contain finalized defeat state")
	assert(playedSounds[#playedSounds] == "gameOver" and playedMusic[#playedMusic] == "gameOver",
		"defeat should select both the game-over sound and music")

	assert(not GameplayOutcome.defeat(cause), "re-observing a defeat must be a no-op")
end

assert(recordCalls == #causes, "failed-run bookkeeping should occur once per run")
assert(achievementCalls == #causes, "achievement finalization should occur once per run")
assert(enterCalls == #causes, "Screen.enter should run once per defeat transition")

-- Reproduce the regression sequence: a boss defeat leaves boss-specific recap
-- data, the player restarts, and ordinary leaks end the new run. These are the
-- outcome fields resetGame clears before gameplay resumes.
state.endReason = "game.bossBreach"
state.previousCompletionDifficulty = "normal"
state.wasFirstClear = true
state.unlockedTowersThisVictory = {"cannon"}
state.unlockedRewardsThisVictory = {{type = "ability", id = "meteor"}}
state.unlockedAbilitiesThisVictory = {"meteor"}

state.mode = "game"
state.lives = 1
state.gameOver = false
state.victory = false
state.endT = 0
state.endReady = false
state.endTitle = nil
state.endReason = nil
state.previousCompletionDifficulty = nil
state.wasFirstClear = false
state.unlockedTowersThisVictory = {}
state.unlockedRewardsThisVictory = {}
state.unlockedAbilitiesThisVictory = {}

assert(GameplayOutcome.defeat("game.outOfLives"), "normal leaks should end the restarted run")
assert(recap.reason == "game.outOfLives" and recap.reason ~= "game.bossBreach",
	"the second recap should contain current generic defeat copy, not the prior boss reason")
assert(#recap.rewards == 0 and recap.previousCompletionDifficulty == nil,
	"the second recap should not retain rewards or completion data from the previous run")
assert(#state.unlockedTowersThisVictory == 0 and #state.unlockedAbilitiesThisVictory == 0,
	"the restarted run should not retain victory unlock collections")

print("defeat transition fixtures passed")
