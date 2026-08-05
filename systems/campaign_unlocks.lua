local Constants = require("core.constants")
local Save = require("core.save")
local L = require("core.localization")
local Maps = require("world.map_defs")

local CampaignUnlocks = {}

local UNKNOWN_REQUIRED_MAP = math.huge

local requiredMapByTower = {
	lancer = 1,
}

for mapIndex, map in ipairs(Maps) do
	for _, kind in ipairs(map.rewardTowers or {}) do
		-- A map's rewardTowers are earned after clearing that map, so the tower
		-- becomes usable starting on the next campaign map.
		requiredMapByTower[kind] = mapIndex + 1
	end
end

local function normalizeProgressIndex(progressIndex)
	return math.max(1, tonumber(progressIndex) or 1)
end

local function getProgressIndex()
	return normalizeProgressIndex(Save.data and Save.data.furthestIndex)
end

function CampaignUnlocks.getRequiredMap(kind)
	return requiredMapByTower[kind] or UNKNOWN_REQUIRED_MAP
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
