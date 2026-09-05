-- Dependency-free Phasewalker mechanic and authored-content fixtures.
package.path = "./?.lua;./?/init.lua;" .. package.path

local Phase = require("world.enemy_phase")
local EnemyDefs = require("world.enemy_defs")
local CampaignWaveDefs = require("systems.campaign_wave_defs")
local Maps = require("world.map_defs")

local def = assert(EnemyDefs.boss_phasewalker, "Phasewalker definition is missing")
assert(def.boss and def.phase, "Phasewalker must be a boss with phase configuration")
assert(def.phase.initialDelay > 0 and def.phase.period > def.phase.duration
	and def.phase.duration > 0 and def.phase.speedMultiplier > 0,
	"Phasewalker timing and speed configuration is invalid")

local enemy = {id = 1, x = 20, y = 0, hp = 10, dist = 20}
Phase.initialize(enemy, def.phase)
Phase.update(enemy, def.phase.initialDelay)
assert(enemy.phaseActive, "initial delay did not begin the phase")
assert(not Phase.canDirectHit(enemy), "direct projectile filtering accepted a phased enemy")

-- Movement remains ordinary path-distance progression while phased, with the
-- authored multiplier applied rather than removing the enemy from simulation.
local before = enemy.dist
enemy.dist = enemy.dist + 10 * Phase.movementMultiplier(enemy)
assert(enemy.dist > before and enemy.dist == before + 10 * def.phase.speedMultiplier,
	"phased enemy stopped moving or lost its movement multiplier")

package.loaded["core.state"] = {frameId = 1}
local candidates = {enemy, {id = 2, x = 10, y = 0, hp = 10, dist = 10}}
package.loaded["world.spatial_grid"] = {
	newQueryContext = function() return {} end,
	pointToCell = function() return 0, 0 end,
	localQueryFootprintKey = function() return 1 end,
	querySquareCandidatesLocal = function() return candidates, #candidates end,
}
package.loaded["world.targeting"] = nil
local Targeting = require("world.targeting")
local tower = {x = 0, y = 0, range = 100, range2 = 10000, target = enemy}
assert(not Targeting.isSemanticallyValidTarget(tower, tower.target),
	"tower retained a boss after it phased")
tower.target = Targeting.findTarget(tower)
assert(tower.target == candidates[2], "tower did not reacquire a legal target")

Phase.update(enemy, def.phase.duration)
assert(not enemy.phaseActive, "phase did not expire after its configured duration")
assert(Phase.canDirectHit(enemy), "direct projectile filtering rejected a surfaced enemy")
assert(Targeting.isSemanticallyValidTarget(tower, enemy), "surfaced boss did not become targetable")

local authored = false
for _, map in ipairs(Maps) do
	for _, waveIndex in ipairs({10, 20}) do
		local wave = CampaignWaveDefs.get(map, waveIndex)
		assert(EnemyDefs[wave.bossArchetype], "authored wave references an unknown boss")
		if wave.bossArchetype == "boss_phasewalker" then authored = true end
	end
end
assert(authored, "no authored campaign encounter uses Phasewalker")

print("phasewalker fixtures passed")
