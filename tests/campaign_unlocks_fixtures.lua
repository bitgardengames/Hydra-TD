-- Dependency-free campaign reward fixtures. Run from the repository root with Lua/LuaJIT.
package.path = "./?.lua;" .. package.path

local save = {data = {furthestIndex = 1, mapStats = {}}}
package.loaded["core.save"] = save
package.loaded["core.localization"] = function(key) return key end

local CampaignUnlocks = require("systems.campaign_unlocks")
local AbilityDefs = require("systems.ability_defs")
local Maps = require("world.map_defs")

local function check(value, message)
	assert(value, message)
end

-- Every campaign clear must advance the player's available options. Keeping
-- this invariant here prevents future reward reshuffles from reintroducing a
-- dead map with no unlock preview or victory card.
for _, map in ipairs(Maps) do
	check(#CampaignUnlocks.getRewardsForMap(map) > 0, map.id .. " has no campaign reward")
end

-- The reward cadence is one unlock per clear, rather than several unlocks on
-- one map followed by an unrewarded gap.
local progressRewards = CampaignUnlocks.getNewRewards(1, #Maps + 1)
check(#progressRewards == #Maps, "campaign rewards are not paced one per map")

-- A stale route index must not relock rewards already proven by completion
-- records, as can happen to profiles created before furthestIndex was saved.
for _, map in ipairs(Maps) do
	save.data.mapStats[map.id] = {completedDifficulty = "normal"}
end
for _, abilityId in ipairs(AbilityDefs.order) do
	check(CampaignUnlocks.isAbilityUnlocked(abilityId), abilityId .. " was relocked on a completed campaign")
end
check(CampaignUnlocks.isAbilityUpgradeUnlocked("enhanced_abilities"), "completed ability upgrade was relocked")
check(CampaignUnlocks.isChallengeModeUnlocked(), "completed campaign mode was relocked")

-- A completion only unlocks the reward attached to that map.
save.data.mapStats = {switchback = {completedDifficulty = "easy"}}
check(CampaignUnlocks.isAbilityUnlocked("meteor"), "completed map did not unlock its ability")
check(not CampaignUnlocks.isAbilityUnlocked("overdrive"), "uncompleted map unlocked its ability")

print("campaign unlock fixtures passed")
