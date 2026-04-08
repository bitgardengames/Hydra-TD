local State = require("core.state")
local Steam = require("core.steam")
local Save = require("core.save")

local Achievements = {}

local watchers = {}

--[[
	List of achievements

	BOSS_KILL_1, BOSS_KILL_25
	ENEMY_KILL_500, ENEMY_KILL_1500, ENEMY_KILL_3000
	TOWER_LANCER_250, TOWER_SLOW_250, TOWER_CANNON_250, TOWER_SHOCK_250, TOWER_POISON_250, TOWER_PLASMA_250
	TOWER_LANCER_1000, TOWER_SLOW_1000, TOWER_CANNON_1000, TOWER_SHOCK_1000, TOWER_POISON_1000, TOWER_PLASMA_1000
	CAMPAIGN_EASY, CAMPAIGN_NORMAL, CAMPAIGN_HARD
	NO_LEAKS_NORMAL, NO_LEAKS_HARD
	TOWER_UPGRADE_1, TOWER_UPGRADE_100
	LAST_SECOND
--]]

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

local HIGHLANDS_CAMPAIGN_MAP_IDS = { -- NYI, Just for ideas
	"ashfall",
	"cliffside",
	"forkriver",
	"stormpass",
	"ironvale",
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

-- Enemy kills
watchers.ENEMIES_KILLED = function(value)
	if value >= 3000 then unlock("ENEMY_KILL_3000") end
	if value >= 1500 then unlock("ENEMY_KILL_1500") end
	if value >= 500 then unlock("ENEMY_KILL_500") end
end

-- Boss kills
watchers.BOSSES_KILLED = function(value)
	if value >= 25 then unlock("BOSS_KILL_25") end
	if value >= 1 then unlock("BOSS_KILL_1") end
end

-- Tower kills
watchers.TOWER_LANCER_KILLS = function(value)
	if value >= 1000 then unlock("TOWER_LANCER_1000") end
	if value >= 250 then unlock("TOWER_LANCER_250") end
end

watchers.TOWER_SLOW_KILLS = function(value)
	if value >= 1000 then unlock("TOWER_SLOW_1000") end
	if value >= 250 then unlock("TOWER_SLOW_250") end
end

watchers.TOWER_CANNON_KILLS = function(value)
	if value >= 1000 then unlock("TOWER_CANNON_1000") end
	if value >= 250 then unlock("TOWER_CANNON_250") end
end

watchers.TOWER_SHOCK_KILLS = function(value)
	if value >= 1000 then unlock("TOWER_SHOCK_1000") end
	if value >= 250 then unlock("TOWER_SHOCK_250") end
end

watchers.TOWER_POISON_KILLS = function(value)
	if value >= 1000 then unlock("TOWER_POISON_1000") end
	if value >= 250 then unlock("TOWER_POISON_250") end
end

watchers.TOWER_PLASMA_KILLS = function(value)
	if value >= 1000 then unlock("TOWER_PLASMA_1000") end
	if value >= 250 then unlock("TOWER_PLASMA_250") end
end

watchers.TOWER_UPGRADES = function(value)
	if value >= 100 then unlock("TOWER_UPGRADE_100") end
	if value >= 1 then unlock("TOWER_UPGRADE_1") end
end

function Achievements.increment(stat, amount)
	if State.ignoreStats then
		return
	end

	amount = amount or 1

	local meta = Save.data.meta
	meta[stat] = (meta[stat] or 0) + amount

	local fn = watchers[stat]

	if fn then
		fn(meta[stat])
	end
end

function Achievements.onGameOver()
	Achievements.checkCampaignCompletion()
	Save.flush()
end

function Achievements.unlock(id)
	unlock(id)
end

return Achievements