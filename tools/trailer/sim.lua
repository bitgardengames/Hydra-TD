local Enemies = require("world.enemies")
local Towers = require("world.towers")
local Projectiles = require("world.projectiles")
local Floaters = require("ui.floaters")
local Waves = require("systems.waves")
local State = require("core.state")
local Effects = require("world.effects")

local Sim = {}

function Sim.update(dt, opts)
	opts = opts or {}

	-- Skip simulation when paused / game over if desired
	if not opts.force then
		if State.paused or State.gameOver then
			return
		end
	end

	Waves.updatePrep(dt)
	Waves.updateSpawner(dt)
	Enemies.updateEnemies(dt)
	Towers.updateTowers(dt)
	Projectiles.update(dt)
	Effects.update(dt)
	Floaters.update(dt)
end

return Sim