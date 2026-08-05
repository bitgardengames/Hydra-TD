local Constants = require("core.constants")
local Save = require("core.save")
local L = require("core.localization")
local Maps = require("world.map_defs")

local CampaignUnlocks = {}

local UNKNOWN_REQUIRED_MAP = math.huge

-- Campaign rewards are authored by map order. Keep the rewards here as the
-- single unlock source; map_defs owns only the playable map ordering/layouts.
-- Rewards intentionally avoid mandatory stat power and instead emphasize new
-- verbs, optional build utilities, and information that teaches counters.
local rewardsByMapId = {
	switchback = {type = "tower", id = "cannon", label = "Cannon tower"},
	highpass = {type = "tower", id = "poison", label = "Poison tower"},
	roundabout = {type = "tower", id = "shock", label = "Shock tower"},
	gauntlet = {type = "ability", id = "meteor", label = "Meteor active ability"},
	snaketrail = {type = "ability", id = "frost_nova", label = "Frost Nova active ability"},
	lowvalley = {type = "targeting", id = "high_hp", label = "Strongest targeting option"},
	circuit = {type = "module_category", id = "utility", label = "Utility module category"},
	outerloop = {type = "ability_slot", id = "ability_slot_2", slots = 2, label = "Second active ability slot"},
	terrace = {type = "wave_preview", id = "enhanced", label = "Enhanced wave preview"},
	highridge = {type = "targeting", id = "low_hp", label = "Weakest targeting option"},
	crossflow = {type = "module_category", id = "movement", label = "Movement module category"},
	steppingstones = {type = "ability_upgrade", id = "enhanced_abilities", label = "Enhanced active ability effects"},
	twinloop = {type = "campaign_complete", id = "challenge_endless", label = "Challenge and Endless modes"},
}

local requiredMapByTower = {
	lancer = 1,
	slow = 1,
}

local requiredMapByFeature = {}
local rewardOrder = {}

local function featureKey(featureType, id)
	return tostring(featureType) .. ":" .. tostring(id)
end

for mapIndex, map in ipairs(Maps) do
	local reward = rewardsByMapId[map.id]
	if reward then
		rewardOrder[map.id] = mapIndex
		local requiredMap = mapIndex + 1
		requiredMapByFeature[featureKey(reward.type, reward.id)] = requiredMap
		if reward.type == "tower" then
			-- A map's tower reward is earned after clearing that map, so the tower
			-- becomes usable starting on the next campaign map.
			requiredMapByTower[reward.id] = requiredMap
		end
	end

	for _, kind in ipairs(map.rewardTowers or {}) do
		-- Compatibility for older map data or mods that still author tower rewards
		-- directly on map definitions.
		requiredMapByTower[kind] = mapIndex + 1
	end
end

local function normalizeProgressIndex(progressIndex)
	return math.max(1, tonumber(progressIndex) or 1)
end

local function getProgressIndex()
	return normalizeProgressIndex(Save.data and Save.data.furthestIndex)
end

local function isFeatureUnlocked(featureType, id)
	return getProgressIndex() >= (requiredMapByFeature[featureKey(featureType, id)] or UNKNOWN_REQUIRED_MAP)
end

function CampaignUnlocks.getRequiredMap(kind)
	return requiredMapByTower[kind] or UNKNOWN_REQUIRED_MAP
end

function CampaignUnlocks.getRequiredFeatureMap(featureType, id)
	return requiredMapByFeature[featureKey(featureType, id)] or UNKNOWN_REQUIRED_MAP
end

function CampaignUnlocks.getRewardForMap(mapOrId)
	local mapId = type(mapOrId) == "table" and mapOrId.id or mapOrId
	return mapId and rewardsByMapId[mapId] or nil
end

function CampaignUnlocks.getRewardsByMapId()
	return rewardsByMapId
end

function CampaignUnlocks.isAbilityUnlocked(abilityId)
	return isFeatureUnlocked("ability", abilityId)
end

function CampaignUnlocks.isAbilitySlotUnlocked(slotIndex)
	return (tonumber(slotIndex) or 1) <= CampaignUnlocks.getUnlockedAbilitySlots()
end

function CampaignUnlocks.isAbilityUpgradeUnlocked(upgradeId)
	return isFeatureUnlocked("ability_upgrade", upgradeId)
end

