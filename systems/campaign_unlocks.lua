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
	riverbend = {{type = "tower", id = "cannon", labelKey = "campaign.rewards.cannon"}},
	switchback = {{type = "ability", id = "meteor", labelKey = "campaign.rewards.meteor"}},
	highpass = {
		{type = "tower", id = "poison", label = "Poison tower"},
		{type = "ability", id = "overdrive", label = "Overdrive active ability"},
		{type = "ability_slot", id = "ability_slot_3", slots = 3, label = "Third ability slot"},
	},
	roundabout = {{type = "targeting", id = "high_hp", labelKey = "campaign.rewards.strongest"}},
	-- Gauntlet is the fundamentals test; Shock joins the arsenal only after it is cleared.
	gauntlet = {
		{type = "tower", id = "shock", label = "Shock tower"},
		{type = "ability", id = "gravity_well", label = "Gravity Well active ability"},
		{type = "ability_slot", id = "ability_slot_4", slots = 4, label = "Fourth ability slot"},
	},
	-- Frost Nova is earned before the map that introduces runners.
	snaketrail = {{type = "ability", id = "frost_nova", label = "Frost Nova active ability"}},
	backtrack = {
		{type = "targeting", id = "low_hp", labelKey = "campaign.rewards.weakest"},
		{type = "ability", id = "gold_rush", label = "Gold Rush active ability"},
		{type = "ability_slot", id = "ability_slot_5", slots = 5, label = "Fifth ability slot"},
	},
	lowvalley = {{type = "wave_preview", id = "enhanced", labelKey = "campaign.rewards.enhancedPreview"}},
	circuit = {
		{type = "tower", id = "plasma", labelKey = "campaign.rewards.plasma"},
		{type = "ability", id = "last_stand", label = "Last Stand active ability"},
		{type = "ability_slot", id = "ability_slot_6", slots = 6, label = "Sixth ability slot"},
	},
	outerloop = {{type = "ability_slot", id = "ability_slot_2", slots = 2, labelKey = "campaign.rewards.secondAbilitySlot"}},
	-- Clearing High Ridge earns the shared enhancement through the same reward
	-- lookup used by every other campaign unlock.
	highridge = {{type = "ability_upgrade", id = "enhanced_abilities", labelKey = "campaign.rewards.enhancedAbilities"}},
	twinloop = {{type = "campaign_complete", id = "challenge_endless", labelKey = "campaign.rewards.challengeEndless"}},
}

local requiredMapByTower = {
	lancer = 1,
	slow = 1,
}

local requiredMapByFeature = {}
local requiredMapByAbilitySlot = {}

local function featureKey(featureType, id)
	return tostring(featureType) .. ":" .. tostring(id)
end

local function toSet(values, valueSelector, iterator)
	local result = {}
	for key, value in (iterator or pairs)(values) do
		result[valueSelector and valueSelector(key, value) or value] = true
	end
	return result
end

local function validateRewards()
	local AbilityDefs = require("systems.ability_defs")
	local Targeting = require("world.targeting")
	local knownMaps = toSet(Maps, function(_, map) return map.id end, ipairs)
	local knownTowers = toSet(Constants.TOWER_LIST, nil, ipairs)
	local knownAbilities, knownUpgrades = {}, {}
	for abilityId, def in pairs(AbilityDefs) do
		if type(def) == "table" and def.id then
			knownAbilities[abilityId] = true
			if def.upgradeId then knownUpgrades[def.upgradeId] = true end
		end
	end
	local knownTargeting = toSet(Targeting.MODES)
	local knownIdsByRewardType = {
		tower = knownTowers,
		ability = knownAbilities,
		ability_upgrade = knownUpgrades,
		targeting = knownTargeting,
		map = knownMaps,
	}
	local standaloneRewardTypes = {
		ability_slot = true,
		wave_preview = true,
		campaign_complete = true,
		module_category = true,
	}

	for mapId, rewards in pairs(rewardsByMapId) do
		assert(knownMaps[mapId], "campaign reward uses unknown map ID: " .. tostring(mapId))
		for _, reward in ipairs(rewards) do
			local knownIds = knownIdsByRewardType[reward.type]
			assert(knownIds or standaloneRewardTypes[reward.type], "campaign reward uses unknown type: " .. tostring(reward.type))
			assert(not knownIds or knownIds[reward.id], "campaign reward uses unknown " .. reward.type .. " ID: " .. tostring(reward.id))
			assert(reward.type ~= "ability_slot" or (type(reward.slots) == "number" and reward.slots >= 2),
				"ability slot reward requires at least two slots: " .. tostring(reward.id))
		end
	end
	for _, map in ipairs(Maps) do
		if map.prerequisiteMapId then
			assert(knownMaps[map.prerequisiteMapId], "campaign route uses unknown map ID: " .. tostring(map.prerequisiteMapId))
		end
	end
end

validateRewards()

local function indexReward(reward, requiredMap)
	requiredMapByFeature[featureKey(reward.type, reward.id)] = requiredMap
	if reward.type == "tower" then
		requiredMapByTower[reward.id] = requiredMap
	elseif reward.type == "ability_slot" then
		for slot = 2, reward.slots do
			requiredMapByAbilitySlot[slot] = math.min(requiredMapByAbilitySlot[slot] or UNKNOWN_REQUIRED_MAP, requiredMap)
		end
	end
