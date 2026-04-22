local Save = {}

local SAVE_DIR = "saves"
local SAVE_FILE = SAVE_DIR .. "/save.lua"
local SAVE_VERSION = 1 -- Only upgrade if save structure changes

local Hotkeys = require("core.hotkeys")

Save.data = nil

local format = string.format
local rep = string.rep

-- Map ID migration (old campaign -> new campaign)
local function ensureKeybinds(settings)
	local changed = false

	if type(settings.keybinds) ~= "table" then
		settings.keybinds = Hotkeys.getDefaultBindings()
		return true
	end

	if settings.keybinds.keyboard == nil and settings.keybinds.gamepad == nil then
		settings.keybinds = {
			keyboard = settings.keybinds,
			gamepad = Hotkeys.getDefaultGamepadBindings(),
		}
		changed = true
	end

	local defaults = Hotkeys.getDefaultBindings()

	for device, deviceDefaults in pairs(defaults) do
		if type(settings.keybinds[device]) ~= "table" then
			settings.keybinds[device] = {}
			changed = true
		end

		for section, sectionDefaults in pairs(deviceDefaults) do
			if type(settings.keybinds[device][section]) ~= "table" then
				settings.keybinds[device][section] = {}
				changed = true
			end

			for id, defaultKey in pairs(sectionDefaults) do
				local key = settings.keybinds[device][section][id]
				if type(key) ~= "string" or key == "" then
					settings.keybinds[device][section][id] = defaultKey
					changed = true
				end
			end
		end
	end

	return changed
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

function Save.load()
	if love.filesystem.getInfo(SAVE_FILE) then
		local chunk = love.filesystem.load(SAVE_FILE)
		local ok, data = pcall(chunk)

		if ok and type(data) == "table" then
			Save.data = data

			local version = Save.data.version or 0

			-- Structure migrations (not used yet)
			if version < SAVE_VERSION then
				--[[ example future upgrade
				if version < 2 then
				end
				]]

				Save.data.version = SAVE_VERSION
				Save.flush()
			end

			-- Campaign progression
			Save.data.furthestIndex = Save.data.furthestIndex or 1
			Save.data.unlockedMaps = Save.data.unlockedMaps or {}
			Save.data.mapStats = Save.data.mapStats or {}

			-- Settings
			Save.data.settings = Save.data.settings or {}

			local settings = Save.data.settings

			settings.musicVolume = settings.musicVolume or 0.20
			settings.sfxVolume = settings.sfxVolume or 0.20
			settings.difficulty = settings.difficulty or "normal"

			if settings.fullscreen == nil then
				settings.fullscreen = true
			end

			if ensureKeybinds(settings) then
				Save.flush()
			end

			-- Achievement stats
			Save.data.meta = Save.data.meta or {}

			local meta = Save.data.meta

			meta.ENEMIES_KILLED = meta.ENEMIES_KILLED or 0
			meta.BOSSES_KILLED = meta.BOSSES_KILLED or 0

			meta.TOWER_LANCER_KILLS = meta.TOWER_LANCER_KILLS or 0
			meta.TOWER_SLOW_KILLS = meta.TOWER_SLOW_KILLS or 0
			meta.TOWER_CANNON_KILLS = meta.TOWER_CANNON_KILLS or 0
			meta.TOWER_SHOCK_KILLS = meta.TOWER_SHOCK_KILLS or 0
			meta.TOWER_POISON_KILLS = meta.TOWER_POISON_KILLS or 0
			meta.TOWER_PLASMA_KILLS = meta.TOWER_PLASMA_KILLS or 0

			meta.TOWER_UPGRADES = meta.TOWER_UPGRADES or 0

			meta.unlockedAchievements = meta.unlockedAchievements or {}

			-- Run map ID migration once
			if not Save.data.mapIdMigrationDone then
				local changed = migrateMapIds()

				Save.data.mapIdMigrationDone = true

				if changed then
					Save.flush()
				end
			end

			return
		end
	end

	-- Fresh save
	Save.data = {
		version = SAVE_VERSION,
		furthestIndex = 1,
		unlockedMaps = {},
		mapStats = {},

		settings = {
			musicVolume = 0.20,
			sfxVolume = 0.20,
			difficulty = "normal",
			fullscreen = true,
			keybinds = Hotkeys.getDefaultBindings(),
		},

		meta = {
			ENEMIES_KILLED = 0,
			BOSSES_KILLED = 0,

			TOWER_LANCER_KILLS = 0,
			TOWER_SLOW_KILLS = 0,
			TOWER_CANNON_KILLS = 0,
			TOWER_SHOCK_KILLS = 0,
			TOWER_POISON_KILLS = 0,
			TOWER_PLASMA_KILLS = 0,

			TOWER_UPGRADES = 0,

			unlockedAchievements = {},
		},

		mapIdMigrationDone = true, -- new saves don't need migration
	}
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

function Save.isMapUnlocked(i, mapId)
	if i <= Save.data.furthestIndex then
		return true
	end

	return Save.data.unlockedMaps[mapId] == true
end

function Save.recordMapResult(mapId, wave, difficulty, completed)
	local stats = Save.data.mapStats
	local safeWave = math.max(0, tonumber(wave) or 0)

	local s = stats[mapId]

	if not s then
		s = {bestWave = 0, completedDifficulty = nil}
		stats[mapId] = s
	end

	if safeWave > (s.bestWave or 0) then
		s.bestWave = safeWave
	end

	if completed then
		local rank = {easy = 1, normal = 2, hard = 3}
		local prev = s.completedDifficulty

		if not prev or rank[difficulty] > rank[prev] then
			s.completedDifficulty = difficulty
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

return Save