function CampaignUnlocks.getUnlockedAbilitySlots()
	local slots = 1
	for _, reward in pairs(rewardsByMapId) do
		if reward.type == "ability_slot" and isFeatureUnlocked(reward.type, reward.id) then
			slots = math.max(slots, reward.slots or slots)
		end
	end
	return slots
end


function CampaignUnlocks.getEquippedAbilities()
	local AbilityDefs = require("systems.ability_defs")
	local equipped = {}

	for _, abilityId in ipairs(AbilityDefs.order or {}) do
		equipped[#equipped + 1] = abilityId
	end

	return equipped
end

function CampaignUnlocks.isTargetingUnlocked(mode)
	return mode == "progress" or mode == "farthest" or isFeatureUnlocked("targeting", mode)
end

function CampaignUnlocks.isModuleCategoryUnlocked(category)
	return category == "identity" or category == "special" or isFeatureUnlocked("module_category", category)
end

function CampaignUnlocks.hasEnhancedWavePreview()
	return isFeatureUnlocked("wave_preview", "enhanced")
end

function CampaignUnlocks.isChallengeModeUnlocked()
	return isFeatureUnlocked("campaign_complete", "challenge_endless")
end

function CampaignUnlocks.isEndlessUnlocked()
	return CampaignUnlocks.isChallengeModeUnlocked()
end

function CampaignUnlocks.isTowerUnlocked(kind)
	return getProgressIndex() >= CampaignUnlocks.getRequiredMap(kind)
end

function CampaignUnlocks.getUnlockedTowers()
	local unlocked = {}

	for _, kind in ipairs(Constants.TOWER_LIST) do
		if CampaignUnlocks.isTowerUnlocked(kind) then
			unlocked[#unlocked + 1] = kind
		end
	end

	return unlocked
end

function CampaignUnlocks.getNewlyUnlockedTowers(previousProgressIndex, nextProgressIndex)
	local unlocked = {}
	local previous = normalizeProgressIndex(previousProgressIndex)
	local nextIndex = normalizeProgressIndex(nextProgressIndex)

	for _, kind in ipairs(Constants.TOWER_LIST) do
		local requiredMap = CampaignUnlocks.getRequiredMap(kind)
		if requiredMap > previous and requiredMap <= nextIndex then
			unlocked[#unlocked + 1] = kind
		end
	end

	return unlocked
end

function CampaignUnlocks.getNewRewards(previousProgressIndex, nextProgressIndex)
	local rewards = {}
	local previous = normalizeProgressIndex(previousProgressIndex)
	local nextIndex = normalizeProgressIndex(nextProgressIndex)
	for _, map in ipairs(Maps) do
		local reward = rewardsByMapId[map.id]
		local requiredMap = reward and rewardOrder[map.id] and (rewardOrder[map.id] + 1)
		if reward and requiredMap > previous and requiredMap <= nextIndex then
			rewards[#rewards + 1] = reward
		end
	end
	return rewards
end

function CampaignUnlocks.getAbilityLockMessage(abilityId, slotIndex)
	local requiredMap = CampaignUnlocks.getRequiredFeatureMap("ability", abilityId)

	if requiredMap == UNKNOWN_REQUIRED_MAP then
		return L("towerUnlock.locked")
	elseif requiredMap > 1 and getProgressIndex() < requiredMap then
		return L("towerUnlock.lockedUntil", requiredMap - 1)
	end

	if not CampaignUnlocks.isAbilitySlotUnlocked(slotIndex) then
		local slotRequiredMap = UNKNOWN_REQUIRED_MAP
		for _, reward in pairs(rewardsByMapId) do
			if reward.type == "ability_slot" and (reward.slots or 1) >= (tonumber(slotIndex) or 1) then
				slotRequiredMap = math.min(slotRequiredMap, CampaignUnlocks.getRequiredFeatureMap(reward.type, reward.id))
			end
		end
		if slotRequiredMap ~= UNKNOWN_REQUIRED_MAP then
			return L("towerUnlock.lockedUntil", slotRequiredMap - 1)
		end
		return L("towerUnlock.locked")
	end

	return nil
end

function CampaignUnlocks.getLockMessage(kind)
	local requiredMap = CampaignUnlocks.getRequiredMap(kind)

	if requiredMap == UNKNOWN_REQUIRED_MAP then
		return L("towerUnlock.locked")
	elseif requiredMap <= 1 then
		return nil
	end

	return L("towerUnlock.lockedUntil", requiredMap - 1)
end

return CampaignUnlocks
