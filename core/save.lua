local Save = {}

local SAVE_DIR = "saves"
local SAVE_FILE = SAVE_DIR .. "/save.lua"
local SAVE_VERSION = 6 -- Persist the active-ability slot selections

local Hotkeys = require("core.hotkeys")

Save.data = nil

local format = string.format
local rep = string.rep

local DEFAULT_SETTINGS = {
	musicVolume = 0.20,
	sfxVolume = 0.20,
	difficulty = "normal",
	screenShake = true,
	showDamageNumbers = true,
	reducedFlash = false,
	fullscreen = true,
}

local META_COUNTERS = {
	"ENEMIES_KILLED",
	"BOSSES_KILLED",
	"TOWER_LANCER_KILLS",
	"TOWER_SLOW_KILLS",
	"TOWER_CANNON_KILLS",
	"TOWER_SHOCK_KILLS",
	"TOWER_POISON_KILLS",
	"TOWER_PLASMA_KILLS",
	"TOWER_UPGRADES",
}

local META_TABLES = {
	"unlockedAchievements",
	"clearedMaps",
	"encounteredEnemies",
	"encounteredAffixes",
	"enemyHistory",
	"towerHistory",
	"discoveredModules",
}

local function defaultValue(tbl, key, value)
	if tbl[key] ~= nil then return false end
	tbl[key] = value
	return true
end

local function defaultTable(tbl, key)
	if type(tbl[key]) == "table" then return false end
	tbl[key] = {}
	return true
end

local function ensureKeybinds(settings)
	local changed = false

	if type(settings.keybinds) ~= "table" then
		settings.keybinds = Hotkeys.getDefaultBindings()
		return true
	end


	local defaults = Hotkeys.getDefaultBindings()
	for section, sectionDefaults in pairs(defaults) do
		if type(settings.keybinds[section]) ~= "table" then
			settings.keybinds[section] = {}
			changed = true
		end
		for id, defaultKey in pairs(sectionDefaults) do
			local key = settings.keybinds[section][id]
			if type(key) ~= "string" or key == "" then
				settings.keybinds[section][id] = defaultKey
				changed = true
			end
		end
	end

	return changed
end

local function normalizeMapStats(mapStats)
	local changed = false
	for _, stats in pairs(mapStats) do
		if type(stats) == "table" then
			changed = defaultValue(stats, "bestEndlessWave", 0) or changed
			if type(stats.medalEarnedAt) ~= "table" then
				-- Older medals intentionally remain undated.
				stats.medalEarnedAt = {}
				changed = true
			end
		end
	end
	return changed
end

local function normalizeSettings(data)
	local changed = defaultTable(data, "settings")
	local settings = data.settings
	for key, value in pairs(DEFAULT_SETTINGS) do
		changed = defaultValue(settings, key, value) or changed
	end
	return ensureKeybinds(settings) or changed
end

local function normalizeMeta(data)
	local changed = defaultTable(data, "meta")
	local meta = data.meta
	for _, key in ipairs(META_COUNTERS) do
		changed = defaultValue(meta, key, 0) or changed
	end
	for _, key in ipairs(META_TABLES) do
		changed = defaultTable(meta, key) or changed
	end
	return changed
end

local function migrateVersion(data)
	if (data.version or 0) >= SAVE_VERSION then return false end
	if type(data.mapStats) == "table" then
		for _, stats in pairs(data.mapStats) do
			if type(stats) == "table" and (tonumber(stats.bestWave) or 0) > 20 then
				stats.bestEndlessWave = math.max(stats.bestEndlessWave or 0, stats.bestWave)
				stats.bestWave = stats.completedDifficulty and 20 or 0
			end
		end
	end
	data.version = SAVE_VERSION
	return true
end

