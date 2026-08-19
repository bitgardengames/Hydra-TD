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
assert(math.abs(hp(10) - 1.62) < 0.000001,
	"campaign wave ten should provide the authored durability check")

for wave = 2, 40 do
	assert(hp(wave) > hp(wave - 1),
		("enemy health must increase from wave %d to wave %d"):format(wave - 1, wave))
end

assert(hp(11) > hp(10),
	"entering Endless must not reset health below the campaign finale")
assert(math.abs(hp(20) - Curve.localEndHp * Curve.endlessHpPerTier) < 0.000001,
	"ten Endless waves should apply exactly one full endless growth tier")

print("difficulty curve fixtures passed")
