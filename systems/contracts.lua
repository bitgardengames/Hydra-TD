-- Deterministic rotating contracts. Generation is deliberately independent of
-- love.math and local time so previews and runs agree across machines.
local Maps = require("world.map_defs")
local Constants = require("core.constants")

local Contracts = {RULESET_VERSION = 1, DEFAULT_CADENCE = "daily"}

local CADENCES = {daily = 1, weekly = 7}
local DIFFICULTIES = {"easy", "normal", "hard"}
local MUTATORS = {
	{id = "armored", kind = "enemy", enemyHpMultiplier = 1.15, label = "Armored enemies (+15% health)"},
	{id = "swift", kind = "enemy", enemySpeedMultiplier = 1.10, label = "Swift enemies (+10% speed)"},
	{id = "lean_economy", kind = "economy", incomeMultiplier = 0.90, label = "Lean economy (-10% income)"},
	{id = "head_start", kind = "economy", startingMoneyMultiplier = 1.20, label = "Head start (+20% starting money)"},
}
local RESTRICTIONS = {
	{id = "no_slow", excluded = {slow = true}, label = "No Slow towers"},
	{id = "no_cannon", excluded = {cannon = true}, label = "No Cannon towers"},
	{id = "no_poison", excluded = {poison = true}, label = "No Poison towers"},
	{id = "no_shock", excluded = {shock = true}, label = "No Shock towers"},
}
local OBJECTIVES = {
	{id = "score", direction = "max", label = "Highest score"},
	{id = "lives", direction = "max", label = "Most lives remaining"},
	{id = "fewest_leaks", direction = "min", label = "Fewest leaks"},
}

local function hash(text)
	-- Products stay below 2^53, making this identical with integer Lua and the
	-- double-number LuaJIT runtime shipped by LÖVE.
	local value = 216613626
	for i = 1, #text do value = (value * 131 + text:byte(i) * 97) % 2147483647 end
	return value
end

local function period(timestamp, cadence)
	local days = math.floor((tonumber(timestamp) or os.time()) / 86400)
	if cadence == "weekly" then
		-- 1970-01-01 was Thursday; make Monday the first day of a week.
		days = days - ((days + 3) % 7)
	end
	return days
end

local function choose(pool, seed)
	seed = (seed * 482 + 1) % 2147483647
	return pool[(seed % #pool) + 1], seed
end

local function copy(value)
	local out = {}
	for k, v in pairs(value) do out[k] = type(v) == "table" and copy(v) or v end
	return out
end

function Contracts.generate(timestamp, cadence, rulesetVersion)
	cadence = CADENCES[cadence] and cadence or Contracts.DEFAULT_CADENCE
	rulesetVersion = math.max(1, math.floor(tonumber(rulesetVersion) or Contracts.RULESET_VERSION))
	local startDay = period(timestamp, cadence)
	local key = table.concat({"contract", rulesetVersion, cadence, startDay}, ":")
	local seed = hash(key)
	local generated = {id = string.format("c%d-%s-%d", rulesetVersion, cadence, startDay), seed = seed,
		rulesetVersion = rulesetVersion, cadence = cadence, periodStartDay = startDay}

	local mapPool = {}
	for index, map in ipairs(Maps) do mapPool[#mapPool + 1] = {id = map.id, index = index, nameKey = map.nameKey} end
	generated.map, seed = choose(mapPool, seed)
	generated.difficulty, seed = choose(DIFFICULTIES, seed)
	generated.mutator, seed = choose(MUTATORS, seed)
	generated.restriction, seed = choose(RESTRICTIONS, seed)
	generated.objective = copy((choose(OBJECTIVES, seed)))
	generated.reward = {type = "achievement", id = "contract_clear", label = "Contract clear badge"}
	return generated
end

function Contracts.secondsUntilRotation(timestamp, cadence)
	timestamp = tonumber(timestamp) or os.time()
	cadence = CADENCES[cadence] and cadence or Contracts.DEFAULT_CADENCE
	local nextDay = period(timestamp, cadence) + CADENCES[cadence]
	return math.max(0, nextDay * 86400 - timestamp)
end

function Contracts.isTowerAllowed(contract, towerId)
	return not (contract and contract.restriction and contract.restriction.excluded[towerId])
end

function Contracts.objectiveValue(contract, run)
	local id = contract and contract.objective and contract.objective.id
	if id == "score" then return math.max(0, tonumber(run.score) or 0) end
	if id == "lives" then return math.max(0, tonumber(run.lives) or 0) end
	if id == "fewest_leaks" then return math.max(0, tonumber(run.totalLeaks) or 0) end
	return nil
end

function Contracts.validate(contract)
	if type(contract) ~= "table" or type(contract.id) ~= "string" or type(contract.seed) ~= "number" then return false end
	if not contract.map or not Maps[contract.map.index] or Maps[contract.map.index].id ~= contract.map.id then return false end
	local validDifficulty = contract.difficulty == "easy" or contract.difficulty == "normal" or contract.difficulty == "hard"
	if not validDifficulty or not contract.mutator or not contract.restriction or not contract.objective then return false end
	local allowed = 0
	for _, towerId in ipairs(Constants.TOWER_LIST) do if Contracts.isTowerAllowed(contract, towerId) then allowed = allowed + 1 end end
	return allowed > 0
end

return Contracts
