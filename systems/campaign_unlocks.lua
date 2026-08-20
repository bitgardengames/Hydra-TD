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
	},
	roundabout = {{type = "ability", id = "overdrive", label = "Overdrive active ability"}},
	-- Gauntlet is the fundamentals test; Shock joins the arsenal only after it is cleared.
	gauntlet = {
		{type = "tower", id = "shock", label = "Shock tower"},
	},
	-- Snake Trail's formation-control reward prepares players for denser mixed waves.
	snaketrail = {{type = "ability", id = "gravity_well", label = "Gravity Well active ability"}},
	-- Frost Nova is earned before Backtrack introduces runners.
	backtrack = {{type = "ability", id = "frost_nova", label = "Frost Nova active ability"}},
	lowvalley = {{type = "ability", id = "gold_rush", label = "Gold Rush active ability"}},
	circuit = {
		{type = "tower", id = "plasma", labelKey = "campaign.rewards.plasma"},
	},
	outerloop = {{type = "ability", id = "last_stand", label = "Last Stand active ability"}},
	-- There are fewer meaningful unlocks than campaign maps. Keep the real
	-- rewards contiguous at the front rather than using route progression as a
	-- placeholder reward or leaving gaps between unlocks.
	twinloop = {{
		type = "campaign_complete",
		id = "challenge_endless",
		labelKey = "campaign.rewards.challengeEndless",
		descriptionKey = "victory.rewardDescriptions.challenge_endless",
	}},
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

local function validateRewards()
	local AbilityDefs = require("systems.ability_defs")
	local knownMaps, knownTowers, knownAbilities = {}, {}, {}
	for _, map in ipairs(Maps) do knownMaps[map.id] = true end
	for _, towerId in ipairs(Constants.TOWER_LIST) do knownTowers[towerId] = true end
	for abilityId, def in pairs(AbilityDefs) do
		if type(def) == "table" and def.id then
			knownAbilities[abilityId] = true
		end
	end
	for mapId, rewards in pairs(rewardsByMapId) do
		assert(knownMaps[mapId], "campaign reward uses unknown map ID: " .. tostring(mapId))
		for _, reward in ipairs(rewards) do
			if reward.type == "tower" then
				assert(knownTowers[reward.id], "campaign reward uses unknown tower ID: " .. tostring(reward.id))
			elseif reward.type == "ability" then
				assert(knownAbilities[reward.id], "campaign reward uses unknown ability ID: " .. tostring(reward.id))
			elseif reward.type == "map" then
				assert(knownMaps[reward.id], "campaign reward uses unknown map ID: " .. tostring(reward.id))
			end
		end
	end
	for _, map in ipairs(Maps) do
		if map.prerequisiteMapId then
			assert(knownMaps[map.prerequisiteMapId], "campaign route uses unknown map ID: " .. tostring(map.prerequisiteMapId))
		end
	end
end

validateRewards()

for mapIndex, map in ipairs(Maps) do
	local requiredMap = mapIndex + 1
	for _, reward in ipairs(rewardsByMapId[map.id] or {}) do
		requiredMapByFeature[featureKey(reward.type, reward.id)] = requiredMap
		if reward.type == "tower" then
			-- A map's tower reward is earned after clearing that map, so the tower
			-- becomes usable starting on the next campaign map.
			requiredMapByTower[reward.id] = requiredMap
		elseif reward.type == "ability_slot" then
			for slot = 2, reward.slots or 1 do
				requiredMapByAbilitySlot[slot] = math.min(requiredMapByAbilitySlot[slot] or UNKNOWN_REQUIRED_MAP, requiredMap)
			end
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

local function isRewardMapCompleted(requiredMap)
	local rewardMap = Maps[requiredMap - 1]
	local mapStats = Save.data and Save.data.mapStats
	local stats = rewardMap and type(mapStats) == "table" and mapStats[rewardMap.id]
	return type(stats) == "table" and stats.completedDifficulty ~= nil
end

local function isFeatureUnlocked(featureType, id)
	local requiredMap = requiredMapByFeature[featureKey(featureType, id)] or UNKNOWN_REQUIRED_MAP
	-- Completion records are the durable proof that a reward was earned. Older
	-- profiles can have complete map stats but a missing/stale furthestIndex, so
	-- relying only on route progression makes every ability appear locked.
	return getProgressIndex() >= requiredMap or isRewardMapCompleted(requiredMap)
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

function CampaignUnlocks.getUnlockedAbilitySlots()
	return 2
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

function CampaignUnlocks.isModuleCategoryUnlocked(category)
	return category == "identity" or category == "special" or isFeatureUnlocked("module_category", category)
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
