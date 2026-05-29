local Challenges = {}

local DEFAULT_CHALLENGES = {
	"no_leaks",
	"three_tower_types",
	"no_selling",
	"max_tier_3",
	"endless_wave_30",
}

local MAP_CHALLENGES = {
	riverbend = {"no_leaks", "three_tower_types", "no_selling"},
	switchback = {"no_leaks", "max_tier_3", "three_tower_types"},
	highpass = {"no_leaks", "no_selling", "endless_wave_30"},
	roundabout = {"three_tower_types", "max_tier_3", "endless_wave_30"},
	gauntlet = {"no_selling", "max_tier_3", "endless_wave_30"},
}

Challenges.defs = {
	no_leaks = {
		id = "no_leaks",
		nameKey = "challenge.no_leaks.name",
		descKey = "challenge.no_leaks.desc",
		summaryKey = "challenge.no_leaks.summary",
		kind = "no_leaks",
	},

	three_tower_types = {
		id = "three_tower_types",
		nameKey = "challenge.three_tower_types.name",
		descKey = "challenge.three_tower_types.desc",
		summaryKey = "challenge.three_tower_types.summary",
		kind = "tower_type_limit",
		maxTowerTypes = 3,
	},

	no_selling = {
		id = "no_selling",
		nameKey = "challenge.no_selling.name",
		descKey = "challenge.no_selling.desc",
		summaryKey = "challenge.no_selling.summary",
		kind = "no_selling",
	},

	max_tier_3 = {
		id = "max_tier_3",
		nameKey = "challenge.max_tier_3.name",
		descKey = "challenge.max_tier_3.desc",
		summaryKey = "challenge.max_tier_3.summary",
		kind = "max_tower_level",
		maxLevel = 3,
	},

	endless_wave_30 = {
		id = "endless_wave_30",
		nameKey = "challenge.endless_wave_30.name",
		descKey = "challenge.endless_wave_30.desc",
		summaryKey = "challenge.endless_wave_30.summary",
		kind = "endless_wave",
		targetWave = 30,
	},
}

local function getMapChallengeIds(map)
	if map and type(map.challenges) == "table" then
		return map.challenges
	end

	if map and MAP_CHALLENGES[map.id] then
		return MAP_CHALLENGES[map.id]
	end

	return DEFAULT_CHALLENGES
end

function Challenges.getForMap(map)
	local ids = getMapChallengeIds(map)
	local out = {}

	for i = 1, #ids do
		local def = Challenges.defs[ids[i]]

		if def then
			out[#out + 1] = def
		end
	end

	return out
end

function Challenges.getById(id)
	return id and Challenges.defs[id] or nil
end

function Challenges.isAvailableForMap(map, challengeId)
	if not challengeId then
		return true
	end

	local defs = Challenges.getForMap(map)

	for i = 1, #defs do
		if defs[i].id == challengeId then
			return true
		end
	end

	return false
end

function Challenges.startRun(state, map)
	local selectedId = state.selectedChallengeId

	if not Challenges.isAvailableForMap(map, selectedId) then
		selectedId = nil
	end

	state.challenge = {
		selectedId = selectedId,
		activeId = selectedId,
		completed = false,
		towerKinds = {},
		towerKindCount = 0,
		sells = 0,
		maxTowerLevel = 1,
		bestWaveCleared = 0,
	}
end

function Challenges.clearRun(state)
	state.challenge = {
		selectedId = state.selectedChallengeId,
		activeId = nil,
		completed = false,
		towerKinds = {},
		towerKindCount = 0,
		sells = 0,
		maxTowerLevel = 1,
		bestWaveCleared = 0,
	}
end

function Challenges.onTowerBuilt(state, kind)
	local run = state.challenge

	if not run or not run.activeId or not kind then
		return
	end

	if not run.towerKinds[kind] then
		run.towerKinds[kind] = true
		run.towerKindCount = (run.towerKindCount or 0) + 1
	end
end

function Challenges.onTowerUpgraded(state, level)
	local run = state.challenge

	if not run or not run.activeId then
		return
	end

	run.maxTowerLevel = math.max(run.maxTowerLevel or 1, level or 1)
end

function Challenges.onTowerSold(state)
	local run = state.challenge

	if not run or not run.activeId then
		return
	end

	run.sells = (run.sells or 0) + 1
end

function Challenges.onWaveCleared(state, wave)
	local run = state.challenge

	if not run or not run.activeId then
		return
	end

	run.bestWaveCleared = math.max(run.bestWaveCleared or 0, wave or 0)
end

function Challenges.isEndlessChallenge(challengeId)
	local def = Challenges.getById(challengeId)

	return def and def.kind == "endless_wave"
end

function Challenges.evaluate(state, completed)
	local run = state.challenge
	local def = run and Challenges.getById(run.activeId)

	if not def or run.completed then
		return false
	end

	if def.kind == "endless_wave" then
		return (run.bestWaveCleared or 0) >= (def.targetWave or 0)
	end

	if not completed then
		return false
	end

	if def.kind == "no_leaks" then
		return (state.totalLeaks or 0) == 0
	elseif def.kind == "tower_type_limit" then
		return (run.towerKindCount or 0) <= (def.maxTowerTypes or 0)
	elseif def.kind == "no_selling" then
		return (run.sells or 0) == 0
	elseif def.kind == "max_tower_level" then
		return (run.maxTowerLevel or 1) <= (def.maxLevel or 1)
	end

	return false
end

function Challenges.markCompleted(state)
	if state.challenge then
		state.challenge.completed = true
	end
end

return Challenges