local function migrateMapIds()
	local oldToNew = {
		alpha = "riverbend",
		spiral = "switchback",
		zigzag = "highpass",
		turntable = "roundabout",
		gauntlet = "gauntlet",
		hairpins = "snaketrail",
		centerpull = "backtrack",
		snakepit = "lowvalley",
		doublebend = "circuit",
		offsetloop = "outerloop",
		sidewinder = "terrace",
		ridge = "highridge",
	}

	local unlocked = Save.data.unlockedMaps
	local stats = Save.data.mapStats

	local changed = false

	-- unlocked maps
	for oldId, newId in pairs(oldToNew) do
		if unlocked[oldId] ~= nil then
			unlocked[newId] = unlocked[oldId]
			unlocked[oldId] = nil
			changed = true
		end
	end

	-- map stats
	for oldId, newId in pairs(oldToNew) do
		if stats[oldId] ~= nil then
			stats[newId] = stats[oldId]
			stats[oldId] = nil
			changed = true
		end
	end

	return changed
end

local function normalizeLoadedData(data)
	local changed = migrateVersion(data)
	changed = defaultValue(data, "furthestIndex", 1) or changed
	changed = defaultTable(data, "unlockedMaps") or changed
	changed = defaultTable(data, "mapStats") or changed
	if type(data.equippedAbilities) ~= "table" then
		data.equippedAbilities = {"meteor", "frost_nova"}
		changed = true
	end
	changed = normalizeMapStats(data.mapStats) or changed
	changed = normalizeSettings(data) or changed
	changed = normalizeMeta(data) or changed

	if not data.mapIdMigrationDone then
		changed = migrateMapIds() or changed
		data.mapIdMigrationDone = true
		changed = true
	end
	return changed
end

local function createFreshData()
	local data = {
		version = SAVE_VERSION,
		equippedAbilities = {"meteor", "frost_nova"},
		mapIdMigrationDone = true,
	}
	normalizeLoadedData(data)
	return data
end

function Save.load()
	if love.filesystem.getInfo(SAVE_FILE) then
		local chunk = love.filesystem.load(SAVE_FILE)
		local ok, data = pcall(chunk)

		if ok and type(data) == "table" then
			Save.data = data
			if normalizeLoadedData(data) then Save.flush() end
			return
		end
	end

	Save.data = createFreshData()
end

function Save.flush()
	if not Save.data then
		return
	end

	Save.data.version = SAVE_VERSION

	local serialized = "return " .. Save.serialize(Save.data)

	if not love.filesystem.getInfo(SAVE_DIR) then
		love.filesystem.createDirectory(SAVE_DIR)
	end

	love.filesystem.write(SAVE_FILE, serialized)
end

function Save.setEquippedAbilities(abilityIds)
	if not Save.data or type(abilityIds) ~= "table" then return false end

	local selections = {}
	for slotIndex, abilityId in ipairs(abilityIds) do
		if type(abilityId) == "string" then selections[slotIndex] = abilityId end
	end
	Save.data.equippedAbilities = selections
	Save.flush()
	return true
end

function Save.isMapUnlocked(i, mapId)
	if i <= Save.data.furthestIndex then
		return true
	end

	return Save.data.unlockedMaps[mapId] == true
end

function Save.recordMapResult(mapId, wave, difficulty, completed, endless)
	local stats = Save.data.mapStats
	local safeWave = math.max(0, tonumber(wave) or 0)

	local s = stats[mapId]

	if not s then
		s = {bestWave = 0, bestEndlessWave = 0, completedDifficulty = nil, medalEarnedAt = {}}
		stats[mapId] = s
	end
	s.medalEarnedAt = type(s.medalEarnedAt) == "table" and s.medalEarnedAt or {}

	if endless then
		if safeWave > (s.bestEndlessWave or 0) then s.bestEndlessWave = safeWave end
	elseif safeWave > (s.bestWave or 0) then
		s.bestWave = safeWave
	end

	if completed then
		local rank = {easy = 1, normal = 2, hard = 3}
		local prev = s.completedDifficulty
		local completedRank = rank[difficulty]
		local previousRank = rank[prev] or 0

		if completedRank and completedRank > previousRank then
			s.completedDifficulty = difficulty

			local earnedAt = os.time()
			for tier, tierRank in pairs(rank) do
				if tierRank <= completedRank and s.medalEarnedAt[tier] == nil then
					s.medalEarnedAt[tier] = earnedAt
				end
			end
		end
	end

	Save.flush()
