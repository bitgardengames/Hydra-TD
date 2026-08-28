local Enemies = require("world.enemies")
local Towers = require("world.towers")
local Projectiles = require("world.projectiles")
local Floaters = require("ui.floaters")
local Waves = require("systems.waves")
local State = require("core.state")
local Effects = require("world.effects")
local Spatial = require("world.spatial_grid")
local EnemySupport = require("world.enemy_support")

local Sim = {}

function Sim.update(dt)
	--if State.paused or State.gameOver then
	if State.paused then
		return
	end

	Spatial.beginFrame()
	-- Targeting caches use this identifier, so it advances once per simulation
	-- tick rather than once per rendered frame.
	State.frameId = (State.frameId or 0) + 1
	Waves.updateSpawner(dt)
	-- Required enemy order: DOT/death, authored traits, effective speed, path and
	-- spatial update, presentation handoff, then escape removal. Movement and
	-- swap-removal queue aura work. This flush MUST stay after the complete enemy
	-- pass and before towers/projectiles consume support boosts.
	Enemies.updateEnemies(dt)
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
