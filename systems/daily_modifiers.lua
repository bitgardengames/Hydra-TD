-- Declarative gameplay transformations for generated/daily runs.
local Modifiers = {}

Modifiers.definitions = {
	swarm = {health = 0.60, count = 1.60, minSpacing = 0.10},
	blitz = {speed = 1.25},
	fortified = {health = 1.40, count = 0.75},
	relentless = {automaticWaves = true, earlyStartReward = false},
	one_life = {lives = 1},
}

local function ids(rules)
	return (rules and (rules.modifiers or rules.dailyModifiers)) or {}
end

local function normalize(id)
	return type(id) == "string" and id:lower():gsub(" ", "_") or id
end

function Modifiers.resolve(rules)
	local result = {health = 1, count = 1, speed = 1, automaticWaves = false,
		earlyStartReward = true, oneLife = false}
	for _, id in ipairs(ids(rules)) do
		id = normalize(id)
		local def = Modifiers.definitions[id]
		if def then
			result.health = result.health * (def.health or 1)
			result.count = result.count * (def.count or 1)
			result.speed = result.speed * (def.speed or 1)
			if def.automaticWaves then result.automaticWaves, result.earlyStartReward = true, false end
			if def.lives == 1 then result.oneLife = true end
			result.minSpacing = math.max(result.minSpacing or 0, def.minSpacing or 0)
		end
	end
	return result
end

function Modifiers.validate(rules)
	local seen = {}
	for _, id in ipairs(ids(rules)) do
		id = normalize(id)
		if not Modifiers.definitions[id] then return false, "unknown_modifier" end
		seen[id] = true
	end
	if seen.swarm and seen.fortified then return false, "incompatible_modifiers" end
	return true
end

function Modifiers.applyToGroup(group, rules)
	local resolved, copy = Modifiers.resolve(rules), {}
	for key, value in pairs(group) do copy[key] = value end
	if copy.kind ~= "boss" and not copy.boss then
		copy.count = math.max(1, math.floor((copy.count or 1) * resolved.count + 0.5))
		if copy.spacing and resolved.count > 1 then
			copy.spacing = math.max(resolved.minSpacing or 0, copy.spacing / resolved.count)
		end
	end
	return copy
end

function Modifiers.applyToEnemy(enemy, rules)
	local resolved = Modifiers.resolve(rules)
	enemy.maxHp = enemy.maxHp * resolved.health
	enemy.hp = math.min(enemy.maxHp, enemy.hp * resolved.health)
	enemy.baseSpeed = enemy.baseSpeed * resolved.speed
	enemy.speed = enemy.baseSpeed * (enemy.slowFactor or 1)
	return enemy
end

function Modifiers.configureRun(state)
	local resolved = Modifiers.resolve(state and state.runRules)
	if resolved.oneLife then state.lives, state.maxLives = 1, 1 end
	return resolved
end

function Modifiers.shouldAutoStart(state)
	return Modifiers.resolve(state and state.runRules).automaticWaves
end

return Modifiers
