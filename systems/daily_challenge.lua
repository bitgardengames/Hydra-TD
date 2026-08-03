local Maps = require("world.map_defs")
local Daily = {}

Daily.RULE_VERSION = 1
Daily.rules = {
	[1] = {
		difficulties = {"normal", "hard", "easy"},
		restrictions = {
			{"plasma", "poison"},
			{"cannon", "shock"},
			{"lancer", "slow"},
		},
		mutators = {
			{id = "armored_rush", label = "Armored Rush"},
			{id = "lean_economy", label = "Lean Economy"},
			{id = "swift_horde", label = "Swift Horde"},
		},
	},
}

local function hash(text)
	-- djb2 kept below 2^53 so all supported Lua number builds agree.
	local value = 5381
	for i = 1, #text do value = (value * 33 + text:byte(i)) % 2147483647 end
	return math.max(1, value)
end

function Daily.utcDate(timestamp)
	return os.date("!%Y-%m-%d", timestamp or os.time())
end

function Daily.forDate(date, version)
	date = date or Daily.utcDate()
	version = version or Daily.RULE_VERSION
	local rules = assert(Daily.rules[version], "unknown daily rule version")
	local seed = hash("hydra-daily:" .. version .. ":" .. date)
	local function pick(list, salt) return list[((seed + salt) % #list) + 1] end
	local map = Maps[((seed + 17) % #Maps) + 1]
	local restricted = pick(rules.restrictions, 31)
	local mutator = pick(rules.mutators, 47)
	return {
		date = date, seed = seed, ruleVersion = version,
		mapId = map.id, mapIndex = ((seed + 17) % #Maps) + 1,
		difficulty = pick(rules.difficulties, 23),
		restrictedTowers = restricted,
		mutators = {mutator},
	}
end

function Daily.today() return Daily.forDate(Daily.utcDate()) end

function Daily.isTowerAllowed(challenge, kind)
	for _, blocked in ipairs(challenge and challenge.restrictedTowers or {}) do
		if blocked == kind then return false end
	end
	return true
end

function Daily.score(completed, lives, money, waves, leaks)
	local parts = {
		completion = completed and 10000 or 0,
		lives = math.max(0, math.floor(tonumber(lives) or 0)) * 250,
		money = math.max(0, math.floor(tonumber(money) or 0)),
		waves = math.max(0, math.floor(tonumber(waves) or 0)) * 500,
		leaks = -math.max(0, math.floor(tonumber(leaks) or 0)) * 200,
	}
	parts.total = math.max(0, parts.completion + parts.lives + parts.money + parts.waves + parts.leaks)
	return parts
end

function Daily.restrictionText(challenge)
	return table.concat(challenge.restrictedTowers or {}, ", ")
end

return Daily
