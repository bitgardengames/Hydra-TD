-- Tower mastery is derived from lifetime statistics.  Nothing in this module
-- changes combat or save data, so the progression curve can safely evolve.
local Mastery = {}

Mastery.levels = {
	{xp = 0, rankKey = "towerMastery.ranks.recruit", rewardKey = "towerMastery.rewards.recruit", rewardType = "dossier"},
	{xp = 600, rankKey = "towerMastery.ranks.operator", rewardKey = "towerMastery.rewards.operator", rewardType = "badge"},
	{xp = 1800, rankKey = "towerMastery.ranks.specialist", rewardKey = "towerMastery.rewards.specialist", rewardType = "soundTest"},
	{xp = 4200, rankKey = "towerMastery.ranks.expert", rewardKey = "towerMastery.rewards.expert", rewardType = "firingRange"},
	{xp = 8000, rankKey = "towerMastery.ranks.mastered", rewardKey = "towerMastery.rewards.mastered", rewardType = "challenge", mastered = true},
}

local function number(value)
	value = tonumber(value)
	return value and math.max(0, value) or 0
end

function Mastery.xp(history)
	history = type(history) == "table" and history or {}
	return math.floor(
		number(history.kills) +
		number(history.damage) / 100 +
		number(history.placements) * 8 +
		number(history.upgrades) * 12 +
		number(history.bestRunDamage) / 250
	)
end

function Mastery.calculate(history)
	local xp = Mastery.xp(history)
	local index = 1
	for i, level in ipairs(Mastery.levels) do
		if xp >= level.xp then index = i else break end
	end
	local current = Mastery.levels[index]
	local nextLevel = Mastery.levels[index + 1]
	local progress = nextLevel and math.max(0, math.min(1, (xp - current.xp) / (nextLevel.xp - current.xp))) or 1
	return {
		xp = xp, level = index, rankKey = current.rankKey, mastered = current.mastered == true,
		currentXP = current.xp, nextXP = nextLevel and nextLevel.xp or current.xp,
		progress = progress, nextLevel = nextLevel,
	}
end

function Mastery.unlockedRewards(history)
	local xp, rewards = Mastery.xp(history), {}
	for _, level in ipairs(Mastery.levels) do
		if xp >= level.xp then rewards[#rewards + 1] = level end
	end
	return rewards
end

return Mastery