end

for mapIndex, map in ipairs(Maps) do
	local requiredMap = mapIndex + 1
	for _, reward in ipairs(rewardsByMapId[map.id] or {}) do
		-- A reward is earned after clearing its map, so it becomes usable on
		-- the following campaign map.
		indexReward(reward, requiredMap)
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

local function isRewardUnlocked(rewardType, rewardId)
	return isFeatureUnlocked(rewardType, rewardId)
end

function CampaignUnlocks.getRequiredMap(kind)
	return requiredMapByTower[kind] or UNKNOWN_REQUIRED_MAP
end

function CampaignUnlocks.getRequiredFeatureMap(featureType, id)
	return requiredMapByFeature[featureKey(featureType, id)] or UNKNOWN_REQUIRED_MAP
end

function CampaignUnlocks.getRewardForMap(mapOrId)
	local mapId = type(mapOrId) == "table" and mapOrId.id or mapOrId
	local rewards = mapId and rewardsByMapId[mapId]
	return rewards and rewards[1] or nil
end

function CampaignUnlocks.getRewardsByMapId()
	local primaryRewards = {}
	for mapId, rewards in pairs(rewardsByMapId) do
		primaryRewards[mapId] = rewards[1]
	end
	return primaryRewards
end

function CampaignUnlocks.getRewardsForMap(mapOrId)
	local mapId = type(mapOrId) == "table" and mapOrId.id or mapOrId
	return (mapId and rewardsByMapId[mapId]) or {}
end

function CampaignUnlocks.isAbilityUnlocked(abilityId)
	return isFeatureUnlocked("ability", abilityId)
end

function CampaignUnlocks.isAbilitySlotUnlocked(slotIndex)
	return (tonumber(slotIndex) or 1) <= CampaignUnlocks.getUnlockedAbilitySlots()
end

function CampaignUnlocks.isAbilityUpgradeUnlocked(upgradeId)
	return isRewardUnlocked("ability_upgrade", upgradeId)
end

function CampaignUnlocks.getUnlockedAbilitySlots()
	local slots = 1
	local progress = getProgressIndex()
	for slot, requiredMap in pairs(requiredMapByAbilitySlot) do
		if progress >= requiredMap then
			slots = math.max(slots, slot)
		end
	end
	return slots
end


function CampaignUnlocks.getEquippedAbilities()
	local AbilityDefs = require("systems.ability_defs")
	local equipped = {}
	local equippedById = {}
	local selections = Save.data and Save.data.equippedAbilities or {"meteor", "frost_nova"}
	local unlockedSlots = CampaignUnlocks.getUnlockedAbilitySlots()

	for slotIndex = 1, unlockedSlots do
		local abilityId = selections[slotIndex]
		if AbilityDefs[abilityId] and CampaignUnlocks.isAbilityUnlocked(abilityId) and not equippedById[abilityId] then
			equipped[#equipped + 1] = abilityId
			equippedById[abilityId] = true
		end
	end

	-- A newly earned ability must be usable even when an older profile has an
	-- empty slot or has a still-locked ability selected there. Build the runtime
	-- loadout from campaign progress rather than rewriting the player's save.
	for _, abilityId in ipairs(AbilityDefs.order) do
		if #equipped >= unlockedSlots then break end
		if CampaignUnlocks.isAbilityUnlocked(abilityId) and not equippedById[abilityId] then
			equipped[#equipped + 1] = abilityId
			equippedById[abilityId] = true
		end
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
	for mapIndex, map in ipairs(Maps) do
		local requiredMap = mapIndex + 1
		if requiredMap > previous and requiredMap <= nextIndex then
			for _, reward in ipairs(rewardsByMapId[map.id] or {}) do
				rewards[#rewards + 1] = reward
			end
		end
	end
	return rewards
end

function CampaignUnlocks.getAbilityLockMessage(abilityId, slotIndex)
	local requiredMap = CampaignUnlocks.getRequiredFeatureMap("ability", abilityId)
	local function clearedMapName(requiredIndex)
		local map = Maps[requiredIndex - 1]
		return map and L(map.nameKey) or nil
	end

	if requiredMap == UNKNOWN_REQUIRED_MAP then
		return L("abilityUnlock.notEarned")
	elseif requiredMap > 1 and getProgressIndex() < requiredMap then
		local mapName = clearedMapName(requiredMap)
		return mapName and L("abilityUnlock.abilityNotEarned", mapName) or L("abilityUnlock.notEarned")
	end

	if not CampaignUnlocks.isAbilitySlotUnlocked(slotIndex) then
		local slotRequiredMap = requiredMapByAbilitySlot[tonumber(slotIndex) or 1] or UNKNOWN_REQUIRED_MAP
		if slotRequiredMap ~= UNKNOWN_REQUIRED_MAP then
			local mapName = clearedMapName(slotRequiredMap)
			return mapName and L("abilityUnlock.slotNotEarned", mapName) or L("abilityUnlock.slotLocked")
		end
		return L("abilityUnlock.slotLocked")
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
