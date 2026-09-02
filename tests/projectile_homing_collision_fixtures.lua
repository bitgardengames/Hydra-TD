-- Homing projectile collision regression fixtures. Run from the repository root
-- with: lua tests/projectile_homing_collision_fixtures.lua
package.path = "./?.lua;./?/init.lua;" .. package.path

love = { graphics = {} }

local movement = require("world.projectile_behaviors.registry").definitions().move_homing.on_tick

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
assert(movement(approaching, 0.3) == "consume", "a homing projectile skipped contact during its movement step")
assert(approaching.hit == enemy, "a homing projectile did not register contact")
assert(math.abs(approaching.x) < 1e-9, "a homing projectile did not stop at first contact")

local travelling = projectile(-20, 20, enemy)
assert(movement(travelling, 0.25) == nil and travelling.hit == nil,
	"a homing projectile hit before reaching the target")
assert(math.abs(travelling.x + 15) < 1e-9, "a homing projectile did not advance normally")

print("projectile homing collision fixtures passed")
