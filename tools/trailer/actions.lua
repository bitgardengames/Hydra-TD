local Towers = require("world.towers")
local Waves = require("systems.waves")
local State = require("core.state")
local Enemies = require("world.enemies")
local Inspect = require("ui.bottom_bar_inspect")

local Actions = {}

local function clearSelection()
	State.selectedTower = nil
	State.selectedEnemy = nil

	Inspect.overrideAnimation(false)
end

function Actions.clearSelection()
	return function()
		clearSelection()
	end
end

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

function Actions.selectTower(gx, gy)
	return function()
		local t = Towers.findTowerAt(gx, gy)

		clearSelection()
		State.selectedTower = t
		Inspect.overrideAnimation()
	end
end

function Actions.selectEnemy(index)
	index = index or 1

	return function()
		local enemies = Enemies.enemies
		local found = nil
		local aliveIndex = 0

		for i = 1, #enemies do
			local e = enemies[i]

			if e.hp > 0 and not e.dying and not e.exitFade then
				aliveIndex = aliveIndex + 1

				if aliveIndex == index then
					found = e
					break
				end
			end
		end

		clearSelection()
		State.selectedEnemy = found
		Inspect.overrideAnimation()
	end
end

function Actions.selectEnemyByKind(kind, nth)
	nth = nth or 1

	return function()
		local enemies = Enemies.enemies
		local found = nil
		local count = 0

		for i = 1, #enemies do
			local e = enemies[i]

			if e.kind == kind and e.hp > 0 and not e.dying and not e.exitFade then
				count = count + 1

				if count == nth then
					found = e
					break
				end
			end
		end

		clearSelection()
		State.selectedEnemy = found
	end
end

function Actions.selectBoss()
	return function()
		clearSelection()
		State.selectedEnemy = State.activeBoss
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

function Actions.setMoney(v)
	return function()
		State.money = v
	end
end

function Actions.setLives(v)
	return function()
		State.lives = v
	end
end

return Actions