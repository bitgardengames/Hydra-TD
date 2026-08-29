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

local definitions, definitionCount = Registry.all(), 0
for id, handlers in pairs(definitions) do
	definitionCount = definitionCount + 1
	assert(reachable[id], "registry contains behavior unreachable from core plans: " .. id)
	assert(type(handlers) == "table", "missing handlers: " .. id)
	assert(handlers.role == nil and handlers.hooks == nil,
		"fixed behavior definitions must not contain composition metadata: " .. id)
	assert(handlers.onHit == nil and handlers.onKill == nil and handlers.onExpire == nil
		and handlers.on_shot == nil and handlers.on_tick == nil and handlers.on_hit == nil,
		"fixed behavior definitions must only use lifecycle operation names: " .. id)
end
local reachableCount = 0
for id in pairs(reachable) do
	reachableCount = reachableCount + 1
	assert(Registry.get(id), "core plan references unknown behavior: " .. id)
end
assert(definitionCount == reachableCount, "registry must contain exactly the reachable core behaviors")

local ok = pcall(Registry.compile, {{ id = "not_a_core_behavior" }})
assert(not ok, "fixed profiles must reject unknown behavior IDs when built")

print("projectile behavior registry fixtures passed (6 core plans, " .. definitionCount .. " behaviors)")
