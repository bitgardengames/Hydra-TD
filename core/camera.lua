local Constants = require("core.constants")

local Camera = {}

Camera.scale = 1
Camera.ox = 0
Camera.oy = 0

function Camera.resize(winW, winH)
    -- The world must fit above the UI
    local viewW = winW
    local viewH = winH - Constants.UI_H

    -- World dimensions in pixels
    local worldW = Constants.WORLD_W
    local worldH = Constants.WORLD_H

    -- Scale so the entire world fits
    local sx = viewW / worldW
    local sy = viewH / worldH
    Camera.scale = math.min(sx, sy)

    -- Center the world in the available space
    Camera.ox = (viewW - worldW * Camera.scale) * 0.5
    Camera.oy = (viewH - worldH * Camera.scale) * 0.5
end

function Camera.begin()
    love.graphics.push()
    love.graphics.translate(Camera.ox, Camera.oy)
    love.graphics.scale(Camera.scale, Camera.scale)
end

function Camera.finish()
    love.graphics.pop()
end

function Camera.screenToWorld(x, y)
    return (x - Camera.ox) / Camera.scale, (y - Camera.oy) / Camera.scale
end

return Camera