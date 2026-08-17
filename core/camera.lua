local Constants = require("core.constants")
local Scale = require("core.scale")

local Camera = {}

Camera.canvas = nil
Camera.ox = 0
Camera.oy = 0

Camera.wx = 0
Camera.wy = 0
Camera.wscale = 1.0
Camera.shakeX = 0
Camera.shakeY = 0
Camera.shakeTime = 0
Camera.shakeDuration = 0
Camera.shakeStrength = 0

-- Authoring baseline
local REF_W = 1920
local REF_H = 1080

--local AUTHORED_ZOOM = 1.30
local AUTHORED_ZOOM = 1.6

-- Clamps
local MIN_ZOOM = 0.64
local MAX_ZOOM = 2.5

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


	local z = AUTHORED_ZOOM * resolutionFactor

	return max(MIN_ZOOM, min(MAX_ZOOM, z))
end

function Camera.load()
	Camera.resize()
end

function Camera.setZoom(z)
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

	local msaa = Scale.suggestMSAA(winW, winH)

	Camera.canvas = lg.newCanvas(winW, winH, {msaa = msaa})

	Camera.ox = 0
	Camera.oy = 0

	Camera.setZoom(computeAdaptiveZoom())
end

function Camera.begin(suppressShake)
	lg.setCanvas(Camera.canvas)
	lg.clear()

	lg.push()
	lg.scale(Camera.wscale, Camera.wscale)

	local shakeX = suppressShake and 0 or Camera.shakeX
	local shakeY = suppressShake and 0 or Camera.shakeY

	lg.translate(-Camera.wx + shakeX, -Camera.wy + shakeY)
end

function Camera.shake(strength, duration)
	if strength <= 0 then return end
	Camera.shakeStrength = math.max(Camera.shakeStrength, strength)
	Camera.shakeDuration = math.max(Camera.shakeDuration, duration or 0.15)
	Camera.shakeTime = Camera.shakeDuration
end

function Camera.update(dt)
	if Camera.shakeTime <= 0 then
		Camera.shakeX, Camera.shakeY = 0, 0
		return
	end
	Camera.shakeTime = math.max(0, Camera.shakeTime - dt)
	local fade = Camera.shakeDuration > 0 and Camera.shakeTime / Camera.shakeDuration or 0
	local amount = Camera.shakeStrength * fade
	Camera.shakeX = (love.math.random() * 2 - 1) * amount
	Camera.shakeY = (love.math.random() * 2 - 1) * amount
	if Camera.shakeTime == 0 then Camera.shakeStrength = 0 end
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
