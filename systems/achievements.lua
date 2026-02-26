local State = require("core.state")
local Steam = require("core.steam")
local Save = require("core.save")

--[[
	List of achievements

	BOSS_KILL_1, BOSS_KILL_25
	ENEMY_KILL_500, ENEMY_KILL_1500, ENEMY_KILL_3000
	TOWER_LANCER_250, TOWER_SLOW_250, TOWER_CANNON_250, TOWER_SHOCK_250, TOWER_POISON_250
--]]

local Achievements = {}

local watchers = {}

local function unlock(id)
	local meta = Save.data.meta

	if meta.unlockedAchievements[id] then
		return
	end

	meta.unlockedAchievements[id] = true

	if Steam.loaded then
		Steam.unlockAchievement(id)
	end

	Save.flush()
end

-- Enemy kills
watchers.ENEMIES_KILLED = function(value)
	if value >= 3000 then unlock("ENEMY_KILL_3000") end
	if value >= 1500 then unlock("ENEMY_KILL_1500") end
	if value >= 500 then unlock("ENEMY_KILL_500") end
end

-- Boss kills
watchers.BOSSES_KILLED = function(value)
	if value >= 25 then unlock("BOSS_KILL_25") end
	if value >= 1 then unlock("BOSS_KILL_1") end
end

-- Tower kills
watchers.TOWER_LANCER_KILLS = function(value)
	if value >= 250 then unlock("TOWER_LANCER_250") end
end

watchers.TOWER_SLOW_KILLS = function(value)
	if value >= 250 then unlock("TOWER_SLOW_250") end
end

watchers.TOWER_CANNON_KILLS = function(value)
	if value >= 250 then unlock("TOWER_CANNON_250") end
end

watchers.TOWER_SHOCK_KILLS = function(value)
	if value >= 250 then unlock("TOWER_SHOCK_250") end
end

watchers.TOWER_POISON_KILLS = function(value)
	if value >= 250 then unlock("TOWER_POISON_250") end
end

function Achievements.increment(stat, amount)
	if State.ignoreStats then
		return
	end

	amount = amount or 1

	local meta = Save.data.meta
	meta[stat] = (meta[stat] or 0) + amount

	local fn = watchers[stat]

	if fn then
		fn(meta[stat])
	end
end

function Achievements.onGameOver()
	Save.flush()
end

return Achievements