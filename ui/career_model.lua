local Model = {}

local DIFFICULTIES = {"easy", "normal", "hard"}
local MODES = {"campaign", "replay"}

local function number(value)
	return math.max(0, tonumber(value) or 0)
end

local function tableCount(values)
	local count = 0
	for _, value in pairs(values or {}) do
		if value then
			count = count + 1
		end
	end
	return count
end

function Model.formatNumber(value)
	local text = tostring(math.floor(number(value) + 0.5))
	while true do
		local replaced, count = text:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		text = replaced
		if count == 0 then
			return text
		end
	end
end

function Model.formatDuration(seconds)
	seconds = math.floor(number(seconds) + 0.5)
	local minutes = math.floor(seconds / 60)
	local remaining = seconds % 60
	return string.format("%d:%02d", minutes, remaining)
end

function Model.career(saveData, maps, achievementDefs)
	local meta = saveData and saveData.meta or {}
	local mapStats = saveData and saveData.mapStats or {}
	local mapsCleared, medals = 0, 0
	local medalRanks = {easy = 1, normal = 2, hard = 3}

	for _, map in ipairs(maps or {}) do
		local stats = mapStats[map.id]
		if stats and medalRanks[stats.completedDifficulty] then
			mapsCleared = mapsCleared + 1
			medals = medals + medalRanks[stats.completedDifficulty]
		end
	end

	local towerPlacements, towerDamage = 0, 0
	for _, history in pairs(meta.towerHistory or {}) do
		towerPlacements = towerPlacements + number(history.placements)
		towerDamage = towerDamage + number(history.damage)
	end

	return {
		mapsCleared = mapsCleared,
		totalMaps = #(maps or {}),
		medals = medals,
		totalMedals = #(maps or {}) * 3,
		enemiesKilled = number(meta.ENEMIES_KILLED),
		bossesKilled = number(meta.BOSSES_KILLED),
		towerPlacements = towerPlacements,
		towerUpgrades = number(meta.TOWER_UPGRADES),
		towerDamage = towerDamage,
		achievements = tableCount(meta.unlockedAchievements),
		totalAchievements = #(achievementDefs or {}),
	}
end

local function bestRecord(stats)
	local best = {}
	for _, mode in ipairs(MODES) do
		local modeRecords = stats and stats.records and stats.records[mode]
		for _, difficulty in ipairs(DIFFICULTIES) do
			local record = modeRecords and modeRecords[difficulty]
			if record then
				if record.bestScore and (not best.bestScore or record.bestScore > best.bestScore) then
					best.bestScore = record.bestScore
				end
				if record.fastestClear and (not best.fastestClear or record.fastestClear < best.fastestClear) then
					best.fastestClear = record.fastestClear
				end
				if record.fewestLeaks and (best.fewestLeaks == nil or record.fewestLeaks < best.fewestLeaks) then
					best.fewestLeaks = record.fewestLeaks
				end
			end
		end
	end
	return best
end

function Model.records(saveData, maps)
	local rows = {}
	local mapStats = saveData and saveData.mapStats or {}
	for index, map in ipairs(maps or {}) do
		local stats = mapStats[map.id] or {}
		local record = bestRecord(stats)
		rows[index] = {
			id = map.id,
			nameKey = map.nameKey,
			completedDifficulty = stats.completedDifficulty,
			bestScore = record.bestScore,
			fastestClear = record.fastestClear,
			fewestLeaks = record.fewestLeaks,
		}
	end
	return rows
end

function Model.enemies(saveData, enemyDefs, order)
	local meta = saveData and saveData.meta or {}
	local encountered = meta.encounteredEnemies or {}
	local history = meta.enemyHistory or {}
	local rows = {}
	for _, kind in ipairs(order or {}) do
		local def = enemyDefs[kind]
		if def then
			local stats = history[kind] or {}
			rows[#rows + 1] = {
				kind = kind,
				def = def,
				discovered = encountered[kind] == true or number(stats.kills) > 0 or number(stats.leaks) > 0,
				kills = number(stats.kills),
				leaks = number(stats.leaks),
				fastestKill = tonumber(stats.fastestKill),
			}
		end
	end
	return rows
end

return Model
