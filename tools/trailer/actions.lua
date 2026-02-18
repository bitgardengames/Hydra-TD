local Towers = require("world.towers")
local Waves = require("systems.waves")
local State = require("core.state")

local Actions = {}

function Actions.placeTower(kind, gx, gy)
	return function()
		Towers.addTower(kind, gx, gy)
	end
end

function Actions.upgradeTowerAt(gx, gy, times)
	times = times or 1

	return function()
		local t = Towers.findTowerAt(gx, gy)

		if not t then
			return
		end

		for i = 1, times do
			Towers.upgradeTower(t)
		end
	end
end

function Actions.startWave()
	return function()
		Waves.startWave()
	end
end

function Actions.jumpToWave(wave)
	return function()
		State.wave = wave - 1
		Waves.startWave()
	end
end

function Actions.setSpeed(v)
	return function()
		State.speed = v
	end
end

return Actions