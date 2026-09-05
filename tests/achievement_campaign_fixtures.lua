-- Dependency-free campaign achievement fixtures. Run from the repository root.

local campaignMapIds = {
	"riverbend", "switchback", "highpass", "roundabout", "gauntlet",
	"snaketrail", "backtrack", "lowvalley", "circuit", "outerloop",
	"terrace", "highridge", "crossflow", "steppingstones", "twinloop",
	"frostgate", "tidelock", "ashspiral",
}

local state = {ignoreStats = false}
local save = {data = nil, flush = function() end}

package.loaded["core.state"] = state
package.loaded["core.steam"] = {loaded = false}
package.loaded["core.save"] = save
package.loaded["systems.achievement_defs"] = {}
package.loaded["systems.achievements"] = nil

local Achievements = require("systems.achievements")

local function statsThrough(lastIndex, difficulty)
	local stats = {}
	for i = 1, lastIndex do
		stats[campaignMapIds[i]] = {completedDifficulty = difficulty}
	end
	return stats
end

local function check(mapStats, unlockedAchievements)
	save.data = {
		mapStats = mapStats,
		meta = {unlockedAchievements = unlockedAchievements or {}},
	}
	Achievements.checkCampaignCompletion()
	return save.data.meta.unlockedAchievements
end

-- A save made before chapter four has all 15 original maps completed, but has
-- not completed the current campaign and must not receive a campaign unlock.
local oldSaveUnlocks = check(statsThrough(15, "normal"))
assert(not oldSaveUnlocks.CAMPAIGN_EASY and not oldSaveUnlocks.CAMPAIGN_NORMAL,
	"an old 15-map save must not count as completing the current campaign")

-- Achievements already persisted in an old save remain intact; checking current
-- completion only grants achievements and never revokes historical unlocks.
local persistedUnlocks = check(statsThrough(15, "normal"), {CAMPAIGN_NORMAL = true})
assert(persistedUnlocks.CAMPAIGN_NORMAL,
	"an achievement persisted by an old save must not be revoked")

local partialUnlocks = check(statsThrough(17, "hard"))
assert(not partialUnlocks.CAMPAIGN_EASY
	and not partialUnlocks.CAMPAIGN_NORMAL
	and not partialUnlocks.CAMPAIGN_HARD,
	"a campaign missing any current map must not unlock at any difficulty")

local completeUnlocks = check(statsThrough(18, "normal"))
assert(completeUnlocks.CAMPAIGN_EASY and completeUnlocks.CAMPAIGN_NORMAL,
	"all 18 maps completed on Normal must unlock Easy and Normal")
assert(not completeUnlocks.CAMPAIGN_HARD,
	"Normal campaign completion must not unlock Hard")

print("campaign achievement fixtures passed")