end

-- Serialization
function Save.serialize(tbl, indent)
	indent = indent or 0
	local pad = rep(" ", indent)
	local s = "{\n"

	for k, v in pairs(tbl) do
		s = s .. pad .. "  [" .. format("%q", k) .. "] = "

		if type(v) == "table" then
			s = s .. Save.serialize(v, indent + 2)
		elseif type(v) == "string" then
			s = s .. format("%q", v)
		else
			s = s .. tostring(v)
		end

		s = s .. ",\n"
	end

	return s .. pad .. "}"
end

-- Helpers
function Save.unlockMap(mapId, mapIndex)
	local u = Save.data.unlockedMaps

	if not u[mapId] then
		u[mapId] = true
		Save.data.furthestIndex = math.max(Save.data.furthestIndex or 1, mapIndex or 1)
		Save.flush()
	end
end

function Save.markEnemyEncountered(kind)
	if not Save.data or type(kind) ~= "string" then
		return
	end

	local meta = Save.data.meta
	meta.encounteredEnemies = meta.encounteredEnemies or {}

	if not meta.encounteredEnemies[kind] then
		meta.encounteredEnemies[kind] = true
		Save.flush()
	end
end

function Save.markAffixEncountered(id)
	if not Save.data or type(id) ~= "string" then return end
	local meta = Save.data.meta
	meta.encounteredAffixes = meta.encounteredAffixes or {}
	if not meta.encounteredAffixes[id] then
		meta.encounteredAffixes[id] = true
		Save.flush()
	end
end

function Save.recordEnemyResult(kind, result, killTime)
	if not Save.data or type(kind) ~= "string" then return end
	local meta = Save.data.meta
	meta.enemyHistory = meta.enemyHistory or {}
	local history = meta.enemyHistory[kind] or {kills = 0, leaks = 0}
	meta.enemyHistory[kind] = history
	if result == "kill" then
		history.kills = (history.kills or 0) + 1
		if killTime and (not history.fastestKill or killTime < history.fastestKill) then
			history.fastestKill = killTime
		end
	elseif result == "leak" then
		history.leaks = (history.leaks or 0) + 1
	end
end

local function towerHistory(kind)
	if not Save.data or type(kind) ~= "string" then return nil end
	local meta = Save.data.meta
	meta.towerHistory = meta.towerHistory or {}
	local history = meta.towerHistory[kind]
	if type(history) ~= "table" then
		history = {placements = 0, upgrades = 0, damage = 0, kills = 0, bestRunDamage = 0, discoveredPaths = {}}
		meta.towerHistory[kind] = history
	end
	history.discoveredPaths = history.discoveredPaths or {}
	return history
end

function Save.recordTowerPlacement(kind)
	local history = towerHistory(kind); if not history then return end
	history.placements = (history.placements or 0) + 1
	Save.flush()
end

function Save.recordTowerUpgrade(kind, pathId)
	local history = towerHistory(kind); if not history then return end
	history.upgrades = (history.upgrades or 0) + 1
	if pathId then history.discoveredPaths[pathId] = true end
	Save.flush()
end

function Save.recordTowerRun(kind, damage, kills)
	local history = towerHistory(kind); if not history then return end
	damage, kills = math.max(0, damage or 0), math.max(0, kills or 0)
	history.damage = (history.damage or 0) + damage
	history.kills = (history.kills or 0) + kills
	history.bestRunDamage = math.max(history.bestRunDamage or 0, damage)
end

function Save.discoverModule(moduleId)
	if not Save.data or not moduleId then return end
	Save.data.meta.discoveredModules = Save.data.meta.discoveredModules or {}
	Save.data.meta.discoveredModules[moduleId] = true
end

return Save
