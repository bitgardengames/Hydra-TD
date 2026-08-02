local State = require("core.state")
local Steam = require("core.steam")
local Save = require("core.save")
local AchievementDefs = require("systems.achievement_defs")
local RunStats = require("systems.run_stats")

local Achievements = {}

local watchers = {}

local BASE_CAMPAIGN_MAP_IDS = {
	"riverbend",
	"switchback",
	"highpass",
	"roundabout",
	"gauntlet",
	"snaketrail",
	"backtrack",
	"lowvalley",
	"circuit",
	"outerloop",
	"terrace",
	"highridge",
	"crossflow",
	"steppingstones",
	"twinloop",
}

local rank = {
	easy = 1,
	normal = 2,
	hard = 3,
}

local function unlock(id)
	local meta = Save.data.meta

	if meta.unlockedAchievements[id] then
		return
	end

	meta.unlockedAchievements[id] = true

	if Steam.loaded then
		Steam.unlockAchievement(id)
	end

	Save.flush()
end

local function isDifficultyAtLeast(completedDifficulty, targetDifficulty)
	return (rank[completedDifficulty] or 0) >= (rank[targetDifficulty] or 0)
end

local function countCompletedBaseCampaignMaps(targetDifficulty)
	local mapStats = Save.data.mapStats or {}
	local count = 0

	for i = 1, #BASE_CAMPAIGN_MAP_IDS do
		local mapId = BASE_CAMPAIGN_MAP_IDS[i]
		local stats = mapStats[mapId]

		if stats and isDifficultyAtLeast(stats.completedDifficulty, targetDifficulty) then
			count = count + 1
		end
	end

	return count
end

local function hasCompletedBaseCampaign(targetDifficulty)
	return countCompletedBaseCampaignMaps(targetDifficulty) == #BASE_CAMPAIGN_MAP_IDS
end

function Achievements.checkCampaignCompletion()
	if State.ignoreStats or not Save.data then
		return
	end

	if hasCompletedBaseCampaign("easy") then
		unlock("CAMPAIGN_EASY")
	end

	if hasCompletedBaseCampaign("normal") then
		unlock("CAMPAIGN_NORMAL")
	end

	if hasCompletedBaseCampaign("hard") then
		unlock("CAMPAIGN_HARD")
	end
end

-- Build cumulative watchers from the same catalog displayed by the UI.
for _, def in ipairs(AchievementDefs) do
	if def.stat and def.target then
		watchers[def.stat] = watchers[def.stat] or {}
		watchers[def.stat][#watchers[def.stat] + 1] = def
	end
end

function Achievements.increment(stat, amount)
	if State.ignoreStats then
		return
	end

	amount = amount or 1

	local meta = Save.data.meta
	meta[stat] = (meta[stat] or 0) + amount

	local definitions = watchers[stat]

	if definitions then
		for _, def in ipairs(definitions) do
			if meta[stat] >= def.target then
				unlock(def.id)
			end
		end
	end
end

function Achievements.onGameOver()
	Achievements.checkCampaignCompletion()
	RunStats.commitTowerHistory()
	Save.flush()
end

function Achievements.unlock(id)
	unlock(id)
end

return Achievements
