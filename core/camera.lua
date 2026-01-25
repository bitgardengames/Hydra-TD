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

local AUTHORED_ZOOM = 1.28

-- Safety rails
local MIN_ZOOM = 0.72
local MAX_ZOOM = 1.40

local lg = love.graphics
local min = math.min
local max = math.max

function Camera.centerOn(cx, cy, z)
	Camera.wscale = z or Camera.wscale

	local sw, sh = lg.getDimensions()

	Camera.wx = cx - (sw / (2 * Camera.wscale))
	Camera.wy = cy - (sh / (2 * Camera.wscale))
end

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

    local mapW = Constants.GRID_W * Constants.TILE
    local mapH = Constants.GRID_H * Constants.TILE

    local mapCX = mapW * 0.5
    local mapCY = mapH * 0.5

    Camera.wx = mapCX - (sw / (2 * z))
    Camera.wy = mapCY - (sh / (2 * z))
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
	return (x / Camera.wscale) + Camera.wx, (y / Camera.wscale) + Camera.wy
end

function Camera.worldToScreen(wx, wy)
	return (wx - Camera.wx) * Camera.wscale, (wy - Camera.wy) * Camera.wscale
end

return Camera