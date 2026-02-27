local Save = {}

local SAVE_DIR = "saves"
local SAVE_FILE = SAVE_DIR .. "/save.lua"
local SAVE_VERSION = 1 -- Only upgrade the version if I change the structure of saves

Save.data = nil

local format = string.format

function Save.load()
    if love.filesystem.getInfo(SAVE_FILE) then
        local chunk = love.filesystem.load(SAVE_FILE)
        local ok, data = pcall(chunk)

        if ok and type(data) == "table" then
            Save.data = data

			local version = Save.data.version or 0

			-- If I need upgrading for adding/removing keys
			if version < SAVE_VERSION then
				--[[if version < 2 then
					-- migration logic
				end]]

				Save.data.version = SAVE_VERSION
				Save.flush()
			end

			-- Campaign progression
            Save.data.furthestIndex = Save.data.furthestIndex or 1
            Save.data.unlockedMaps = Save.data.unlockedMaps or {}

			-- Settings
			Save.data.settings = Save.data.settings or {}

			local settings = Save.data.settings

			settings.musicVolume = settings.musicVolume or 0.25
			settings.sfxVolume = settings.sfxVolume or 0.25
			settings.difficulty = settings.difficulty or "normal"

			if settings.fullscreen == nil then
				settings.fullscreen = true
			end

			-- Achievement progress / stat storage
			Save.data.meta = Save.data.meta or {}

			local meta = Save.data.meta

			meta.ENEMIES_KILLED = meta.ENEMIES_KILLED or 0
			meta.BOSSES_KILLED = meta.BOSSES_KILLED or 0

			meta.TOWER_LANCER_KILLS = meta.TOWER_LANCER_KILLS or 0
			meta.TOWER_SLOW_KILLS = meta.TOWER_SLOW_KILLS or 0
			meta.TOWER_CANNON_KILLS = meta.TOWER_CANNON_KILLS or 0
			meta.TOWER_SHOCK_KILLS = meta.TOWER_SHOCK_KILLS or 0
			meta.TOWER_POISON_KILLS = meta.TOWER_POISON_KILLS or 0

			meta.unlockedAchievements = meta.unlockedAchievements or {}

            return
        end
    end

    -- Fresh save
    Save.data = {
        version = SAVE_VERSION,
        furthestIndex = 1,
        unlockedMaps = {},
		settings = {
			musicVolume = 0.25,
			sfxVolume = 0.25,
			difficulty = "normal",
			fullscreen = true,
		},

		meta = {
			ENEMIES_KILLED = 0,
			BOSSES_KILLED = 0,

			TOWER_LANCER_KILLS = 0,
			TOWER_SLOW_KILLS = 0,
			TOWER_CANNON_KILLS = 0,
			TOWER_SHOCK_KILLS = 0,
			TOWER_POISON_KILLS = 0,

			unlockedAchievements = {},
		},
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

-- Serialization
function Save.serialize(tbl, indent)
    indent = indent or 0
    local pad = string.rep(" ", indent)
    local s = "{\n"

    for k, v in pairs(tbl) do
        s = s .. pad .. "  [" .. string.format("%q", k) .. "] = "

        if type(v) == "table" then
            s = s .. Save.serialize(v, indent + 2)
        elseif type(v) == "string" then
            s = s .. string.format("%q", v)
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

function Save.isUnlocked(mapId)
    return Save.data.unlockedMaps[mapId] == true
end

return Save