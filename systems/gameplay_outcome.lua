local State = require("core.state")
local Save = require("core.save")
local Maps = require("world.map_defs")
local Difficulty = require("systems.difficulty")
local Achievements = require("systems.achievements")
local Sound = require("systems.sound")
local L = require("core.localization")
local RunStats = require("systems.run_stats")
local RunModes = require("systems.run_modes")

local GameplayOutcome = {}

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
	local difficulty = Difficulty.key()
	local mode = RunModes.get(State)
	local result = RunStats.finish(completed and "completed" or "failed", State)
	State.runResult = result
	State.newRecords = Save.recordRun(map.id, mode, difficulty, result)
	if RunModes.awardsCampaignProgress(State) then
		Save.recordMapResult(map.id, difficulty, completed == true)
	end
	return true
end

function GameplayOutcome.cancel(reason)
	State.runResult = RunStats.finish(reason == "restart" and "restarted" or "abandoned", State)
	State.newRecords = {}
	return State.runResult
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
