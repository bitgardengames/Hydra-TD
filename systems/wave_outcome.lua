local Difficulty = require("systems.difficulty")
local EnemyDefs = require("world.enemy_defs")

local Outcome = {}

function Outcome.getWaveCompletionBonus(wave, waveLeaks, bossKind)
	if waveLeaks ~= 0 then return 0 end
	local base = Difficulty.get().perfectWaveBonus
	local def = bossKind and EnemyDefs[bossKind]
	local mechanicWeight = (def and def.mechanicWeight) or 1
	local archetypeBonus = (def and def.boss and def.mechanicPackage) and .2 or 0
	local milestoneBonus = wave % 5 == 0 and .1 or 0
	return math.floor(base * (1 + archetypeBonus + milestoneBonus + (mechanicWeight - 1) * .75) + .5)
end

return Outcome
