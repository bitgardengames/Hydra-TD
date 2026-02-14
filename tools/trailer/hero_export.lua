local Camera = require("core.camera")
local State  = require("core.state")

local lg = love.graphics
local min = math.min
local max = math.max

local HeroExport = {}

HeroExport.formats = {
	hero = {
		width = 3840,
		height = 1240,
		subjectScale = 0.05,
		verticalBias = 0.08,
	},
	vertical = {
		width = 748,
		height = 896,
		subjectScale = 0.05,
		verticalBias = 0.15,
	},
}

-- State
HeroExport.active        = false
HeroExport.canvas        = nil
HeroExport.subject       = nil   -- actual tower or enemy instance
HeroExport.subjectType   = nil   -- "tower" | "enemy"

HeroExport.width         = 3840
HeroExport.height        = 1240
HeroExport.subjectScale  = 0.7
HeroExport.verticalBias  = 0.1

HeroExport.captureX      = 0
HeroExport.captureY      = 0
HeroExport._prevPaused   = nil

function HeroExport.init()
	HeroExport._rebuildCanvas()
end

function HeroExport.setFormat(name)
	local f = HeroExport.formats[name]
	assert(f, "Unknown HeroExport format: " .. tostring(name))

	HeroExport.width        = f.width
	HeroExport.height       = f.height
	HeroExport.subjectScale = f.subjectScale
	HeroExport.verticalBias = f.verticalBias

	HeroExport._rebuildCanvas()
end

function HeroExport._rebuildCanvas()
	HeroExport.canvas = lg.newCanvas(HeroExport.width, HeroExport.height, {msaa = 8})
end

function HeroExport.getSubjectBounds()
	local s = HeroExport.subject
	if not s then return nil end

	-- Towers (match towers.lua reality)
	if HeroExport.subjectType == "tower" then
		local r =
			(s.def and s.def.visualRadius) or
			s.visualRadius or
			32

		return {
			x = s.x,
			y = s.y,
			r = r,
		}
	end

	-- Enemies (match enemies.lua reality)
	if HeroExport.subjectType == "enemy" then
		local r = s.radius or s.r or 16

		return {
			x = s.x,
			y = s.y,
			r = r,
		}
	end

	return nil
end

-- Camera framing
function HeroExport.frameOnSubject()
	local b = HeroExport.getSubjectBounds()
	if not b then
		return HeroExport.captureX, HeroExport.captureY
	end

	local cx = b.x
	local cy = b.y - b.r * (HeroExport.verticalBias or 0.1)

	return cx, cy
end

function HeroExport.computeZoom(bounds)
	local diameter = bounds.r * 2
	local minScreen = min(HeroExport.width, HeroExport.height)

	local targetPixels = minScreen * HeroExport.subjectScale
	return targetPixels / diameter
end

function HeroExport.capture(opts)
	opts = opts or {}

	HeroExport.active      = true
	HeroExport.subject     = assert(opts.subject, "HeroExport.capture requires subject")
	HeroExport.subjectType = assert(opts.subjectType, "HeroExport.capture requires subjectType")

	-- Freeze sim
	if opts.freezeSim ~= false then
		HeroExport._prevPaused = State.paused
		State.paused = true
	end

	HeroExport.captureX, HeroExport.captureY =
		HeroExport.frameOnSubject()
end

function HeroExport.draw(renderWorldFn)
	if not HeroExport.active then
		return false
	end

	local prevCanvas = lg.getCanvas()
	local bounds = HeroExport.getSubjectBounds()
	if not bounds then
		return false
	end

	local scale = HeroExport.computeZoom(bounds)

	lg.setCanvas(HeroExport.canvas)
	lg.clear(0, 0, 0, 0)

	lg.push()

	-- 1. Scale world
	lg.scale(scale, scale)

	-- 2. Move subject to origin
	lg.translate(
		-HeroExport.captureX,
		-HeroExport.captureY
	)

	-- 3. Move origin to center of output canvas
	lg.translate(
		HeroExport.width  * 0.5 / scale,
		HeroExport.height * 0.5 / scale
	)

	renderWorldFn()
	lg.pop()

	lg.setCanvas(prevCanvas)

	--local img = HeroExport.canvas:newImageData()
	--img:encode("png", fileName)

	-- Restore sim
	if HeroExport._prevPaused ~= nil then
		State.paused = HeroExport._prevPaused
		HeroExport._prevPaused = nil
	end

	HeroExport.active = false

	if HeroExport.canvas then
		ArtExport = require("tools.art_export")
		ArtExport.composeHero({
			canvas = HeroExport.canvas,
			width  = HeroExport.width,
			height = HeroExport.height,
		})
	end

	return true

	--[[return {
		canvas = HeroExport.canvas,
		width  = HeroExport.width,
		height = HeroExport.height,
	}]]
end

return HeroExport