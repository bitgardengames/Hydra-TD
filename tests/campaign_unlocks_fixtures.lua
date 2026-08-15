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

-- Meaningful unlocks must be paced one per clear and packed at the front of
-- the campaign. Once the pool is exhausted, remaining maps intentionally have
-- no reward rather than presenting route progression as a new unlock.
local reachedBareMap = false
local rewardCount = 0
for _, map in ipairs(Maps) do
	local rewards = CampaignUnlocks.getRewardsForMap(map)
	check(#rewards <= 1, map.id .. " grants more than one campaign reward")
	if #rewards == 0 then
		reachedBareMap = true
	else
		check(not reachedBareMap, map.id .. " grants an unlock after a bare campaign map")
		check(rewards[1].type ~= "map", map.id .. " uses route progression as an unlock")
		rewardCount = rewardCount + 1
	end
end

local progressRewards = CampaignUnlocks.getNewRewards(1, #Maps + 1)
check(#progressRewards == rewardCount, "campaign progress did not return every authored reward")
check(rewardCount < #Maps, "fixture no longer covers a campaign with fewer unlocks than maps")

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
