local Enemies = require("world.enemies")
local Towers = require("world.towers")
local Projectiles = require("world.projectiles")
local Floaters = require("ui.floaters")
local Waves = require("systems.waves")
local State = require("core.state")
local Effects = require("world.effects")

local Sim = {}

function Sim.update(dt)
	--if State.paused or State.gameOver then
	if State.paused then
		return
	end

	Waves.updateSpawner(dt)
	Enemies.updateEnemies(dt)
	Towers.updateTowers(dt)
	Projectiles.update(dt)
	Effects.update(dt)
	Floaters.update(dt)
end

return Sim