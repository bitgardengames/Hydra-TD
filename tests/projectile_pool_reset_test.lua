-- Run with: lua tests/projectile_pool_reset_test.lua
package.path = "./?.lua;./?/init.lua;" .. package.path

love = love or {}
love.graphics = love.graphics or {}

local Registry = require("world.projectile_behaviors.registry")
local definitions = Registry.definitions()

-- Model one pool slot used by a linear, ticking/forking shot.
local p = {
	angle = 0, speed = 100, life = 2, hitRadius = 4,
	sourceTower = { angle = 0, x = 0, y = 0 },
}
definitions.move_linear.on_shot(p, { dist = 80 })
definitions.tick_damage.on_shot(p, { radius = 16 })
p._forksScratch = { { from = "old", to = "target" } }
p._claimedScratch = { oldTarget = true }
p._tickStates.oldTarget = { timer = 10 }

local forks, claimed, tickStates = p._forksScratch, p._claimedScratch, p._tickStates
Registry.resetProjectile(p)

assert(p._linear == nil, "first shot's movement state leaked")
assert(p.allowRepeatHits == nil and p.visualScale == nil, "first shot's damage state leaked")
assert(p._forksScratch == forks and next(forks) == nil, "fork scratch buffer was not retained and cleared")
assert(p._claimedScratch == claimed and next(claimed) == nil, "claim scratch buffer was not retained and cleared")
assert(p._tickStates == tickStates and next(tickStates) == nil, "tick state map was not retained and cleared")

-- Reuse that exact slot for a different behavior combination, then reverse the
-- direction once more to catch state leaking in either direction.
definitions.beam.on_shot(p, { length = 90 })
assert(p._beam and p._beam.length == 90, "second shot did not initialize")
assert(p._linear == nil and next(p._tickStates) == nil and next(p._claimedScratch) == nil,
	"first behavior combination affected the second shot")

Registry.resetProjectile(p)
definitions.move_linear.on_shot(p, { dist = 25 })
assert(p._beam == nil, "second shot's beam state affected the third shot")
assert(p._linear and p._linear.maxDistance == 25, "pooled slot did not accept a new movement state")

print("projectile pool behavior reset tests passed")
