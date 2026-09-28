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
		bossDamageByTower = {},
		investmentByTower = {},
		towerBranches = {},
		byTowerKind = {},
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
		kills = state.totalKills or 0,
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
	data.investmentByTower[tower.runStatsId] = tower.def and tower.def.cost or 0
	data.towersPlaced = data.towersPlaced + 1
	local total = data.byTowerKind[tower.kind] or {damage = 0, bossDamage = 0, kills = 0, placements = 0, investment = 0}
	total.placements = total.placements + 1
	total.investment = total.investment + (tower.def and tower.def.cost or 0)
	data.byTowerKind[tower.kind] = total
end

function RunStats.recordSpecialization(tower, branch, cost)
	if not tower or not tower.runStatsId or type(branch) ~= "string" then return end
	local data = getData()
	data.towerBranches[tower.runStatsId] = branch
	addCount(data.investmentByTower, tower.runStatsId, cost or 0)
	local baseAggregate = data.byTowerKind[tower.kind]
	if baseAggregate then baseAggregate.investment = baseAggregate.investment + math.max(0, cost or 0) end
	local key = tower.kind .. "/" .. branch
	local aggregate = data.byTowerKind[key] or {damage = 0, bossDamage = 0, kills = 0, placements = 0, investment = 0}
	aggregate.placements = aggregate.placements + 1
	aggregate.investment = aggregate.investment + (data.investmentByTower[tower.runStatsId] or 0)
	aggregate.damage = aggregate.damage + (data.damageByTower[tower.runStatsId] or 0)
	aggregate.bossDamage = aggregate.bossDamage + (data.bossDamageByTower[tower.runStatsId] or 0)
	aggregate.kills = aggregate.kills + (data.killsByTower[tower.runStatsId] or 0)
	data.byTowerKind[key] = aggregate
end

function RunStats.recordInvestment(tower, cost)
	if tower then
		local data = getData()
		addCount(data.investmentByTower, tower.runStatsId or tower.kind, cost or 0)
		for _, key in ipairs({tower.kind, tower.specialization and (tower.kind .. "/" .. tower.specialization)}) do
			if key then
				local total = data.byTowerKind[key]
				if total then total.investment = total.investment + math.max(0, cost or 0) end
			end
		end
	end
end

function RunStats.recordAbilityUse()
	local data = getData()
	data.abilitiesUsed = data.abilitiesUsed + 1
end

function RunStats.recordDamage(tower, amount, isBoss)
	local data = getData()
	if tower then
		addCount(data.damageByTower, tower.runStatsId or tower.kind, amount)
		if isBoss then addCount(data.bossDamageByTower, tower.runStatsId or tower.kind, amount) end
		for _, key in ipairs({tower.kind, tower.specialization and (tower.kind .. "/" .. tower.specialization)}) do
			local total = key and data.byTowerKind[key]
			if total then
				total.damage = total.damage + math.max(0, amount or 0)
				if isBoss then total.bossDamage = total.bossDamage + math.max(0, amount or 0) end
			end
		end
	end
end

function RunStats.recordKill(tower)
	if tower then
		local data = getData()
		addCount(data.killsByTower, tower.runStatsId or tower.kind, 1)
		local base = data.byTowerKind[tower.kind]
		if base then base.kills = base.kills + 1 end
		local branch = tower.specialization and data.byTowerKind[tower.kind .. "/" .. tower.specialization]
		if branch then branch.kills = branch.kills + 1 end
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
	local totals, branchTotals = {}, {}
	for id, kind in pairs(data.towerKinds) do
		local total = totals[kind] or { damage = 0, bossDamage = 0, kills = 0, placements = 0, investment = 0 }
		total.damage = total.damage + (data.damageByTower[id] or 0)
		total.bossDamage = total.bossDamage + (data.bossDamageByTower[id] or 0)
		total.kills = total.kills + (data.killsByTower[id] or 0)
		total.placements = total.placements + 1
		total.investment = total.investment + (data.investmentByTower[id] or 0)
		totals[kind] = total
		local branch = data.towerBranches[id]
		if branch then
			local key = kind .. "/" .. branch
			local bt = branchTotals[key] or {kind = kind, branch = branch, damage = 0, bossDamage = 0, kills = 0, placements = 0, investment = 0}
			bt.damage = bt.damage + (data.damageByTower[id] or 0)
			bt.bossDamage = bt.bossDamage + (data.bossDamageByTower[id] or 0)
			bt.kills = bt.kills + (data.killsByTower[id] or 0)
			bt.placements = bt.placements + 1
			bt.investment = bt.investment + (data.investmentByTower[id] or 0)
			branchTotals[key] = bt
		end
	end
	for kind, total in pairs(totals) do
		Save.recordTowerRun(kind, total.damage, total.kills, total.bossDamage, total.investment)
	end
	for _, total in pairs(branchTotals) do
		Save.recordTowerBranchRun(total.kind, total.branch, total)
	end
	Save.flush()
	return true
end

RunStats.reset()
return RunStats
