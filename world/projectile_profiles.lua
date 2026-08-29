-- Fixed projectile plans for the six core towers. Tower upgrades may tune the
-- numbers on a plan, but they never replace, inherit, or mix its behaviors.
local Profiles = {}
local Registry = require("world.projectile_behaviors.registry")
local cache = setmetatable({}, { __mode = "k" })

local function cloneBehavior(behavior)
	local copy = { id = behavior.id }
	if behavior.data then
		copy.data = {}
		for key, value in pairs(behavior.data) do copy.data[key] = value end
	end
	return copy
end

local function build(tower)
	local behaviors = {}
	for i = 1, #tower.def.behaviors do
		behaviors[i] = cloneBehavior(tower.def.behaviors[i])
	end

	local upgrades = math.max(0, (tower.level or 1) - 1)
	local upgrade = tower.def.upgrade or {}
	for i = 1, #behaviors do
		local behavior, data = behaviors[i], behaviors[i].data
		if data and behavior.id == "apply_slow" then
			data.dur = (data.dur or 0) + (upgrade.slowDurAdd or 0) * upgrades
		elseif data and behavior.id == "apply_poison" then
			data.dur = (data.dur or 0) + (upgrade.poisonDurAdd or 0) * upgrades
			data.dps = (data.dps or 0) * ((upgrade.poisonDpsMult or 1) ^ upgrades)
			data.maxStacks = math.max(1, (data.maxStacks or 1) + (upgrade.stackAdd or 0) * upgrades)
		elseif data and behavior.id == "aoe_damage" then
			data.radius = math.max(1, (data.radius or 1) + (upgrade.splashAdd or 0) * upgrades)
		end
	end
	return Registry.compile(behaviors)
end

function Profiles.get(tower)
	assert(tower and tower.def and tower.def.behaviors, "tower requires a projectile plan")
	local level = tower.level or 1
	local byLevel = cache[tower.def]
	if not byLevel then
		byLevel = {}
		cache[tower.def] = byLevel
	end
	if not byLevel[level] then byLevel[level] = build(tower) end
	return byLevel[level]
end

return Profiles
