local RunStats = {}

local function sortedKeys(t)
	local keys = {}
	for key in pairs(t or {}) do keys[#keys + 1] = key end
	table.sort(keys)
	return keys
end

local function add(t, key, amount)
	if key and amount and amount > 0 then t[key] = (t[key] or 0) + amount end
end

function RunStats.reset(options)
	options = options or {}
	RunStats.data = {
		moneyEarned = 0, moneySpent = 0,
		earlyCallBonuses = 0, flawlessBonuses = 0,
		leaksByEnemy = {}, purchases = {}, sales = {}, branches = {},
		damageByTower = {}, damageByType = {},
		killsByTower = {},
		finalTierWave = {}, towerKinds = {}, towerBranches = {}, soldTowers = {},
		modules = {}, contracts = {}, difficulty = options.difficulty or "normal",
	}
	RunStats.nextTowerId = 0
end

local function ensure() if not RunStats.data then RunStats.reset() end return RunStats.data end

function RunStats.recordIncome(amount, source)
	local d = ensure(); d.moneyEarned = d.moneyEarned + math.max(0, amount or 0)
	if source == "early_call" then d.earlyCallBonuses = d.earlyCallBonuses + amount
	elseif source == "flawless" then d.flawlessBonuses = d.flawlessBonuses + amount end
end

function RunStats.recordPurchase(tower, cost)
	local d = ensure(); RunStats.nextTowerId = RunStats.nextTowerId + 1
	tower.runStatsId = RunStats.nextTowerId; d.towerKinds[tower.runStatsId] = tower.kind
	add(d.purchases, tower.kind, 1); d.moneySpent = d.moneySpent + (cost or 0)
end

function RunStats.recordUpgrade(tower, branch, cost, wave, isFinal)
	local d = ensure(); d.moneySpent = d.moneySpent + (cost or 0)
	d.towerBranches[tower.runStatsId] = d.towerBranches[tower.runStatsId] or {}
	table.insert(d.towerBranches[tower.runStatsId], branch); add(d.branches, branch, 1)
	if isFinal then d.finalTierWave[tower.runStatsId] = wave end
end

function RunStats.recordSale(tower, value)
	local d = ensure(); add(d.sales, tower.kind, 1); d.soldTowers[tower.runStatsId] = true
	RunStats.recordIncome(value, "sale")
end

function RunStats.recordLeak(kind) add(ensure().leaksByEnemy, kind, 1) end

function RunStats.recordDamage(tower, damageType, amount)
	local d = ensure(); add(d.damageByType, damageType or "other", amount)
	if tower then add(d.damageByTower, tower.runStatsId or tower.kind, amount) end
end

function RunStats.recordKill(tower)
	if tower then add(ensure().killsByTower, tower.runStatsId or tower.kind, 1) end
end

function RunStats.commitTowerHistory()
	local Save = require("core.save")
	local d, totals = ensure(), {}
	for id, kind in pairs(d.towerKinds) do
		local total = totals[kind] or {damage = 0, kills = 0}
		total.damage = total.damage + (d.damageByTower[id] or 0)
		total.kills = total.kills + (d.killsByTower[id] or 0)
		totals[kind] = total
	end
	for kind, total in pairs(totals) do Save.recordTowerRun(kind, total.damage, total.kills) end
	Save.flush()
end

function RunStats.captureLoadout(modules, contracts)
	local d = ensure(); d.modules = {}; d.contracts = {}
	for target, list in pairs(modules or {}) do
		for _, mod in ipairs(list) do d.modules[#d.modules + 1] = (mod.id or mod.nameKey or "module") .. "@" .. target end
	end
	for key, id in pairs(contracts or {}) do
		if type(key) == "number" then d.contracts[#d.contracts + 1] = tostring(id)
		elseif id == true then d.contracts[#d.contracts + 1] = tostring(key) end
	end
	table.sort(d.modules); table.sort(d.contracts)
end

local function greatest(t)
	local best, value = nil, -1
	for _, key in ipairs(sortedKeys(t)) do if t[key] > value then best, value = key, t[key] end end
	return best, math.max(0, value)
end

function RunStats.summarize(currentMoney, score)
	local d = ensure(); local mvpId, mvpDamage = greatest(d.damageByTower)
	local mvpKind = d.towerKinds[mvpId] or mvpId or "none"
	local leakKind, leakCount = greatest(d.leaksByEnemy); local damageType, damage = greatest(d.damageByType)
	local counts, paths = {}, {}
	for id, kind in pairs(d.towerKinds) do
		if not d.soldTowers[id] then
			counts[kind] = (counts[kind] or 0) + 1
			local branches = d.towerBranches[id]
			if branches and #branches > 0 then paths[#paths + 1] = kind .. ":" .. table.concat(branches, ">") end
		end
	end
	local builds = {}; for _, kind in ipairs(sortedKeys(counts)) do builds[#builds + 1] = kind .. "x" .. counts[kind] end
	table.sort(paths)
	local observation
	if (currentMoney or 0) >= 500 and (currentMoney or 0) >= d.moneySpent * 0.35 then
		observation = "High reserve: spend more than $500 before the final waves."
	elseif (d.leaksByEnemy.shieldbearer or 0) > 0 and ((d.damageByType.cannon or 0) + (d.damageByType.shock or 0)) < math.max(1, damage) * 0.2 then
		observation = "Shieldbearer leak: add burst or chain damage."
	elseif (d.leaksByEnemy.warcaller or 0) >= 2 and not (table.concat(d.modules, ","):find("target", 1, true)) then
		observation = "Warcaller leaks: choose a priority-targeting branch."
	elseif leakCount > 0 then observation = "Largest leak was " .. leakKind .. "; counter it before the next run."
	else observation = "No leaks: preserve this coverage while spending earlier." end
	local code = table.concat({"HTD1", table.concat(builds, ","), table.concat(paths, ","), table.concat(d.modules, ","), table.concat(d.contracts, ","), d.difficulty, tostring(score or 0)}, "|")
	return {mvp = mvpKind, mvpDamage = mvpDamage, leak = leakKind or "none", leakCount = leakCount,
		damageType = damageType or "none", damage = damage, build = table.concat(builds, " "), paths = table.concat(paths, " "),
		modules = table.concat(d.modules, ", "), contracts = table.concat(d.contracts, ", "), observation = observation, code = code}
end

RunStats.reset()
return RunStats
