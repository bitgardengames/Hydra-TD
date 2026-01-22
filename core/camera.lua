local Constants = require("core.constants")

local Camera = {}

Camera.canvas = nil
Camera.ox = 0
Camera.oy = 0

Camera.wx = 0
Camera.wy = 0
Camera.wscale = 1.0

-- Authoring baseline
local REF_W = 1920
local REF_H = 1080

local AUTHORED_ZOOM = 1.25

-- Safety rails
local MIN_ZOOM = 0.72
local MAX_ZOOM = 1.30

local lg = love.graphics
local min = math.min
local max = math.max

local function computeAdaptiveZoom()
    local sw, sh = lg.getDimensions()

    local scaleX = sw / REF_W
    local scaleY = sh / REF_H

    -- Preserve framing by using the limiting axis
    local resolutionFactor = min(scaleX, scaleY)

    -- Optional softening (feels nicer than linear)
    resolutionFactor = resolutionFactor ^ 0.85

    local z = AUTHORED_ZOOM * resolutionFactor

    return max(MIN_ZOOM, min(MAX_ZOOM, z))
end

function Camera.load()
    Camera.resize()
	Camera.setLensZoom(computeAdaptiveZoom())
end

function Camera.setLensZoom(z)
    Camera.wscale = z

    local sw, sh = lg.getDimensions()

    -- Keep screen center fixed while zooming
    Camera.wx = (sw * (z - 1)) / (2 * z)
    Camera.wy = (sh * (z - 1)) / (2 * z)
end

function Camera.resize()
    local winW, winH = lg.getDimensions()

    Camera.canvas = lg.newCanvas(winW, winH, { msaa = 8 })
    --Camera.canvas:setFilter("nearest", "nearest")

    Camera.ox = 0
    Camera.oy = 0

	Camera.setLensZoom(computeAdaptiveZoom())
end

function Camera.begin()
    lg.setCanvas(Camera.canvas)
    lg.clear()

    lg.push()
    lg.scale(Camera.wscale, Camera.wscale)
    lg.translate(-Camera.wx, -Camera.wy)
end

function Camera.finish()
    lg.pop()
    lg.setCanvas()
end

function Camera.present()
    lg.setColor(1, 1, 1)
    lg.draw(Camera.canvas, 0, 0)
end

function Camera.screenToWorld(x, y)
    return
        (x / Camera.wscale) + Camera.wx,
        (y / Camera.wscale) + Camera.wy
end

return Camera