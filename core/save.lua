local Save = {}

local SAVE_FILE = "save.lua"
local SAVE_VERSION = 1

Save.data = nil

local format = string.format

function Save.load()
    if love.filesystem.getInfo(SAVE_FILE) then
        local chunk = love.filesystem.load(SAVE_FILE)
        local ok, data = pcall(chunk)

        if ok and type(data) == "table" then
            Save.data = data

			local version = Save.data.version or 0

			--[[ If I need upgrading for adding/removing keys
			local migrated = false

			if version < 2 then
				Save.data.settings.showDamageMeter = true
				migrated = true
			end

			Save.data.version = SAVE_VERSION

			if migrated then
				Save.flush()
			end
			--]]

            Save.data.furthestIndex = Save.data.furthestIndex or 1
            Save.data.unlockedMaps = Save.data.unlockedMaps or {}

			Save.data.settings = Save.data.settings or {}

			Save.data.settings.musicVolume = Save.data.settings.musicVolume or 0.25
			Save.data.settings.sfxVolume = Save.data.settings.sfxVolume or 0.25
			Save.data.settings.difficulty = Save.data.settings.difficulty or "normal"
			Save.data.settings.fullscreen = Save.data.settings.fullscreen ~= nil and Save.data.settings.fullscreen or false

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
    }
end

function Save.flush()
	Save.data.version = SAVE_VERSION

    local serialized = "return " .. Save.serialize(Save.data)
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