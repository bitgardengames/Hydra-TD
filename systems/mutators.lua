local State = require("core.state")
local Defs = require("systems.mutator_defs")

local Mutators = {}

local function idOf(entry)
	return type(entry) == "table" and entry.id or entry
end

function Mutators.resolve(challenge)
	local resolved = {}
	for _, entry in ipairs(challenge and challenge.mutators or {}) do
		local id = idOf(entry)
		local def = Defs[id]
		if def then resolved[#resolved + 1] = {id = id, def = def} end
	end
	return resolved
end

function Mutators.active()
	return Mutators.resolve(State.dailyChallenge)
end

local function eachValue(field, initial, combine)
	local value = initial
	for _, active in ipairs(Mutators.active()) do
		local candidate = active.def[field]
		if candidate ~= nil then value = combine(value, candidate) end
	end
	return value
end

function Mutators.isTowerAllowed(kind)
	for _, active in ipairs(Mutators.active()) do
		for _, blocked in ipairs(active.def.restrictedTowerKinds or {}) do
			if blocked == kind then return false end
		end
	end
	return true
end

function Mutators.getTowerCap()
	return eachValue("towerCap", math.huge, math.min)
end

function Mutators.canPlaceTower(kind, currentCount)
	if not Mutators.isTowerAllowed(kind) then return false, "restricted" end
	if currentCount >= Mutators.getTowerCap() then return false, "tower_cap" end
	return true
end

function Mutators.canSell()
	return not eachValue("sellingDisabled", false, function(a, b) return a or b end)
end

function Mutators.startingCurrency(base)
	return math.floor(eachValue("startingCurrencyMultiplier", base,
		function(value, multiplier) return value * multiplier end) + 0.5)
end

function Mutators.enemySpeedMultiplier()
	return eachValue("enemySpeedMultiplier", 1, function(a, b) return a * b end)
end

function Mutators.abilityRechargeMultiplier()
	return eachValue("abilityRechargeMultiplier", 1, function(a, b) return a * b end)
end

function Mutators.affixPowerMultiplier()
	return eachValue("affixPowerMultiplier", 1, function(a, b) return a * b end)
end

return Mutators
