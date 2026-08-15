local Enemies = require("world.enemies")
local Towers = require("world.towers")
local Projectiles = require("world.projectiles")
local Floaters = require("ui.floaters")
local Waves = require("systems.waves")
local State = require("core.state")
local Effects = require("world.effects")
local Spatial = require("world.spatial_grid")
local Abilities = require("systems.abilities")
local EnemySupport = require("world.enemy_support")

local Sim = {}

function Sim.update(dt)
	--if State.paused or State.gameOver then
	if State.paused then
		return
	end

	Spatial.beginFrame()
	Abilities.update(dt)
	-- Targeting caches use this identifier, so it advances once per simulation
	-- tick rather than once per rendered frame.
	State.frameId = (State.frameId or 0) + 1
	Waves.updateSpawner(dt)
	Enemies.updateEnemies(dt)
	-- Enemy movement queues aura membership changes. Resolve them only after all
	-- spatial positions are final, but before targeting and combat consume boosts.
	EnemySupport.flushDirtySources()
	Towers.updateTowers(dt)
	Projectiles.update(dt)
	Effects.update(dt)
	Floaters.update(dt)

	local localQueryCount, localCandidateTotal = Spatial.getLocalQueryFrameStats()
	State.spatialStats.localQueryCount = localQueryCount
	State.spatialStats.localCandidateTotal = localCandidateTotal
end

return Sim
