local Save = {}

local SAVE_FILE = "save.lua"

Save.data = nil

function Save.load()
    if love.filesystem.getInfo(SAVE_FILE) then
        local chunk = love.filesystem.load(SAVE_FILE)
        local ok, data = pcall(chunk)

        if ok and type(data) == "table" then
            Save.data = data
            Save.data.furthestIndex = Save.data.furthestIndex or 1
            Save.data.unlockedMaps = Save.data.unlockedMaps or {}

            return
        end
    end

    -- Fresh save
    Save.data = {
        version = 1,
        furthestIndex = 1,
        unlockedMaps = {},
    }
end

function Save.flush()
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