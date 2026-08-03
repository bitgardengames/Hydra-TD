-- Elite affixes are kept separate from archetype definitions so a spawned enemy
-- can be composed without ever mutating the shared, immutable EnemyDefs tables.
local Affixes = {
	fortified = {
		id = "fortified",
		nameKey = "enemyAffix.fortified.name",
		descriptionKey = "enemyAffix.fortified.description",
		icon = "◆",
		color = {0.95, 0.55, 0.18},
		cost = 2,
		tags = {"defense"},
		excludes = {"evasive"},
		eligible = {excludeBosses = true, minRadius = 10},
		behavior = {hpMultiplier = 1.45, rewardMultiplier = 1.35, damageTakenMultiplier = 0.82},
	},
	relentless = {
		id = "relentless",
		nameKey = "enemyAffix.relentless.name",
		descriptionKey = "enemyAffix.relentless.description",
		icon = "▲",
		color = {0.72, 0.38, 1.0},
		cost = 2,
		tags = {"speed", "evasive"},
		excludes = {"defense"},
		eligible = {excludeBosses = true, maxBaseSpeed = 125},
		behavior = {speedMultiplier = 1.18, rewardMultiplier = 1.25, statusDurationMultiplier = 0.55},
	},
}

Affixes.order = {"fortified", "relentless"}

function Affixes.isEligible(id, enemyDef, selectedTags)
	local affix = Affixes[id]
	if not affix or not enemyDef then return false end
	local rule = affix.eligible or {}
	if rule.excludeBosses and enemyDef.boss then return false end
	if rule.minRadius and (enemyDef.radius or 0) < rule.minRadius then return false end
	if rule.maxBaseSpeed and (enemyDef.speed or 0) > rule.maxBaseSpeed then return false end
	for _, tag in ipairs(affix.excludes or {}) do
		if selectedTags and selectedTags[tag] then return false end
	end
	return true
end

return Affixes
