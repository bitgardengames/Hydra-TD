local Constants = require("core.constants")
local TowerDefs = require("world.tower_defs")

local Modifiers = {}

local DEFAULTS = {
	startMoneyDelta = 0,
	enemyHpMult = 1.0,
	enemySpeedMult = 1.0,
	towerRangeMult = 1.0,
	rewardMult = 1.0,
	noBuildZones = nil,
	bonusInterest = 0,
	extraBossAdds = 0,
	limitedTowerTypes = nil,
}

local SUMMARY_ORDER = {
	"startMoneyDelta",
	"enemyHpMult",
	"enemySpeedMult",
	"towerRangeMult",
	"rewardMult",
	"noBuildZones",
	"bonusInterest",
	"extraBossAdds",
	"limitedTowerTypes",
}

local function copyArray(src)
	if not src then
		return nil
	end

	local dst = {}
	for i, value in ipairs(src) do
		if type(value) == "table" then
			local item = {}
			for k, v in pairs(value) do
				item[k] = v
			end
			dst[i] = item
		else
			dst[i] = value
		end
	end

	return dst
end

function Modifiers.resolve(mapDef)
	local src = mapDef and mapDef.modifiers or nil
	local resolved = {}

	for key, value in pairs(DEFAULTS) do
		resolved[key] = value
	end

	if src then
		for key in pairs(DEFAULTS) do
			if src[key] ~= nil then
				if key == "noBuildZones" or key == "limitedTowerTypes" then
					resolved[key] = copyArray(src[key])
				else
					resolved[key] = src[key]
				end
			end
		end
	end

	if resolved.noBuildZones and #resolved.noBuildZones == 0 then
		resolved.noBuildZones = nil
	end

	if resolved.limitedTowerTypes and #resolved.limitedTowerTypes == 0 then
		resolved.limitedTowerTypes = nil
	end

	return resolved
end

function Modifiers.applyNoBuildZones(mapMod, modifiers)
	local zones = modifiers and modifiers.noBuildZones
	if not zones then
		return
	end

	for _, zone in ipairs(zones) do
		local x = zone.x or zone[1]
		local y = zone.y or zone[2]
		local w = zone.w or zone[3] or 1
		local h = zone.h or zone[4] or 1

		if x and y then
			for gx = x, x + w - 1 do
				for gy = y, y + h - 1 do
					if gx >= 1 and gx <= Constants.GRID_W and gy >= 1 and gy <= Constants.GRID_H then
						mapMod.setBlocked(gx, gy)
					end
				end
			end
		end
	end
end

function Modifiers.isTowerAllowed(modifiers, kind)
	local allowed = modifiers and modifiers.limitedTowerTypes
	if not allowed then
		return true
	end

	for _, towerKind in ipairs(allowed) do
		if towerKind == kind then
			return true
		end
	end

	return false
end

local function signedPercent(value)
	local pct = math.floor(math.abs((value - 1.0) * 100) + 0.5)
	local sign = value >= 1.0 and "+" or "-"

	return sign .. pct .. "%"
end

local function signedMoney(value)
	return (value >= 0 and "+$" or "-$") .. tostring(math.abs(value))
end

local function towerListText(l10n, towerTypes)
	local names = {}
	for i, kind in ipairs(towerTypes or {}) do
		local def = TowerDefs[kind]
		names[i] = def and l10n(def.nameKey) or kind
	end

	return table.concat(names, ", ")
end

function Modifiers.getSummaryLines(modifiers, l10n)
	local lines = {}
	if not modifiers then
		return lines
	end

	for _, key in ipairs(SUMMARY_ORDER) do
		local value = modifiers[key]
		local text = nil

		if key == "startMoneyDelta" and value and value ~= 0 then
			text = l10n("mapModifier.startMoneyDelta", signedMoney(value))
		elseif key == "enemyHpMult" and value and value ~= 1.0 then
			text = l10n("mapModifier.enemyHpMult", signedPercent(value))
		elseif key == "enemySpeedMult" and value and value ~= 1.0 then
			text = l10n("mapModifier.enemySpeedMult", signedPercent(value))
		elseif key == "towerRangeMult" and value and value ~= 1.0 then
			text = l10n("mapModifier.towerRangeMult", signedPercent(value))
		elseif key == "rewardMult" and value and value ~= 1.0 then
			text = l10n("mapModifier.rewardMult", signedPercent(value))
		elseif key == "noBuildZones" and value and #value > 0 then
			text = l10n("mapModifier.noBuildZones", #value)
		elseif key == "bonusInterest" and value and value ~= 0 then
			text = l10n("mapModifier.bonusInterest", value)
		elseif key == "extraBossAdds" and value and value ~= 0 then
			text = l10n("mapModifier.extraBossAdds", value)
		elseif key == "limitedTowerTypes" and value and #value > 0 then
			text = l10n("mapModifier.limitedTowerTypes", towerListText(l10n, value))
		end

		if text then
			lines[#lines + 1] = text
		end
	end

	return lines
end

return Modifiers
