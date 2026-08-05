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
	riverbend = {type = "codex", id = "path_basics", label = "Pathing codex: bends and overlap"},
	switchback = {type = "tower", id = "cannon", label = "Cannon tower"},
	highpass = {type = "tower", id = "poison", label = "Poison tower"},
	roundabout = {type = "tower", id = "shock", label = "Shock tower"},
	gauntlet = {type = "tower", id = "plasma", label = "Plasma tower"},
	snaketrail = {type = "ability", id = "frost_nova", label = "Frost Nova active ability"},
	backtrack = {type = "targeting", id = "strongest", label = "Strongest targeting option"},
	lowvalley = {type = "module_slot", id = "utility_slot_1", label = "Optional utility module slot"},
	circuit = {type = "module", id = "cull_weak", label = "Cull Weak poison module"},
	outerloop = {type = "challenge", id = "no_leaks", label = "No-leaks challenge badge"},
	terrace = {type = "codex", id = "support_roles", label = "Support enemy codex entries"},
	highridge = {type = "targeting", id = "shield_priority", label = "Shield-priority targeting option"},
	crossflow = {type = "module", id = "chain_fork", label = "Chain Fork shock module"},
	steppingstones = {type = "build_utility", id = "saved_loadouts", label = "Optional saved build loadouts"},
	twinloop = {type = "challenge", id = "endless_variants", label = "Endless variant challenge modes"},
}

local requiredMapByTower = {
	lancer = 1,
	slow = 1,
}

for mapIndex, map in ipairs(Maps) do
	local reward = rewardsByMapId[map.id]
	if reward and reward.type == "tower" then
		-- A map's tower reward is earned after clearing that map, so the tower
		-- becomes usable starting on the next campaign map.
		requiredMapByTower[reward.id] = mapIndex + 1
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

function CampaignUnlocks.getRequiredMap(kind)
	return requiredMapByTower[kind] or UNKNOWN_REQUIRED_MAP
end

function CampaignUnlocks.getRewardForMap(mapOrId)
	local mapId = type(mapOrId) == "table" and mapOrId.id or mapOrId
	return mapId and rewardsByMapId[mapId] or nil
end

function CampaignUnlocks.getRewardsByMapId()
	return rewardsByMapId
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
