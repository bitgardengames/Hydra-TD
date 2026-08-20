-- Dependency-free durability progression regression fixtures.
package.loaded["systems.difficulty"] = {
	get = function()
		return {enemyHpBias = 1, bossHpBias = 1, enemySpeedBias = 1}
	end,
}

local Curve = require("systems.difficulty_curve")

local function hp(wave)
	return Curve.getEnemyHpMultiplier(wave, 1)
end

assert(hp(1) == 1, "campaign wave one should use base enemy health")
assert(math.abs(hp(10) - 3.0) < 0.000001,
	"campaign wave ten should provide a substantial midpoint durability check")

for wave = 2, 20 do
	assert(hp(wave) > hp(wave - 1),
		("enemy health must increase from wave %d to wave %d"):format(wave - 1, wave))
end

assert(math.abs(hp(20) - 4.35) < 0.000001,
	"campaign wave twenty should provide the final durability check")

assert(hp(21) == hp(20),
	"enemy health should remain capped at the campaign finale")

print("difficulty curve fixtures passed")
