-- Dependency-free fixtures for the registered effect-family lifecycle.
package.path = "./?.lua;./?/init.lua;" .. package.path

package.loaded["systems.sound"] = {play = function() end}
package.loaded["core.save"] = {data = {settings = {highDensityParticles = true}}}
package.loaded["core.camera"] = {shake = function() end}

love = {
	graphics = {},
	math = {random = function(low, high)
		if low and high then return low end
		return 0.25
	end},
}

local Effects = require("world.effects")
local Clock = require("core.simulation_clock")

-- Expiration and pool reuse use the same descriptor release path.
Effects.presentationEvent("wave_cleared", {life = 0.01})
local expired = Effects.presentation[1]
Effects.update(0.02)
assert(#Effects.presentation == 0, "expired presentation should be removed")
Effects.presentationEvent("boss_spawn", {life = 1})
assert(Effects.presentation[1] == expired, "expiration should return objects to their family pool")
Effects.clear()

-- Zap release must also return every owned segment to its specialized pool.
Effects.spawnZapEffect(1, 2, {{to = {x = 3, y = 4}}})
local oldZap = Effects.zaps[1]
local oldSegment = oldZap.segs[1]
Effects.update(1)
Effects.spawnZapEffect(5, 6, nil)
assert(Effects.zaps[1] == oldZap, "zap object should be pooled")
assert(Effects.zaps[1].segs[1] == oldSegment, "zap segments should be cleaned and pooled")
Effects.clear()

-- Fixed and nonstandard delta drag share the specialized poison handler.
Effects.spawnPoisonSplash(0, 0)
local poison = Effects.poison[1]
local vx = poison.vx
Effects.update(Clock.step)
assert(math.abs(poison.vx - vx * poison.dragMultiplier) < 1e-9, "fixed-step drag multiplier")
local before = poison.vx
local oddDelta = Clock.step * 1.5
Effects.update(oddDelta)
assert(math.abs(poison.vx - before * poison.drag ^ (oddDelta * 60)) < 1e-9,
	"nonstandard delta drag multiplier")
Effects.clear()

-- Populate every public family, including the two families omitted by the old
-- hand-written clear routine, then verify descriptor-driven clearing.
Effects.presentationEvent("boss_spawn", {})
Effects.spawnTowerTransformation(0, 0, {})
Effects.spawnCannonImpact(0, 0, 10)
Effects.spawnBossDeathExplosion(0, 0, 10)
Effects.spawnZapEffect(0, 0, nil)
Effects.spawnZapLine(0, 0, 1, 1)
Effects.spawnFrostBurst(0, 0)
Effects.spawnPoisonSplash(0, 0)
Effects.spawnLancerHit(0, 0)
Effects.spawnPlasmaHit(0, 0, 0, 0)
Effects.spawnPlacePuff(0, 0)
Effects.spawnEnemyDeath(0, 0, 2)
Effects.clear()

local familyNames = {
	"presentation", "towerTransformations", "splashes", "explosions", "zaps", "zapLines",
	"frost", "poison", "lancer", "plasmaParticles", "placePuffs", "death",
}
for i = 1, #familyNames do
	local name = familyNames[i]
	assert(#Effects[name] == 0, name .. " should be cleared")
end

print("effects family fixtures passed")
