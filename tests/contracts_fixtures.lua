-- Dependency-free deterministic contract and persistence fixtures.
package.path = "./?.lua;./?/init.lua;" .. package.path

local Contracts = require("systems.contracts")
local Maps = require("world.map_defs")

local day = 86400
local beforeMidnight = 20000 * day - 1
local afterMidnight = 20000 * day
local dailyBefore = Contracts.generate(beforeMidnight, "daily", 1)
local dailyAfter = Contracts.generate(afterMidnight, "daily", 1)
assert(dailyBefore.id ~= dailyAfter.id, "daily contract did not rotate at UTC midnight")
assert(Contracts.secondsUntilRotation(beforeMidnight, "daily") == 1, "daily boundary countdown is not UTC based")

-- Exercise a complete Monday-through-Sunday period and its boundary.
local monday = 20000 - ((20000 + 3) % 7)
local weekly = Contracts.generate(monday * day, "weekly", 1)
for offset = 1, 6 do
	assert(Contracts.generate((monday + offset) * day, "weekly", 1).id == weekly.id,
		"weekly contract rotated before its boundary")
end
assert(Contracts.generate((monday + 7) * day, "weekly", 1).id ~= weekly.id,
	"weekly contract did not rotate after seven days")

local repeatGeneration = Contracts.generate(beforeMidnight, "daily", 1)
assert(repeatGeneration.id == dailyBefore.id and repeatGeneration.seed == dailyBefore.seed,
	"repeat generation changed contract identity")
assert(Contracts.generate(beforeMidnight, "daily", 2).id ~= dailyBefore.id
	and Contracts.generate(beforeMidnight, "daily", 2).seed ~= dailyBefore.seed,
	"ruleset version did not namespace identity and seed")

for cadence in pairs({daily = true, weekly = true}) do
	for periodIndex = 0, 500 do
		local contract = Contracts.generate((19000 + periodIndex) * day, cadence, 1)
		assert(Contracts.validate(contract), "generated an invalid " .. cadence .. " contract")
		assert(Maps[contract.map.index].id == contract.map.id, "selected map/index disagree")
	end
end

print("contract generation fixtures passed")
