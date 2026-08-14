local RunStats = {}

local function sortedKeys(t)
	local keys = {}
	for key in pairs(t or {}) do
		keys[#keys + 1] = key
	end
	table.sort(keys)
	return keys
end

local function addCount(counts, key, amount)
	if key and amount and amount > 0 then
		counts[key] = (counts[key] or 0) + amount
	end
end

function RunStats.reset()
	RunStats.data = {
		moneyEarned = 0, moneySpent = 0,
		earlyCallBonuses = 0, flawlessBonuses = 0,
		leaksByEnemy = {}, purchases = {}, sales = {}, branches = {},
		damageByTower = {}, damageByType = {},
		killsByTower = {},
		finalTierWave = {}, towerKinds = {}, towerBranches = {}, soldTowers = {},
		modules = {}, contracts = {},
	}
	RunStats.nextTowerId = 0
end

local function getData()
	if not RunStats.data then
		RunStats.reset()
	end
	return RunStats.data
end

function RunStats.recordIncome(amount, source)
	amount = amount or 0
	local data = getData()
	data.moneyEarned = data.moneyEarned + math.max(0, amount)
	if source == "early_call" then
		data.earlyCallBonuses = data.earlyCallBonuses + amount
	elseif source == "flawless" then
		data.flawlessBonuses = data.flawlessBonuses + amount
	end
end

function RunStats.recordPurchase(tower, cost)
	local data = getData()
	RunStats.nextTowerId = RunStats.nextTowerId + 1
	tower.runStatsId = RunStats.nextTowerId
	data.towerKinds[tower.runStatsId] = tower.kind
	addCount(data.purchases, tower.kind, 1)
	data.moneySpent = data.moneySpent + (cost or 0)
end

function RunStats.recordUpgrade(tower, branch, cost, wave, isFinal)
	local data = getData()
	data.moneySpent = data.moneySpent + (cost or 0)
	if branch then
		local branches = data.towerBranches[tower.runStatsId] or {}
		data.towerBranches[tower.runStatsId] = branches
		table.insert(branches, branch)
		addCount(data.branches, branch, 1)
	end
	if isFinal then
		data.finalTierWave[tower.runStatsId] = wave
	end
end

function RunStats.recordSale(tower, value)
	local data = getData()
	addCount(data.sales, tower.kind, 1)
	data.soldTowers[tower.runStatsId] = true
	RunStats.recordIncome(value, "sale")
end

function RunStats.recordLeak(kind)
	addCount(getData().leaksByEnemy, kind, 1)
end

function RunStats.recordDamage(tower, damageType, amount)
	local data = getData()
	addCount(data.damageByType, damageType or "other", amount)
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
end

function RunStats.captureLoadout(modules, contracts)
	local data = getData()
	data.modules = {}
	data.contracts = {}
	for target, list in pairs(modules or {}) do
		for _, mod in ipairs(list) do
			data.modules[#data.modules + 1] = (mod.id or mod.nameKey or "module") .. "@" .. target
		end
	end
	for key, id in pairs(contracts or {}) do
		if type(key) == "number" then
			data.contracts[#data.contracts + 1] = tostring(id)
		elseif id == true then
			data.contracts[#data.contracts + 1] = tostring(key)
		end
	end
	table.sort(data.modules)
	table.sort(data.contracts)
end

local function greatest(t)
	local best, value = nil, -1
	for _, key in ipairs(sortedKeys(t)) do
		if t[key] > value then
			best, value = key, t[key]
		end
	end
	return best, math.max(0, value)
end

function RunStats.summarize(currentMoney)
	local data = getData()
	local mvpId, mvpDamage = greatest(data.damageByTower)
	local mvpKind = data.towerKinds[mvpId] or mvpId or "none"
	local leakKind, leakCount = greatest(data.leaksByEnemy)
	local damageType, damage = greatest(data.damageByType)
	local counts, paths = {}, {}
	for id, kind in pairs(data.towerKinds) do
		if not data.soldTowers[id] then
			counts[kind] = (counts[kind] or 0) + 1
			local branches = data.towerBranches[id]
			if branches and #branches > 0 then
				paths[#paths + 1] = kind .. ":" .. table.concat(branches, ">")
			end
		end
	end
	local builds = {}
	for _, kind in ipairs(sortedKeys(counts)) do
		builds[#builds + 1] = kind .. "x" .. counts[kind]
	end
	table.sort(paths)

	local observation
	if (currentMoney or 0) >= 500 and (currentMoney or 0) >= data.moneySpent * 0.35 then
		observation = "High reserve: spend more than $500 before the final waves."
	elseif (data.leaksByEnemy.warcaller or 0) >= 2 and not (table.concat(data.modules, ","):find("target", 1, true)) then
		observation = "Warcaller leaks: choose a priority-targeting branch."
	elseif leakCount > 0 then
		observation = "Largest leak was " .. leakKind .. "; counter it before the next run."
	else
		observation = "No leaks: preserve this coverage while spending earlier."
	end

	return {
		mvp = mvpKind,
		mvpDamage = mvpDamage,
		leak = leakKind or "none",
		leakCount = leakCount,
		damageType = damageType or "none",
		damage = damage,
		build = table.concat(builds, " "),
		paths = table.concat(paths, " "),
		modules = table.concat(data.modules, ", "),
		contracts = table.concat(data.contracts, ", "),
		observation = observation,
	}
end

RunStats.reset()
return RunStats
