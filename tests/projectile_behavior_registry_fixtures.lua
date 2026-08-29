-- Registry integrity for the six fixed core projectile plans.
package.path = "./?.lua;./?/init.lua;" .. package.path
love = love or { graphics = {} }

package.loaded["core.theme"] = { tower = {
	slow = {}, lancer = {}, poison = {}, cannon = {}, shock = {}, plasma = {},
} }

local Registry = require("world.projectile_behaviors.registry")
local TowerDefs = require("world.tower_defs")

local expectedPlans = {
	slow = {"move_homing", "hit_damage", "apply_slow", "draw_slow"},
	lancer = {"move_homing", "hit_circle", "hit_damage", "lancer_hit_fx", "draw_lancer"},
	poison = {"move_homing", "hit_circle", "hit_damage", "apply_poison", "draw_poison"},
	cannon = {"move_to_target_point", "aoe_damage", "draw_cannon"},
	shock = {"emit_on_target", "hit_chain", "chain_zap_fx"},
	plasma = {"move_linear", "tick_damage", "draw_plasma"},
}
local validRoles = {
	movement = true, collision = true, damage = true,
	status_proc = true, emission = true, drawing = true,
}
local reachable, planCount = {}, 0
for kind, expected in pairs(expectedPlans) do
	local plan = assert(TowerDefs[kind] and TowerDefs[kind].behaviors, "missing core plan: " .. kind)
	assert(#plan == #expected, kind .. " behavior plan length changed")
	for i = 1, #expected do
		assert(plan[i].id == expected[i], kind .. " behavior plan changed at position " .. i)
		reachable[expected[i]] = true
	end
	planCount = planCount + 1
end
assert(planCount == 6, "fixture must validate exactly six core projectile plans")

local descriptors, descriptorCount = Registry.all(), 0
for id, descriptor in pairs(descriptors) do
	descriptorCount = descriptorCount + 1
	assert(reachable[id], "registry contains behavior unreachable from core plans: " .. id)
	assert(descriptor.id == id, "descriptor key/id mismatch: " .. id)
	assert(validRoles[descriptor.role], "invalid role on descriptor: " .. id)
	assert(type(descriptor.hooks) == "table", "missing supported hooks: " .. id)
	assert(type(descriptor.handlers) == "table", "missing handlers: " .. id)
	for i = 1, #descriptor.hooks do
		assert(descriptor.handlers[descriptor.hooks[i]], id .. " declares hook without a handler")
	end
end
local reachableCount = 0
for id in pairs(reachable) do
	reachableCount = reachableCount + 1
	assert(Registry.get(id), "core plan references unknown behavior: " .. id)
end
assert(descriptorCount == reachableCount, "registry must contain exactly the reachable core behaviors")

local ok = pcall(Registry.validateDescriptor, { id = "move_homing", role = "movement", handlers = {} })
assert(not ok, "duplicate behavior IDs must be rejected")
ok = pcall(Registry.validateDescriptor, { id = "fixture_bad_role", role = "mystery", handlers = {} })
assert(not ok, "unknown behavior roles must be rejected")
ok = pcall(Registry.validateDescriptor, { id = "fixture_missing_handler", role = "damage", hooks = { "on_hit" }, handlers = {} })
assert(not ok, "declared hooks without handlers must be rejected")

print("projectile behavior registry fixtures passed (6 core plans, " .. descriptorCount .. " behaviors)")
