-- Registry integrity and checked-in behavior reference fixtures.
package.path = "./?.lua;./?/init.lua;" .. package.path
love = love or { graphics = {} }

package.loaded["core.theme"] = { tower = {
	slow = {}, lancer = {}, poison = {}, cannon = {}, shock = {}, plasma = {},
} }

local Registry = require("world.projectile_behaviors.registry")
local TowerDefs = require("world.tower_defs")
local ModuleDefs = require("systems.module_defs")

local validRoles = {
	movement = true, collision = true, damage = true,
	status_proc = true, emission = true, drawing = true,
}
local descriptors = Registry.all()
for id, descriptor in pairs(descriptors) do
	assert(descriptor.id == id, "descriptor key/id mismatch: " .. id)
	assert(validRoles[descriptor.role], "invalid role on descriptor: " .. id)
	assert(type(descriptor.hooks) == "table", "missing supported hooks: " .. id)
	assert(type(descriptor.handlers) == "table", "missing handlers: " .. id)
	for i = 1, #descriptor.hooks do
		assert(descriptor.handlers[descriptor.hooks[i]],
			id .. " declares hook without a handler: " .. descriptor.hooks[i])
	end
end

local ok = pcall(Registry.validateDescriptor, { id = "move_homing", role = "movement", handlers = {} })
assert(not ok, "duplicate behavior IDs must be rejected")
ok = pcall(Registry.validateDescriptor, { id = "fixture_bad_role", role = "mystery", handlers = {} })
assert(not ok, "unknown behavior roles must be rejected")
ok = pcall(Registry.validateDescriptor, { id = "fixture_missing_handler", role = "damage", hooks = { "on_hit" }, handlers = {} })
assert(not ok, "declared hooks without handlers must be rejected")

local checked, visited = 0, {}
local function validateBehaviorLists(value, path)
	if type(value) ~= "table" or visited[value] then return end
	visited[value] = true
	if type(value.behaviors) == "table" then
		for i = 1, #value.behaviors do
			local behavior = value.behaviors[i]
			assert(Registry.get(behavior.id), path .. " references unknown behavior: " .. tostring(behavior.id))
			checked = checked + 1
		end
	end
	for key, child in pairs(value) do
		validateBehaviorLists(child, path .. "." .. tostring(key))
	end
end
validateBehaviorLists(TowerDefs, "TowerDefs")
validateBehaviorLists(ModuleDefs, "ModuleDefs")

-- Module apply closures retain their behavior literals, so also inspect those authored IDs.
local moduleSource = assert(io.open("systems/module_defs.lua", "r")):read("*a")
for id in moduleSource:gmatch("{%s*id%s*=%s*\"([^\"]+)\"") do
	assert(Registry.get(id), "ModuleDefs source references unknown behavior: " .. id)
	checked = checked + 1
end
assert(checked > 0, "fixture did not discover any tower or module behaviors")

print("projectile behavior registry fixtures passed (" .. checked .. " references)")
