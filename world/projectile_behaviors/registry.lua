local Shared = require("world.projectile_behaviors.shared")

local Registry = {}
local descriptors = {}
local definitions = {}
local validRoles = {
	movement = true, collision = true, damage = true,
	status_proc = true, emission = true, drawing = true,
}
local hookAliases = {
	init = "on_shot", update = "on_tick", onHit = "on_hit",
	onKill = "on_kill", onExpire = "on_expire",
}
local canonicalHooks = { "on_shot", "on_tick", "on_hit", "on_kill", "on_expire" }

local function validateDescriptor(descriptor, known)
	assert(type(descriptor.id) == "string" and descriptor.id ~= "", "behavior descriptor requires an id")
	assert(not (known or descriptors)[descriptor.id], "duplicate projectile behavior id: " .. descriptor.id)
	assert(validRoles[descriptor.role], "unknown projectile behavior role for " .. descriptor.id .. ": " .. tostring(descriptor.role))
	local handlers = descriptor.handlers or {}
	if descriptor.hooks then
		for i = 1, #descriptor.hooks do
			local hook = hookAliases[descriptor.hooks[i]] or descriptor.hooks[i]
			assert(handlers[hook] or handlers[descriptor.hooks[i]], descriptor.id .. " declares hook without handler: " .. hook)
		end
	end
	return true
end

local function register(descriptor)
	validateDescriptor(descriptor)
	local handlers = descriptor.handlers or {}
	-- The sole compatibility boundary: definitions leave this function using only canonical names.
	for legacy, canonical in pairs(hookAliases) do
		if handlers[legacy] then
			assert(not handlers[canonical], descriptor.id .. " implements both " .. legacy .. " and " .. canonical)
			handlers[canonical] = handlers[legacy]
			handlers[legacy] = nil
		end
	end
	local declared = descriptor.hooks
	if declared then
		for i = 1, #declared do
			local hook = hookAliases[declared[i]] or declared[i]
			assert(handlers[hook], descriptor.id .. " declares hook without handler: " .. hook)
			declared[i] = hook
		end
	else
		declared = {}
		for i = 1, #canonicalHooks do
			local hook = canonicalHooks[i]
			if handlers[hook] then declared[#declared + 1] = hook end
		end
		if handlers.draw then declared[#declared + 1] = "draw" end
		if handlers.canHit then declared[#declared + 1] = "canHit" end
	end
	descriptor.hooks = declared
	descriptors[descriptor.id] = descriptor
	definitions[descriptor.id] = handlers
end

for _, moduleName in ipairs({ "movement", "collision", "damage", "status_proc", "emission", "drawing" }) do
	require("world.projectile_behaviors." .. moduleName)(Shared, register)
end

function Registry.get(id) return descriptors[id] end
Registry.validateDescriptor = validateDescriptor
function Registry.getRole(id)
	local descriptor = descriptors[id]
	return descriptor and descriptor.role or nil
end
function Registry.all() return descriptors end
function Registry.definitions() return definitions end
function Registry.validateBehaviorIds(behaviors)
	for i = 1, #behaviors do
		assert(descriptors[behaviors[i].id], "unknown projectile behavior id: " .. tostring(behaviors[i].id))
	end
	return true
end

return Registry
