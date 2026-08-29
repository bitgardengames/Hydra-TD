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
		init = {},
		update = {},
		hit = {},
		expire = {},
		draw = {},
		canHit = {},
	}

	for i = 1, #behaviors do
		local behavior = behaviors[i]
		local handlers = assert(definitions[behavior.id],
			"unknown projectile behavior id: " .. tostring(behavior.id))
		for _, operation in ipairs({ "init", "update", "hit", "expire", "draw", "canHit" }) do
			if handlers[operation] then
				local list = profile[operation]
				list[#list + 1] = { fn = handlers[operation], data = behavior.data }
			end
		end
	end

	return profile
end

return Registry
