local Save = {}

local SAVE_DIR = "saves"
local SAVE_FILE = SAVE_DIR .. "/save.lua"
local BACKUP_FILE = SAVE_DIR .. "/save.bak.lua"
local TEMP_FILE = SAVE_DIR .. "/save.tmp.lua"
local SAVE_VERSION = 6 -- Persist the active-ability slot selections
local DIRTY_DELAY = 0.35

local Hotkeys = require("core.hotkeys")

Save.data = nil
Save.dirty = false
Save.dirtyTimer = nil

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
	uiScale = 1.0,
	screenShakeIntensity = 1.0,
	msaaQuality = "auto",
	cameraMotion = true,
	highDensityParticles = true,
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
	local uiScale = tonumber(settings.uiScale)
	if not uiScale or uiScale < 0.75 or uiScale > 1.5 then settings.uiScale = 1; changed = true end
	local shake = tonumber(settings.screenShakeIntensity)
	if not shake or shake < 0 or shake > 1 then settings.screenShakeIntensity = 1; changed = true end
	if not ({auto = true, off = true, low = true, medium = true, high = true})[settings.msaaQuality] then
		settings.msaaQuality = "auto"
		changed = true
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

local function loadTable(path)
	if not love.filesystem.getInfo(path) then return nil, "file does not exist" end
	local loaded, chunk, loadError = pcall(love.filesystem.load, path)
	if not loaded or type(chunk) ~= "function" then return nil, loadError or chunk or "could not load file" end
	local ok, data = pcall(chunk)
	if not ok or type(data) ~= "table" then return nil, ok and "save did not return a table" or data end
	return data
end

local function renameFile(from, to)
	if love.filesystem.rename then return love.filesystem.rename(from, to) end
	local root = love.filesystem.getSaveDirectory()
	return os.rename(root .. "/" .. from, root .. "/" .. to)
end

local function removeFile(path)
	if not love.filesystem.getInfo(path) then return true end
	local ok, err = love.filesystem.remove(path)
	if ok then return true end
	return false, err or ("could not remove " .. path)
end

local function diagnosticName()
	local stamp = os.date("!%Y%m%d-%H%M%S")
	local path = SAVE_DIR .. "/save.corrupt-" .. stamp .. ".lua"
	local suffix = 1
	while love.filesystem.getInfo(path) do
		path = SAVE_DIR .. "/save.corrupt-" .. stamp .. "-" .. suffix .. ".lua"
		suffix = suffix + 1
	end
	return path
end

local function preserveCorruptPrimary()
	if not love.filesystem.getInfo(SAVE_FILE) then return true end
	return renameFile(SAVE_FILE, diagnosticName())
end

function Save.load()
	local data = loadTable(SAVE_FILE)
	if not data and love.filesystem.getInfo(SAVE_FILE) then
		local ok, err = preserveCorruptPrimary()
		if not ok then print("Could not preserve corrupt save: " .. tostring(err)) end
	end

	local recovered = false
	if not data then
		data = loadTable(BACKUP_FILE)
		recovered = data ~= nil
	end

	Save.data = data or createFreshData()
	local normalized = normalizeLoadedData(Save.data)
	Save.dirty = false
	Save.dirtyTimer = nil
	if recovered or normalized then Save.flush() end
end

function Save.flush()
	if not Save.data then return false, "no save data" end

	Save.data.version = SAVE_VERSION

	local serializedOk, body = pcall(Save.serialize, Save.data)
	if not serializedOk then return false, "could not serialize save: " .. tostring(body) end
	local serialized = "return " .. body

	if not love.filesystem.getInfo(SAVE_DIR) then
		local ok, err = love.filesystem.createDirectory(SAVE_DIR)
		if not ok then return false, err or "could not create save directory" end
	end

	local wrote, writeError = love.filesystem.write(TEMP_FILE, serialized)
	if not wrote then return false, writeError or "could not write temporary save" end
	local validated, validationError = loadTable(TEMP_FILE)
	if not validated then
		return false, "temporary save validation failed: " .. tostring(validationError)
	end

	-- Only a valid primary may become the last known-good backup.
	if loadTable(SAVE_FILE) then
		local removed, removeError = removeFile(BACKUP_FILE)
		if not removed then return false, removeError end
		local backedUp, backupError = renameFile(SAVE_FILE, BACKUP_FILE)
		if not backedUp then return false, backupError or "could not replace backup" end
	elseif love.filesystem.getInfo(SAVE_FILE) then
		local preserved, preserveError = preserveCorruptPrimary()
		if not preserved then return false, preserveError or "could not preserve corrupt save" end
	end

	local promoted, promoteError = renameFile(TEMP_FILE, SAVE_FILE)
	if not promoted then
		-- Best-effort restoration keeps a failed promotion from removing the primary.
		if not love.filesystem.getInfo(SAVE_FILE) and love.filesystem.getInfo(BACKUP_FILE) then
			local restored, restoreError = renameFile(BACKUP_FILE, SAVE_FILE)
			if not restored then
				return false, (promoteError or "could not promote temporary save")
					.. "; backup restoration failed: " .. tostring(restoreError)
			end
		end
		return false, promoteError or "could not promote temporary save"
	end

	Save.dirty = false
	Save.dirtyTimer = nil
	return true
end

function Save.markDirty()
	if not Save.data then return false end
	Save.dirty = true
	Save.dirtyTimer = DIRTY_DELAY
	return true
end

function Save.update(dt)
	if not Save.dirty then return end
	Save.dirtyTimer = (Save.dirtyTimer or DIRTY_DELAY) - math.max(0, tonumber(dt) or 0)
	if Save.dirtyTimer <= 0 then Save.flush() end
end

function Save.setEquippedAbilities(abilityIds)
	if not Save.data or type(abilityIds) ~= "table" then return false end

	local selections = {}
	for slotIndex, abilityId in ipairs(abilityIds) do
		if type(abilityId) == "string" then selections[slotIndex] = abilityId end
	end
	Save.data.equippedAbilities = selections
	Save.markDirty()
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
		Save.markDirty()
	end
end

function Save.markAffixEncountered(id)
	if not Save.data or type(id) ~= "string" then return end
	local meta = Save.data.meta
	meta.encounteredAffixes = meta.encounteredAffixes or {}
	if not meta.encounteredAffixes[id] then
		meta.encounteredAffixes[id] = true
		Save.markDirty()
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
	Save.markDirty()
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
	Save.markDirty()
end

function Save.recordTowerUpgrade(kind, pathId)
	local history = towerHistory(kind); if not history then return end
	history.upgrades = (history.upgrades or 0) + 1
	if pathId then history.discoveredPaths[pathId] = true end
	Save.markDirty()
end

function Save.recordTowerRun(kind, damage, kills)
	local history = towerHistory(kind); if not history then return end
	damage, kills = math.max(0, damage or 0), math.max(0, kills or 0)
	history.damage = (history.damage or 0) + damage
	history.kills = (history.kills or 0) + kills
	history.bestRunDamage = math.max(history.bestRunDamage or 0, damage)
	Save.markDirty()
end

function Save.discoverModule(moduleId)
	if not Save.data or not moduleId then return end
	Save.data.meta.discoveredModules = Save.data.meta.discoveredModules or {}
	Save.data.meta.discoveredModules[moduleId] = true
	Save.markDirty()
end

return Save
