local Constants = require("core.constants")
local Camera = require("core.camera")
local State  = require("core.state")
local Title  = require("ui.title")

local lg = love.graphics
local min = math.min
local max = math.max

local HeroExport = {}

-- Formats (existing behavior preserved)
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
		verticalBias = 0.0,
	},
}

-- Banner Sizes
HeroExport.BANNERS = {
	-- Steam banner sizes
	main_capsule = {w = 1232, h = 706},
	header_capsule = {w = 920, h = 430},
	small_capsule = {w = 462, h = 174},
	vertical_capsule = {w = 748, h = 896},

	library_hero = {w = 3840, h = 1240},
	library_logo = {w = 1280, h = 720},
	library_header = {w = 920, h = 430},
	library_capsule = {w = 600, h = 900},

	page_background = {w = 1438, h = 810},

	-- Social banners
	youtube_banner = {w = 2048, h = 1152},
	reddit_banner = {w = 1920, h = 384},
	reddit_mobile_banner = {w = 1600, h = 480},
	x_banner = {w = 1500, h = 500},

	-- Desktop
	desktop = {w = 1920, h = 1080},
}

HeroExport.TEXTLESS_BANNERS = {
	library_hero = true,
	page_background = true,
}

HeroExport.TRANSPARENT_BANNERS = {
	library_logo = true,
	main_capsule = true,
	header_capsule = true,
	small_capsule = true,
	desktop = true,
}

HeroExport.TITLE_DROP_BY_BANNER = {
	vertical_capsule = 0.34,
	library_capsule = 0.36,
	small_capsule = 0.31,
}

HeroExport.TEXT_SCALE_BIAS = {
	small_capsule = 0.72,
}

-- State
HeroExport.active = false
HeroExport.canvas = nil
HeroExport.subject = nil
HeroExport.subjectType = nil

HeroExport.width = 3840
HeroExport.height = 1240
HeroExport.subjectScale = 0.7
HeroExport.verticalBias = 0.1
HeroExport.frameLift = 66
HeroExport.extraZoom = 3.0
HeroExport.titleDrop = 0.28

HeroExport.captureX = 0
HeroExport.captureY = 0
HeroExport._prevPaused = nil

HeroExport.logoCache = {}

-- Setup
function HeroExport.init()
	HeroExport._rebuildCanvas()
end

function HeroExport.setFormat(name)
	local f = HeroExport.formats[name]
	assert(f, "Unknown HeroExport format: " .. tostring(name))

	HeroExport.width = f.width
	HeroExport.height = f.height
	HeroExport.subjectScale = f.subjectScale
	HeroExport.verticalBias = f.verticalBias

	HeroExport._rebuildCanvas()
end

function HeroExport._rebuildCanvas()
	HeroExport.canvas = lg.newCanvas(HeroExport.width, HeroExport.height, {msaa = 8})
end

-- Subject Bounds
function HeroExport.getSubjectBounds()
	local s = HeroExport.subject
	if not s then return nil end

	if HeroExport.subjectType == "tower" then
		local r =
			(s.def and s.def.visualRadius) or
			s.visualRadius or
			32

		return { x = s.x, y = s.y, r = r }
	end

	if HeroExport.subjectType == "enemy" then
		local r = s.radius or s.r or 16
		return { x = s.x, y = s.y, r = r }
	end

	return nil
end

function HeroExport.frameOnSubject()
	local b = HeroExport.getSubjectBounds()
	if not b then
		return HeroExport.captureX, HeroExport.captureY
	end

	local cx = b.x
	local lift = HeroExport.verticalBias or 0.1
	local cy = b.y - b.r * lift + (b.r * HeroExport.frameLift)

	return cx, cy
end

function HeroExport.computeZoom(bounds)
	local diameter = bounds.r * 2
	local minScreen = min(HeroExport.width, HeroExport.height)
	local targetPixels = minScreen * HeroExport.subjectScale
	return targetPixels / diameter
end

-- Capture
function HeroExport.capture(opts)
	opts = opts or {}

	HeroExport.active      = true
	HeroExport.subject     = assert(opts.subject, "HeroExport.capture requires subject")
	HeroExport.subjectType = assert(opts.subjectType, "HeroExport.capture requires subjectType")

	if opts.freezeSim ~= false then
		HeroExport._prevPaused = State.paused
		State.paused = true
	end

	HeroExport.captureX, HeroExport.captureY =
		HeroExport.frameOnSubject()
