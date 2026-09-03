-- Homing projectile collision regression fixtures. Run from the repository root
-- with: lua tests/projectile_homing_collision_fixtures.lua
package.path = "./?.lua;./?/init.lua;" .. package.path

love = { graphics = {} }

local movement = require("world.projectile_behaviors.registry").definitions().move_homing.on_tick
local ProjectileBehaviors = require("world.projectile_behaviors")

local function projectile(x, speed, target)
	return {
		x = x,
		y = 0,
		speed = speed,
		r = 4,
		hitRadius = 4,
		target = target,
		targetID = target.id,
		lastTX = target.x,
		lastTY = target.y,
	}
end

local enemy = { id = 7, x = 10, y = 0, radius = 6, hp = 100 }

local overlapping = projectile(5, 20, enemy)
assert(movement(overlapping, 0.01) == "consume", "an overlapping homing projectile was not consumed")
assert(overlapping.hit == enemy, "an overlapping homing projectile did not register its target")
assert(overlapping.x == 5, "an overlapping projectile was incorrectly moved back out of its target")

local approaching = projectile(-5, 20, enemy)
assert(movement(approaching, 0.5) == "consume", "a homing projectile skipped contact during its movement step")
assert(approaching.hit == enemy, "a homing projectile did not register contact")
assert(math.abs(approaching.x - 4) < 1e-9, "a homing projectile did not stop at the enemy surface")

local travelling = projectile(-20, 20, enemy)
assert(movement(travelling, 0.25) == nil and travelling.hit == nil,
	"a homing projectile hit before reaching the target")
assert(math.abs(travelling.x + 15) < 1e-9, "a homing projectile did not advance normally")

local function assertImpactFX(behaviorID, data, expectedKind)
	local p = {
		x = 3,
		y = 4,
		behaviors = {{id = behaviorID, data = data}},
		events = {},
		eventRead = 1,
		eventCount = 0,
	}
	ProjectileBehaviors.compileHooks(p)
	local target = {id = enemy.id, x = enemy.x, y = enemy.y, radius = enemy.radius, hp = enemy.hp}
	ProjectileBehaviors.hit(p, target)
	local evt = p.events[1]
	assert(evt and evt.id == "fx" and evt.kind == expectedKind,
		behaviorID .. " did not emit its impact effect")
	assert(evt.x == 3 and evt.y == 4, behaviorID .. " emitted its effect at the wrong position")
end

assertImpactFX("lancer_hit_fx", nil, "lancer_hit")
assertImpactFX("apply_slow", {factor = 0.45, dur = 1.7}, "frost_burst")
assertImpactFX("apply_poison", {dps = 4, dur = 4.5, maxStacks = 8}, "poison_splash")

print("projectile homing collision fixtures passed")
