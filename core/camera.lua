local Constants = require("core.constants")

local Camera = {}

Camera.canvas = nil
Camera.scale = 1
Camera.ox = 0
Camera.oy = 0

Camera.wx = 0
Camera.wy = 0
Camera.wscale = 1

function Camera.load()
    Camera.canvas = love.graphics.newCanvas(Constants.SCREEN_W, Constants.SCREEN_H, {msaa = 8})

    Camera.resize()
end

function Camera.resize()
    local winW, winH = love.graphics.getDimensions()

    local sx = winW / Constants.SCREEN_W
    local sy = winH / Constants.SCREEN_H
	local s = math.min(sx, sy)

	if s >= 1 then
		Camera.scale = math.floor(s) -- integer upscale
	else
		Camera.scale = s -- fractional downscale
	end

    Camera.ox = math.floor((winW - Constants.SCREEN_W * Camera.scale) * 0.5)
    Camera.oy = math.floor((winH - Constants.SCREEN_H * Camera.scale) * 0.5)
end

function Camera.begin()
    love.graphics.setCanvas(Camera.canvas)
    love.graphics.clear()

    love.graphics.push()
    love.graphics.translate(-Camera.wx, -Camera.wy)
    love.graphics.scale(Camera.wscale, Camera.wscale)
end

function Camera.finish()
    love.graphics.pop()
    love.graphics.setCanvas()
end

function Camera.present()
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(Camera.canvas, Camera.ox, Camera.oy, 0, Camera.scale, Camera.scale)
end

function Camera.screenToWorld(x, y)
    -- Window to screen
    x = (x - Camera.ox) / Camera.scale
    y = (y - Camera.oy) / Camera.scale

    -- Screen to world
    return (x / Camera.wscale) + Camera.wx, (y / Camera.wscale) + Camera.wy
end

return Camera