end

-- Rendering Helpers
local function drawVignette(w, h)
	local steps = 32
	local maxInset = math.min(w, h) * 0.06

	for i = 1, steps do
		local t = i / steps
		local inset = t * maxInset
		local alpha = 0.025 * (1 - t) ^ 2

		lg.setColor(0, 0, 0, alpha)

		lg.rectangle("fill", 0, 0, w, inset)
		lg.rectangle("fill", 0, h - inset, w, inset)
		lg.rectangle("fill", 0, inset, inset, h - inset * 2)
		lg.rectangle("fill", w - inset, inset, inset, h - inset * 2)
	end
end

local function drawScaledFill(srcCanvas, targetW, targetH)
	local sw = srcCanvas:getWidth()
	local sh = srcCanvas:getHeight()

	local scale = math.max(targetW / sw, targetH / sh)

	local drawW = sw * scale
	local drawH = sh * scale

	local dx = (targetW - drawW) * 0.5
	local dy = (targetH - drawH) * 0.5

	lg.draw(srcCanvas, dx, dy, 0, scale, scale)
end

function HeroExport.getLogoCanvas(name)
	if HeroExport.logoCache[name] then
		return HeroExport.logoCache[name]
	end

	local b = HeroExport.BANNERS[name]

	if not b then
		return nil
	end

	local canvas = lg.newCanvas(b.w, b.h, {msaa = 8})

	lg.setCanvas(canvas)
	lg.clear(0, 0, 0, 0)

	Title.invalidateCache()

	local bias = HeroExport.SCALE_BIAS[name] or 1

	Title.textScaleBias = HeroExport.TEXT_SCALE_BIAS and HeroExport.TEXT_SCALE_BIAS[name] or 1

	Title.drawBannerStyle(b.w, b.h, -math.pi / 6, 1, 0, bias)

	Title.textScaleBias = nil

	lg.setCanvas()

	HeroExport.logoCache[name] = canvas

	return canvas
end

local function exportCanvas(canvas, filePath)
	local img = canvas:newImageData()
	img:encode("png", filePath)
end

local cachedCanvas

-- Render the world to a target canvas size using the SAME framing rules,
function HeroExport.renderWorldToCanvas(w, h, renderWorldFn)
    -- Save live camera state
    local prevCanvas = Camera.canvas
    local prevWx = Camera.wx
    local prevWy = Camera.wy
    local prevScale = Camera.wscale

    -- Create export canvas
	if not cachedCanvas or cachedCanvas:getWidth() ~= w or cachedCanvas:getHeight() ~= h then
		cachedCanvas = lg.newCanvas(w, h, {msaa = 8})
	end

	local canvas = cachedCanvas
    Camera.canvas = canvas

    -- Live screen size
    local liveW, liveH = love.graphics.getDimensions()

    -- Preserve exact world center
    local centerWorldX = prevWx + (liveW / (2 * prevScale))
    local centerWorldY = prevWy + (liveH / (2 * prevScale))
	-- Apply vertical lift in world space
	local liftAmount = HeroExport.frameLift or 0

	-- Positive frameLift moves scene upward visually
	centerWorldY = centerWorldY + liftAmount

	local scaleFactor = w / liveW
	local newScale = prevScale * scaleFactor * HeroExport.extraZoom

    Camera.wscale = newScale

    -- Recenter camera for new canvas size
    Camera.wx = centerWorldX - (w / (2 * newScale))
    Camera.wy = centerWorldY - (h / (2 * newScale))

    -- Render
    Camera.begin()
    renderWorldFn()
    Camera.finish()

    -- Restore camera
    Camera.canvas = prevCanvas
    Camera.wx     = prevWx
    Camera.wy     = prevWy
    Camera.wscale = prevScale

    return canvas
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

	lg.scale(scale, scale)

	lg.translate(
		-HeroExport.captureX,
		-HeroExport.captureY
	)

	lg.translate(
		HeroExport.width  * 0.5 / scale,
		HeroExport.height * 0.5 / scale
	)

	renderWorldFn()
	lg.pop()

	lg.setCanvas(prevCanvas)

	if HeroExport._prevPaused ~= nil then
		State.paused = HeroExport._prevPaused
		HeroExport._prevPaused = nil
	end

	HeroExport.active = false

	HeroExport.exportAllFromWorld(renderWorldFn)

	return true
