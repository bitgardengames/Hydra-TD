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
Camera.motionEnabled = true
Camera.impulses = {}
Camera.motionX, Camera.motionY = 0, 0
Camera.zoomOffset, Camera.vignette = 0, 0

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
	local renderScale = Camera.wscale * (1 + (suppressShake and 0 or Camera.zoomOffset))
	local sw, sh = lg.getDimensions()
	local centerX = Camera.wx + sw / (2 * Camera.wscale)
	local centerY = Camera.wy + sh / (2 * Camera.wscale)
	local renderWX = centerX - sw / (2 * renderScale)
	local renderWY = centerY - sh / (2 * renderScale)
	lg.scale(renderScale, renderScale)

	local shakeX = suppressShake and 0 or Camera.shakeX + Camera.motionX
	local shakeY = suppressShake and 0 or Camera.shakeY + Camera.motionY

	lg.translate(-renderWX + shakeX, -renderWY + shakeY)
end

local function addImpulse(kind, opts)
	if not Camera.motionEnabled then return end
	opts.kind, opts.t = kind, 0
	opts.duration = math.max(0.01, opts.duration or 0.2)
	Camera.impulses[#Camera.impulses + 1] = opts
end

-- Render-only impulses never change the authored camera or simulation clock.
function Camera.kick(dx, dy, duration)
	addImpulse("kick", {x = dx or 0, y = dy or 0, duration = duration or 0.12})
end

function Camera.settle(strength, duration, angle)
	addImpulse("settle", {strength = strength or 1, duration = duration or 0.28, angle = angle or 0})
end

function Camera.zoomPulse(amount, duration)
	addImpulse("zoom", {amount = amount or 0.006, duration = duration or 0.35})
end

function Camera.vignettePulse(amount, duration)
	addImpulse("vignette", {amount = amount or 0.08, duration = duration or 0.45})
end

function Camera.easeHome(duration)
	if not Camera.motionEnabled then return end
	duration = duration or 0.25
	-- Do not add displacement; simply constrain every active envelope to a
	-- short, smooth tail back to its zero-valued endpoint.
	for i = 1, #Camera.impulses do
		local e = Camera.impulses[i]
		e.duration = math.min(e.duration, e.t + duration)
	end
end

function Camera.setMotionEnabled(enabled)
	Camera.motionEnabled = enabled ~= false
	if Camera.motionEnabled then return end
	Camera.impulses = {}
	Camera.shakeTime, Camera.shakeStrength = 0, 0
	Camera.shakeX, Camera.shakeY = 0, 0
	Camera.motionX, Camera.motionY = 0, 0
	Camera.zoomOffset, Camera.vignette = 0, 0
end

function Camera.shake(strength, duration)
	if strength <= 0 then return end
	Camera.shakeStrength = math.max(Camera.shakeStrength, strength)
	Camera.shakeDuration = math.max(Camera.shakeDuration, duration or 0.15)
	Camera.shakeTime = Camera.shakeDuration
end

function Camera.update(dt)
	Camera.motionX, Camera.motionY, Camera.zoomOffset, Camera.vignette = 0, 0, 0, 0
	if not Camera.motionEnabled then return end
	if Camera.shakeTime > 0 then
		Camera.shakeTime = math.max(0, Camera.shakeTime - dt)
		local fade = Camera.shakeDuration > 0 and Camera.shakeTime / Camera.shakeDuration or 0
		local amount = Camera.shakeStrength * fade
		Camera.shakeX = (love.math.random() * 2 - 1) * amount
		Camera.shakeY = (love.math.random() * 2 - 1) * amount
		if Camera.shakeTime == 0 then Camera.shakeStrength = 0 end
	else Camera.shakeX, Camera.shakeY = 0, 0 end
	for i = #Camera.impulses, 1, -1 do
		local e = Camera.impulses[i]
		e.t = e.t + dt
		local u = math.min(1, e.t / e.duration)
		local fade = (1 - u) * (1 - u)
		if e.kind == "kick" then
			Camera.motionX, Camera.motionY = Camera.motionX + e.x * fade, Camera.motionY + e.y * fade
		elseif e.kind == "settle" then
			local wave = math.sin(u * math.pi * 4) * fade * e.strength
			Camera.motionX = Camera.motionX + math.cos(e.angle) * wave
			Camera.motionY = Camera.motionY + math.sin(e.angle) * wave
		elseif e.kind == "zoom" then Camera.zoomOffset = Camera.zoomOffset + math.sin(u * math.pi) * e.amount
		elseif e.kind == "vignette" then Camera.vignette = Camera.vignette + math.sin(u * math.pi) * e.amount end
		if u >= 1 then table.remove(Camera.impulses, i) end
	end
	local displacement = math.sqrt(Camera.motionX ^ 2 + Camera.motionY ^ 2)
	if displacement > 14 then
		Camera.motionX, Camera.motionY = Camera.motionX * 14 / displacement, Camera.motionY * 14 / displacement
	end
	Camera.zoomOffset = math.max(-0.012, math.min(0.012, Camera.zoomOffset))
	Camera.vignette = math.max(0, math.min(0.14, Camera.vignette))
end

function Camera.finish()
	lg.pop()
	lg.setCanvas()
end

function Camera.present()
	lg.setColor(1, 1, 1)
	lg.draw(Camera.canvas, 0, 0)
	if Camera.vignette > 0 then
		local sw, sh = lg.getDimensions()
		local edge = math.min(sw, sh) * 0.12
		for i = 1, 6 do
			local inset = edge * (i - 1) / 6
			lg.setColor(0.04, 0.02, 0.08, Camera.vignette * (1 - i / 7) * 0.32)
			lg.setLineWidth(edge / 6 + 1)
			lg.rectangle("line", inset, inset, sw - inset * 2, sh - inset * 2)
		end
		lg.setLineWidth(1)
		lg.setColor(1, 1, 1)
	end
end

function Camera.screenToWorld(x, y)
	return (x / Camera.wscale) + Camera.wx, (y / Camera.wscale) + Camera.wy
end

function Camera.worldToScreen(wx, wy)
	return (wx - Camera.wx) * Camera.wscale, (wy - Camera.wy) * Camera.wscale
end

return Camera
