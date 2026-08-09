local CampaignWaveDefs = require("systems.campaign_wave_defs")
local Difficulty = require("systems.difficulty")
local Maps = require("world.map_defs")
local State = require("core.state")
local L = require("core.localization")

local RunRecap = {}

function RunRecap.getReachedWave()
	return State.inPrep and math.max(1, State.wave - 1) or State.wave
end

function RunRecap.getMap()
	return Maps[State.worldMapIndex]
end

function RunRecap.getMapName()
	local map = RunRecap.getMap()
	return map and L(map.nameKey) or "--"
end

function RunRecap.getDifficultyLabel()
	return L("difficulty." .. RunRecap.getDifficultyKey())
end

function RunRecap.getDifficultyKey()
	return Difficulty.key()
end

function RunRecap.isLateWave(reachedWave)
	local map = RunRecap.getMap()
	local finalWave = CampaignWaveDefs.getFinalWave(map)
	if not finalWave then
		return false
	end

	return (reachedWave or RunRecap.getReachedWave()) >= finalWave * 0.75
end

return RunRecap
