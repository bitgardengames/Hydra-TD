-- Dependency-free campaign reward fixtures. Run from the repository root with Lua/LuaJIT.
package.path = "./?.lua;" .. package.path

local save = {data = {furthestIndex = 1, mapStats = {}}}
package.loaded["core.save"] = save
package.loaded["core.localization"] = function(key) return key end

local CampaignUnlocks = require("systems.campaign_unlocks")
local AbilityDefs = require("systems.ability_defs")
local Constants = require("core.constants")
local Maps = require("world.map_defs")
local languageFile = assert(io.open("languages/enUS.lua", "r"))
local enUSSource = languageFile:read("*a")
languageFile:close()

local function check(value, message)
	assert(value, message)
end

check(CampaignUnlocks.getUnlockedAbilitySlots() == 0,
	"profiles without active abilities must not display ability slots")

-- Every tower is part of the baseline arsenal, even on a brand-new profile.
for _, towerId in ipairs(Constants.TOWER_LIST) do
	check(CampaignUnlocks.isTowerUnlocked(towerId), towerId .. " was locked on a fresh profile")
	check(CampaignUnlocks.getRequiredMap(towerId) == 1, towerId .. " requires campaign progress")
end
check(#CampaignUnlocks.getUnlockedTowers() == #Constants.TOWER_LIST,
	"fresh profiles must have the complete tower roster")
check(#CampaignUnlocks.getNewlyUnlockedTowers(1, #Maps + 1) == 0,
	"campaign progress must never award towers")

-- Campaign unlocks are paced at no more than one per clear. Maps that formerly
-- awarded towers now intentionally have no authored reward.
local rewardCount = 0
for _, map in ipairs(Maps) do
	local rewards = CampaignUnlocks.getRewardsForMap(map)
	check(#rewards <= 1, map.id .. " grants more than one campaign reward")
	if #rewards > 0 then
		check(rewards[1].type ~= "map", map.id .. " uses route progression as an unlock")
		check(rewards[1].type ~= "tower", map.id .. " awards a baseline tower")
		rewardCount = rewardCount + 1
	end
end

local progressRewards = CampaignUnlocks.getNewRewards(1, #Maps + 1)
check(#progressRewards == rewardCount, "campaign progress did not return every authored reward")
check(rewardCount < #Maps, "fixture no longer covers a campaign with fewer unlocks than maps")

-- Ability rewards follow their teaching progression, use localized labels that
-- both Campaign and Victory can render, and start with Meteor on the first clear.
local abilityTeachingOrder = {
	{"riverbend", "meteor", "burst"},
	{"roundabout", "overdrive", "tower_buff"},
	{"snaketrail", "gravity_well", "formation"},
	{"backtrack", "frost_nova", "control"},
	{"lowvalley", "gold_rush", "economy"},
	{"outerloop", "last_stand", "emergency"},
}
for _, expected in ipairs(abilityTeachingOrder) do
	local reward = CampaignUnlocks.getRewardForMap(expected[1])
	check(reward and reward.type == "ability" and reward.id == expected[2],
		expected[1] .. " does not award " .. expected[2])
	check(AbilityDefs[reward.id].utilityRole == expected[3], reward.id .. " changed utility role")
	local labelName = reward.labelKey and reward.labelKey:match("^campaign%.rewards%.(.+)$")
	check(labelName and enUSSource:match("\n%s*" .. labelName .. '%s*=%s*"[^"]+"'),
		reward.id .. " has no en-US reward label")
end

-- A stale route index must not relock rewards already proven by completion
-- records, as can happen to profiles created before furthestIndex was saved.
for _, map in ipairs(Maps) do
	save.data.mapStats[map.id] = {completedDifficulty = "normal"}
end
for _, abilityId in ipairs(AbilityDefs.order) do
	check(CampaignUnlocks.isAbilityUnlocked(abilityId), abilityId .. " was relocked on a completed campaign")
end

-- A completion only unlocks the reward attached to that map.
save.data.mapStats = {riverbend = {completedDifficulty = "easy"}}
check(CampaignUnlocks.isAbilityUnlocked("meteor"), "completed map did not unlock its ability")
check(not CampaignUnlocks.isAbilityUnlocked("overdrive"), "uncompleted map unlocked its ability")
check(CampaignUnlocks.getUnlockedAbilitySlots() == 1,
	"the first earned active ability must unlock exactly one slot")
save.data.mapStats.roundabout = {completedDifficulty = "easy"}
check(CampaignUnlocks.getUnlockedAbilitySlots() == 2,
	"the second earned active ability must unlock the second slot")

print("campaign unlock fixtures passed")
