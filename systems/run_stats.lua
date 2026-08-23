local RunStats = {}

local function addCount(counts, key, amount)
	if key and amount and amount > 0 then
		counts[key] = (counts[key] or 0) + amount
	end
end

function RunStats.reset()
	RunStats.data = {
		damageByTower = {},
		killsByTower = {},
		towerKinds = {},
		towersPlaced = 0,
		abilitiesUsed = 0,
	}
	RunStats.nextTowerId = 0
	RunStats.elapsed = 0
	RunStats.final = nil
	RunStats.towerHistoryCommitted = false
end

function RunStats.update(dt)
	if not RunStats.final then RunStats.elapsed = RunStats.elapsed + math.max(0, tonumber(dt) or 0) end
end

function RunStats.finish(outcome, state)
	if RunStats.final then return RunStats.final end
	state = state or {}
	local data = RunStats.data or {}
	RunStats.final = {outcome = outcome, duration = RunStats.elapsed, score = state.score or 0,
		remainingLives = state.lives or 0, leaks = state.totalLeaks or 0, wave = state.wave or 0,
		kills = state.totalKills or 0, buildSeed = state.buildSeed,
		towersPlaced = data.towersPlaced or 0, abilitiesUsed = data.abilitiesUsed or 0}
	return RunStats.final
end

local function getData()
	if not RunStats.data then
		RunStats.reset()
	end
	return RunStats.data
end

function RunStats.recordPurchase(tower)
	local data = getData()
	RunStats.nextTowerId = RunStats.nextTowerId + 1
	tower.runStatsId = RunStats.nextTowerId
	data.towerKinds[tower.runStatsId] = tower.kind
	data.towersPlaced = data.towersPlaced + 1
end

function RunStats.recordAbilityUse()
	local data = getData()
	data.abilitiesUsed = data.abilitiesUsed + 1
end

function RunStats.recordDamage(tower, amount)
	local data = getData()
	if tower then
		addCount(data.damageByTower, tower.runStatsId or tower.kind, amount)
	end
end

function RunStats.recordKill(tower)
	if tower then
		addCount(getData().killsByTower, tower.runStatsId or tower.kind, 1)
	end
end

function RunStats.commitTowerHistory()
	-- Tower history represents played-out runs, not every way gameplay can end.
	-- This guard also makes terminal UI navigation and shutdown harmless.
	local eligible = RunStats.final
		and (RunStats.final.outcome == "completed" or RunStats.final.outcome == "failed")
	if RunStats.towerHistoryCommitted or not eligible then
		return false
	end
	RunStats.towerHistoryCommitted = true

	local Save = require("core.save")
	local data = getData()
	local totals = {}
	for id, kind in pairs(data.towerKinds) do
		local total = totals[kind] or { damage = 0, kills = 0 }
		total.damage = total.damage + (data.damageByTower[id] or 0)
		total.kills = total.kills + (data.killsByTower[id] or 0)
		totals[kind] = total
	end
	for kind, total in pairs(totals) do
		Save.recordTowerRun(kind, total.damage, total.kills)
	end
	Save.flush()
	return true
end

RunStats.reset()
return RunStats
