local Enemies = require("world.enemies")
local Towers = require("world.towers")
local Projectiles = require("world.projectiles")
local Floaters = require("ui.floaters")
local Waves = require("systems.waves")
local State = require("core.state")

local Sim = {}

function Sim.update(dt)
	-- Skip simulation when paused / game over if desired
	if State.paused or State.gameOver then
		return
	end

	Waves.updatePrep(dt)
	Waves.updateSpawner(dt)
	Enemies.updateEnemies(dt)
	Towers.updateTowers(dt)
	Projectiles.updateProjectiles(dt)
	Floaters.updateFloaters(dt)
end

return Sim