end

function HeroExport.exportAllFromCanvas(srcCanvas)
	if not srcCanvas then
		return
	end

	love.filesystem.createDirectory("export")
	love.filesystem.createDirectory("export/hero")

	for name, b in pairs(HeroExport.BANNERS) do
		local canvas = lg.newCanvas(b.w, b.h, {msaa = 8})
		lg.setCanvas(canvas)
		lg.clear(0, 0, 0, 0)

		lg.setColor(1,1,1,1)
		drawScaledFill(srcCanvas, b.w, b.h)

		drawVignette(b.w, b.h)

		if not HeroExport.TEXTLESS_BANNERS[name] then
			lg.setBlendMode("alpha")
			lg.setColor(1, 1, 1, 1)

			Title.invalidateCache()
			Title.drawBannerStyle(b.w, b.h, -math.pi / 6, 1, b.h * 0.14)
		end

		lg.setCanvas()

		local filePath = string.format("export/hero/%s_%dx%d.png", name, b.w, b.h)
		exportCanvas(canvas, filePath)

		if HeroExport.TRANSPARENT_BANNERS[name] then
			local logo = HeroExport.getLogoCanvas(name)

			if logo then
				local tCanvas = lg.newCanvas(b.w, b.h, {msaa = 8})
				lg.setCanvas(tCanvas)
				lg.clear(0, 0, 0, 0)

				lg.setBlendMode("alpha")
				lg.setColor(1, 1, 1, 1)
				lg.draw(logo, 0, 0)

				lg.setCanvas()

				local tPath = string.format("export/hero/%s_%dx%d_transparent.png", name, b.w, b.h)
				exportCanvas(tCanvas, tPath)
			end
		end
	end

	print("HeroExport: All banner sizes exported (scaled).")
end

-- New: Crisp export path (native render per size)
function HeroExport.exportAllFromWorld(renderWorldFn)
	if not renderWorldFn then
		return
	end

	love.filesystem.createDirectory("export")
	love.filesystem.createDirectory("export/hero")

	for name, b in pairs(HeroExport.BANNERS) do
		local canvas = HeroExport.renderWorldToCanvas(b.w, b.h, renderWorldFn)
		if canvas then
			lg.setCanvas(canvas)

			-- Post effects + branding
			lg.setBlendMode("alpha")
			drawVignette(b.w, b.h)

			if not HeroExport.TEXTLESS_BANNERS[name] then
				local drop = HeroExport.TITLE_DROP_BY_BANNER[name] or HeroExport.titleDrop

				lg.setBlendMode("alpha")
				lg.setColor(1, 1, 1, 1)
				Title.invalidateCache()

				Title.invalidateCache()

				Title.textScaleBias = HeroExport.TEXT_SCALE_BIAS and HeroExport.TEXT_SCALE_BIAS[name] or 1

				Title.drawBannerStyle(b.w, b.h, -math.pi / 6, 1, b.h * drop)

				Title.textScaleBias = nil
			end

			lg.setCanvas()

			local filePath = string.format("export/hero/%s_%dx%d.png", name, b.w, b.h)
			exportCanvas(canvas, filePath)

			-- Transparent variant stays logo-only (kept exactly as before)
			if HeroExport.TRANSPARENT_BANNERS[name] then
				local tCanvas = lg.newCanvas(b.w, b.h, {msaa = 8})
				lg.setCanvas(tCanvas)
				lg.clear(0, 0, 0, 0)

				lg.setBlendMode("alpha")
				lg.setColor(1,1,1,1)
				Title.invalidateCache()
				Title.drawBannerStyle(b.w, b.h, -math.pi / 6, 1, 0)

				lg.setCanvas()

				local tPath = string.format("export/hero/%s_%dx%d_transparent.png", name, b.w, b.h)
				exportCanvas(tCanvas, tPath)
			end
		end
	end

	print("HeroExport: All banner sizes exported (crisp native render).")
end

return HeroExport