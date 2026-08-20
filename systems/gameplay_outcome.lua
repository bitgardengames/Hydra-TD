local State = require("core.state")
local Save = require("core.save")
local Maps = require("world.map_defs")
local Difficulty = require("systems.difficulty")
local Achievements = require("systems.achievements")
local Sound = require("systems.sound")
local L = require("core.localization")
local GameSpeed = require("core.game_speed")
local WaveBuilder = require("systems.wave_builder")

local GameplayOutcome = {}

-- Player-facing contract for the retained Endless mode. Keeping this beside
-- continuation makes the victory screen and transition use the same rules as waves.
function GameplayOutcome.getEndlessContinuationMetadata(nextWave)
	local rules = WaveBuilder.getEndlessRules(nextWave or (State.wave + 1))
	return {
		identityKey = "endless.identity",
		ruleNameKey = rules.nameKey,
		ruleDescriptionKey = rules.descriptionKey,
		nextMilestoneWave = rules.nextMilestoneWave,
		milestoneNumber = rules.milestoneNumber,
	}
end

function GameplayOutcome.continueIntoEndless()
	if not (State.gameOver and State.victory) then
		return false
	end

	State.gameOver = false
	State.victory = false
	State.endless = true
	State.wave = State.wave + 1
	State.endlessRules = GameplayOutcome.getEndlessContinuationMetadata(State.wave)
	State.waveLeaks = 0
	State.activeBoss = nil
	State.activeBossKind = nil
	State.inPrep = true
	GameSpeed.reset()
	State.mode = "game"
	return true
end

function GameplayOutcome.recordCurrentRun(completed)
	if State.ignoreStats then
		return false
	end

	local map = Maps[State.worldMapIndex]
	if not map then
		return false
	end

	local stats = Save.data.mapStats[map.id]
	State.previousCompletionDifficulty = stats and stats.completedDifficulty or nil
	Save.recordMapResult(map.id, Difficulty.key(), completed == true)
	return true
end

function GameplayOutcome.defeat(reason)
	-- Enemy movement and the post-simulation outcome check may observe the same
	-- leak. Only the first observer is allowed to finalize and navigate.
	if State.gameOver then
		return false
	end

	State.lives = 0
	State.gameOver = true
	State.victory = false
	State.endT = 0
	State.endReady = false
	State.endTitle = L("game.gameOver")
	State.endReason = reason or L("game.outOfLives")

	Achievements.onGameOver()
	GameplayOutcome.recordCurrentRun(false)
	Sound.play("gameOver")
	Sound.playMusic("gameOver")
	-- Keep this dependency lazy: enemies load before the menu, while several menu
	-- dependencies refer back to enemies during application bootstrap.
	require("ui.menu.menu").set("game_over")
	return true
end

return GameplayOutcome
