local Scale = {}

local lg = love.graphics
local min = math.min

-- Authored reference resolution
local REF_W = 1920
local REF_H = 1080

Scale.sw = REF_W
Scale.sh = REF_H
Scale.factor = 1.0

function Scale.update()
    Scale.sw, Scale.sh = lg.getDimensions()

    local sx = Scale.sw / REF_W
    local sy = Scale.sh / REF_H

    -- Limiting axis preserves framing/layout
    Scale.factor = min(sx, sy)
end

-- Raw, unclamped resolution factor
function Scale.getScale()
    return Scale.factor
end

-- Convenience
function Scale.getDimensions()
    return Scale.sw, Scale.sh
end

function Scale.suggestMSAA(w, h)
    if w >= 1920 and h >= 1080 then
        return 8
    elseif w >= 1280 and h >= 720 then
        return 4
    else
        return 2
    end
end

return Scale