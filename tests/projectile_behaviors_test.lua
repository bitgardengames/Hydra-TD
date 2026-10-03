-- Run with a Lua interpreter from the repository root.
package.path = "./?.lua;./?/init.lua;" .. package.path

package.loaded["systems.behavior_context"] = { cloneBehavior = function(behavior) return behavior end }
package.loaded["world.projectile_behaviors.registry"] = {
	definitions = function() return {} end,
	validateBehaviorIds = function() end,
}
package.loaded["world.projectile_behaviors.shared"] = {}

local ProjectileBehaviors = require("world.projectile_behaviors")

local function hook(fn, data)
	return { fn = fn, data = data }
end

-- Fire-and-forget shot hooks all run in declaration order.
local shotCalls = {}
local shotProjectile = { _hooks = { on_shot = {
	hook(function(_, data) shotCalls[#shotCalls + 1] = data end, "first"),
	hook(function(_, data) shotCalls[#shotCalls + 1] = data end, "second"),
} } }
ProjectileBehaviors.init(shotProjectile)
assert(table.concat(shotCalls, ",") == "first,second")

-- Tick dispatch returns the first non-nil result and skips later hooks.
local tickCalls = {}
local tickProjectile = { _hooks = { on_tick = {
	hook(function(_, dt, data) tickCalls[#tickCalls + 1] = data .. dt end, "first"),
	hook(function(_, _, data) tickCalls[#tickCalls + 1] = data return false end, "second"),
	hook(function() tickCalls[#tickCalls + 1] = "third" return "later" end),
} } }
assert(ProjectileBehaviors.update(tickProjectile, 0.5) == false)
assert(#tickCalls == 2 and tickCalls[1] == "first0.5" and tickCalls[2] == "second")

-- Every hit hook runs, consumption is aggregated, and kill hooks run afterward.
local hitCalls = {}
local hitProjectile = { x = 10, y = 20, _hooks = {} }
hitProjectile._hooks.on_hit = {
	hook(function(p) hitCalls[#hitCalls + 1] = "hit-one:" .. p.x .. ":" .. p.y return "consume" end),
	hook(function() hitCalls[#hitCalls + 1] = "hit-two" end),
}
hitProjectile._hooks.on_kill = {
	hook(function(p) hitCalls[#hitCalls + 1] = "kill:" .. p.x .. ":" .. p.y end),
}
hitProjectile._hooks.on_expire = {
	hook(function() hitCalls[#hitCalls + 1] = "expire" end),
}
local deadEnemy = { hp = 0 }
assert(ProjectileBehaviors.hit(hitProjectile, deadEnemy, { hitX = 30, hitY = 40 }) == "consume")
assert(table.concat(hitCalls, ",") == "hit-one:30:40,hit-two,kill:30:40,expire")
assert(hitProjectile.x == 10 and hitProjectile.y == 20)

-- Repeated consumption never executes expiration more than once.
assert(ProjectileBehaviors.hit(hitProjectile, deadEnemy) == "consume")
assert(ProjectileBehaviors.update(hitProjectile, 0.1) == nil)
local expireCount = 0
for i = 1, #hitCalls do
	if hitCalls[i] == "expire" then expireCount = expireCount + 1 end
end
assert(expireCount == 1)

print("projectile behavior dispatch tests passed")
