-- The canonical interpretation of a tower's authored level and specialization.
-- Keep branch mechanics here: runtime firing, previews, UI, emissions and the
-- balance readers must not independently guess which tier is active.
local Resolver = {}

local function copy(value, seen)
	if type(value) ~= "table" then
		return value
	end
	seen = seen or {}
	if seen[value] then
		return seen[value]
	end
	local out = {}
	seen[value] = out
	for key, item in pairs(value) do
		out[copy(key, seen)] = copy(item, seen)
	end
	return out
end

local function applyTier(behaviors, tier)
	tier = tier or {}
	for i = 1, #behaviors do
		local behavior, data = behaviors[i], behaviors[i].data
		if data then
			if behavior.id == "move_linear" and tier.travelDistance then data.dist = tier.travelDistance
			elseif behavior.id == "tick_damage" then
				if tier.tickRadius then data.radius = tier.tickRadius end
				if tier.tickRate then data.rate = tier.tickRate end
			elseif behavior.id == "apply_slow" then
				data.dur = (data.dur or 0) + (tier.slowDurAdd or 0)
				if tier.slowFactor then
					data.factor = tier.slowFactor
				end
			elseif behavior.id == "slow_field" then
				if tier.fieldRadius then
					data.radius = tier.fieldRadius
				end
				if tier.fieldLifetime then
					data.life = tier.fieldLifetime
				end
				if tier.fieldFactor then
					data.factor = tier.fieldFactor
				end
			elseif behavior.id == "apply_poison" then
				if tier.poisonDPS then
					data.dps = tier.poisonDPS
				end
				if tier.poisonDuration then
					data.dur = tier.poisonDuration
				end
				if tier.poisonStackCap then
					data.maxStacks = tier.poisonStackCap
				end
				data.dur = (data.dur or 0) + (tier.poisonDurAdd or 0)
				data.dps = (data.dps or 0) * (tier.poisonDpsMult or 1)
				if tier.stackAdd then
					data.maxStacks = math.max(1, (data.maxStacks or 1) + tier.stackAdd)
				end
			elseif behavior.id == "infect_spread" then
				if tier.spreadRadius then
					data.radius = tier.spreadRadius
				end
				if tier.transferFraction then
					data.stackMult = tier.transferFraction
				end
				if tier.recipientCap then
					data.recipientCap = tier.recipientCap
				end
			elseif behavior.id == "aoe_damage" then
				if tier.splashRadius then data.radius = tier.splashRadius
				elseif tier.splashAdd then data.radius = math.max(1, (data.radius or 1) + tier.splashAdd) end
				if tier.splashFalloff then data.falloff = tier.splashFalloff end
			elseif behavior.id == "pierce" and tier.pierceMaxHits then data.maxHits = tier.pierceMaxHits
			elseif behavior.id == "hit_chain" then
				if tier.chainJumps then
					data.jumps = tier.chainJumps
				end
				if tier.chainRadius then
					data.radius = tier.chainRadius
				end
				if tier.chainFalloff then
					data.falloff = tier.chainFalloff
				end
			elseif behavior.id == "capacitor" then
				if tier.capacitorThreshold then
					data.threshold = tier.capacitorThreshold
				end
				if tier.dischargeMult then
					data.dischargeMult = tier.dischargeMult
				end
			end
		end
	end
end

function Resolver.validate(definitions)
	local ids = {}
	for kind, def in pairs(definitions) do
		local upgrade = def.upgrade or {}
		local branches = upgrade.branches or {}
		for level = 2, 3 do
			assert(upgrade.tiers and upgrade.tiers[level], kind .. " missing normal tier " .. level)
		end
		local count = 0
		for id, branch in pairs(branches) do
			count = count + 1
			assert(type(id) == "string" and id:match("^[a-z][a-z0-9_]*$"), kind .. " has an unstable branch id")
			assert(not ids[id], "duplicate branch id: " .. id)
			assert(branch.id == id, kind .. "/" .. id .. " must declare its stable id")
			ids[id] = kind
			for level = 4, 5 do
				assert(branch.tiers and branch.tiers[level], kind .. "/" .. id .. " missing specialized tier " .. level)
			end
		end
		assert(count == 2, kind .. " must have exactly two branches")
	end
	return true
end

function Resolver.resolve(tower, options)
	options = options or {}
	local def = assert(options.def or tower.def, "tower definition required")
	local level = math.max(1, options.level or tower.level or 1)
	local specialization = options.specialization
	if specialization == nil then
		specialization = tower.specialization
	end
	local branches = def.upgrade and def.upgrade.branches
	local upgrade = def.upgrade or {}
	local branch = specialization and branches and branches[specialization]
	if level >= 4 then
		assert(branch and branch.tiers[level], "invalid specialized tier")
	elseif specialization then
		assert(branch, "invalid specialization")
	end
	local tier = level == 1 and (upgrade.base or {})
		or level <= 3 and assert(upgrade.tiers and upgrade.tiers[level], "invalid normal tier")
		or branch.tiers[level]
	local baseBehaviors = level >= 4 and branch.fireProfile or def.behaviors or {}
	local behaviors = copy(baseBehaviors)
	applyTier(behaviors, tier)
	local modifiers = options.modifiers or {damageMult = 1, fireRateMult = 1, rangeAdd = 0}
	return {
		kind = tower.kind, level = level, specialization = specialization,
		branch = branch, tier = copy(tier), targetingPolicy = branch and branch.targetingPolicy or nil,
		stats = {
			damage = def.damage * (tier.dmgMult or 1) * (modifiers.damageMult or 1),
			fireRate = def.fireRate * (tier.fireMult or 1) * (modifiers.fireRateMult or 1),
			range = def.range + (tier.rangeAdd or 0) + (modifiers.rangeAdd or 0),
			projSpeed = tier.projSpeed or def.projSpeed,
		},
		-- This is an owned snapshot. Consumers may build mutable contexts from it;
		-- no authored definition or other tower can be changed through the result.
		profile = {output = branch and branch.output or nil, behaviors = behaviors},
	}
end

return Resolver
