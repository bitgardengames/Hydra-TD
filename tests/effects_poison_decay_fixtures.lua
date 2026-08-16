-- Dependency-free poison particle decay fixtures. Run from the repository root
-- with Lua/LuaJIT.
package.path = "./?.lua;./?/init.lua;" .. package.path

package.loaded["systems.sound"] = {}
package.loaded["core.save"] = {data = {settings = {highDensityParticles = true}}}
package.loaded["core.camera"] = {}

love = {
	graphics = {},
	math = {
		random = function(low, high)
			if low and high then return (low + high) * 0.5 end
		return 0.25
	end,
	},
}

local SimulationClock = require("core.simulation_clock")
local Effects = require("world.effects")

local function assertNear(actual, expected, tolerance, message)
	assert(math.abs(actual - expected) <= tolerance,
		string.format("%s: expected %.12f, got %.12f", message, expected, actual))
end

Effects.spawnPoisonSplash(0, 0)
local particle = Effects.poison[1]
local initialVx, initialVy = particle.vx, particle.vy
local dragBase = 0.94
local updates = 8

for _ = 1, updates do
	Effects.update(SimulationClock.step)
end

local fixedExpectedMultiplier = dragBase ^ (SimulationClock.step * 60 * updates)
assertNear(particle.vx, initialVx * fixedExpectedMultiplier, 1e-9,
	"fixed-step horizontal poison decay")
assertNear(particle.vy, initialVy * fixedExpectedMultiplier, 1e-9,
	"fixed-step vertical poison decay")

local nonstandardDelta = SimulationClock.step * 1.5
local beforeFallback = particle.vx
Effects.update(nonstandardDelta)
assertNear(particle.vx, beforeFallback * dragBase ^ (nonstandardDelta * 60), 1e-9,
	"nonstandard-delta poison decay fallback")

print("effects poison decay fixtures passed")
