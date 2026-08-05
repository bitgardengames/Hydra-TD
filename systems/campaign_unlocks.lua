local Constants = require("core.constants")
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

local function normalizeMapIndex(mapIndex)
	return math.max(1, tonumber(mapIndex) or 1)
end

function CampaignUnlocks.getRequiredMap(kind)
	return requiredMapByTower[kind] or 1
end

function CampaignUnlocks.isTowerUnlocked(kind, mapIndex)
	return normalizeMapIndex(mapIndex) >= CampaignUnlocks.getRequiredMap(kind)
end

function CampaignUnlocks.getUnlockedTowers(mapIndex)
	local unlocked = {}
	local normalizedMapIndex = normalizeMapIndex(mapIndex)

	for _, kind in ipairs(Constants.TOWER_LIST) do
		if CampaignUnlocks.isTowerUnlocked(kind, normalizedMapIndex) then
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
