local Constants = require("core.constants")
local Save = require("core.save")
local L = require("core.localization")

local CampaignUnlocks = {}

local requiredMapByTower = {
	lancer = 1,
	slow = 2,
	cannon = 3,
	poison = 4,
	shock = 5,
	plasma = 6,
}

local function normalizeProgressIndex(progressIndex)
	return math.max(1, tonumber(progressIndex) or 1)
end

local function getProgressIndex()
	return normalizeProgressIndex(Save.data and Save.data.furthestIndex)
end

function CampaignUnlocks.getRequiredMap(kind)
	return requiredMapByTower[kind] or 1
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

	if requiredMap <= 1 then
		return nil
	end

	return L("towerUnlock.lockedUntil", requiredMap - 1)
end

return CampaignUnlocks
