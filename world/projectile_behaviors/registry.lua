local Shared = require("world.projectile_behaviors.shared")

-- The registry is deliberately only a lookup table for the behaviors used by
-- the six checked-in tower plans. Profiles are compiled once when their tuned
-- values are built; projectiles never validate or compose descriptors at run
-- time.
local definitions = {}

local function register(id, handlers)
	assert(type(id) == "string" and id ~= "", "projectile behavior requires an id")
	assert(not definitions[id], "duplicate projectile behavior id: " .. id)
	definitions[id] = handlers
end

for _, moduleName in ipairs({ "movement", "collision", "damage", "status_proc", "emission", "drawing" }) do
	require("world.projectile_behaviors." .. moduleName)(Shared, register)
end

local Registry = {}

function Registry.get(id)
	return definitions[id]
end

function Registry.all()
	return definitions
end

function Registry.compile(behaviors)
	local profile = {
		behaviors = behaviors,
	}

	for i = 1, #behaviors do
		local behavior = behaviors[i]
		local handlers = assert(definitions[behavior.id],
			"unknown projectile behavior id: " .. tostring(behavior.id))
		for _, operation in ipairs({ "init", "update", "hit", "expire", "draw", "canHit" }) do
			local fn = handlers[operation]
			if fn then
				local functionsKey = operation .. "Fns"
				local dataKey = operation .. "Data"
				local functions = profile[functionsKey]
				if not functions then
					functions = {}
					profile[functionsKey] = functions
					profile[dataKey] = {}
				end
				functions[#functions + 1] = fn
				profile[dataKey][#functions] = behavior.data
			end
		end
	end

	return profile
end

return Registry
