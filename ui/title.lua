local Theme = require("core.theme")
local Entities = require("render.draw_entities")

local Title = {}

local lg = love.graphics
local pi = math.pi
local min = math.min
local max = math.max
local rad = math.rad
local floor = math.floor
local sin = math.sin
local ceil = math.ceil

local BASE_LANCER_VISUAL_W = 50
local FONT_RATIO = 0.72
local BANNER_LANCER_SCALE_FACTOR = 0.0048
local TITLE_CANVAS_MARGIN = 6
local TITLE_CANVAS_BLEED = 4
local OUTLINE_SAMPLE_STEP = 0.25

local ROTATE_TIME = 1.8
local HOLD_TIME = 5.0

local SERVO_AMPLITUDE = rad(0.35)
local SERVO_SPEED = 1.8

local TITLE_TEXT = "HYDRA TD"
--local TITLE_TEXT = "Hydra TD"

local SHOW_TOWER = true
local TOWER_TYPE = "lancer"

if love.math.random() < 0.01 then
	local towers = {"cannon", "shock", "poison", "plasma", "slow"}
	TOWER_TYPE = towers[love.math.random(1, #towers)]
end

local colorTower = Theme.tower[TOWER_TYPE]
local colorOutline = Theme.outline.color

local titleCache = {
	canvas = nil,
	fontPx = nil,
	textW = 0,
	textH = 0,
	opticalH = 0,
	pad = 0,
	outlineOffsets = nil,
}

local function buildOutlineOffsets(radius)
	local offsets = {}
	local limit = ceil(radius + 1)

	for oy = -limit, limit, OUTLINE_SAMPLE_STEP do
		for ox = -limit, limit, OUTLINE_SAMPLE_STEP do
			local dist = (ox * ox + oy * oy) ^ 0.5
			local alpha = min(1, max(0, (radius + 0.5) - dist))

			if dist > 0 and alpha > 0 then
				offsets[#offsets + 1] = {ox = ox, oy = oy, alpha = alpha}
			end
		end
	end

	table.sort(offsets, function(a, b)
		return a.alpha < b.alpha
	end)

	return offsets
end

function Title.invalidateCache()
	if titleCache.canvas then
		titleCache.canvas:release()
	end

	titleCache.canvas = nil
	titleCache.fontPx = nil
end

local function buildTitleCanvas(lancerScale)
	local fontPx = floor(BASE_LANCER_VISUAL_W * lancerScale * FONT_RATIO * (Title.textScaleBias or 1))

	if titleCache.canvas and titleCache.fontPx == fontPx then
		return
	end

	Title.invalidateCache()

	local prevCanvas = lg.getCanvas()

	local font = lg.newFont("assets/fonts/PTSans.ttf", fontPx)
	--local font = lg.newFont("assets/fonts/Fredoka_SemiCondensed-SemiBold.ttf", fontPx)
	lg.setFont(font)

	local textW = font:getWidth(TITLE_TEXT)
	local textH = font:getHeight()

	-- Optical (visual) height: ascent minus descent
	local ascent = font:getAscent()
	local descent = font:getDescent()
	local opticalH = ascent - descent

	local outline = max(1.0, 5 * (lancerScale / 2))
	-- Add bleed so anti-aliased outline pixels are not clipped by canvas edges.
	local pad = ceil(outline) + TITLE_CANVAS_MARGIN + TITLE_CANVAS_BLEED

	local canvas = lg.newCanvas(textW + pad * 2, textH + pad * 2, {msaa = 8})

	lg.setCanvas(canvas)
	lg.clear(0, 0, 0, 0)

	-- Outline
	local outlineOffsets = buildOutlineOffsets(outline)

	for _, offset in ipairs(outlineOffsets) do
		lg.setColor(colorOutline[1], colorOutline[2], colorOutline[3], (colorOutline[4] or 1) * offset.alpha)
		lg.print(TITLE_TEXT, pad + offset.ox, pad + offset.oy)
	end

	-- Fill
	lg.setColor(colorTower)
	lg.print(TITLE_TEXT, pad, pad)

	lg.setCanvas(prevCanvas)

	titleCache.canvas = canvas
	titleCache.fontPx = fontPx
	titleCache.textW = textW
	titleCache.textH = textH
	titleCache.opticalH = opticalH
	titleCache.pad = pad
	titleCache.outlineOffsets = outlineOffsets
end

function Title.updateLancerIdle(state, dt, timeNow)
	if state.startupHold > 0 then
		state.startupHold = state.startupHold - dt
		state.angle = -pi / 6

		return
	end

	if state.hold > 0 then
		state.hold = state.hold - dt
	else
		state.t = state.t + dt / ROTATE_TIME

		if state.t >= 1 then
			state.t = 0
			state.hold = HOLD_TIME
			state.dir = -state.dir
		end
	end

	local p = state.t

	p = p * p * (3 - 2 * p)

	local a, b = state.from, state.to

	if state.dir ~= 1 then
		a, b = b, a
	end

	state.angle = a + (b - a) * p

	if state.hold > 0 then
		local fade = min(1, state.hold / 0.6)

		state.angle = state.angle + sin(timeNow * SERVO_SPEED) * SERVO_AMPLITUDE * fade
	end
end

local function drawTitleLayout(originX, originY, layoutScale, lancerScale, gap, angle, alpha)
	buildTitleCanvas(lancerScale)

	local lancerVisualW = BASE_LANCER_VISUAL_W * lancerScale
	local groupW = lancerVisualW + gap + titleCache.textW
	local OPTICAL_CENTER_BIAS = titleCache.textW * 0.020

	-- Centered around origin
	local baseX = -groupW * 0.5 - OPTICAL_CENTER_BIAS

	local LANCER_Y_OFFSET = -7
	local TEXT_Y_OFFSET = 3
	local midY = LANCER_Y_OFFSET

	lg.push()
	lg.translate(originX, originY)
	lg.scale(layoutScale, layoutScale)

	-- Lancer
	if SHOW_TOWER then
		lg.push()
		lg.translate(baseX + lancerVisualW * 0.5, midY)
		lg.scale(lancerScale, lancerScale)

		Entities.drawTowerVisual(TOWER_TYPE, 0, 0, angle, 0, alpha)

		lg.pop()
	end

	-- Text
	lg.setColor(1, 1, 1, alpha)
	lg.draw(titleCache.canvas, baseX + lancerVisualW + gap - titleCache.pad, midY - titleCache.opticalH * 0.5 + TEXT_Y_OFFSET - titleCache.pad)

	lg.pop()
end

function Title.draw(x, y, scale, lancerScale, angle, alpha, gap)
	x = x or 0
	y = y or 0
	scale = scale or 1
	lancerScale = lancerScale or 2.2
	angle = angle or -pi / 6
	alpha = alpha or 1
	gap = gap or 26

	drawTitleLayout(x, y, scale, lancerScale, gap, angle, alpha)
end

function Title.drawBannerStyle(w, h, angle, alpha, yOffset)
	angle = angle or -pi / 6
	alpha = alpha or 1
	yOffset = yOffset or 0

	local aspect = w / h
	local horizontalBoost = min(2.4, max(1.0, aspect))

	if h < 200 then
		horizontalBoost = horizontalBoost * 1.18
	end

	local lancerScale = min(w, h) * BANNER_LANCER_SCALE_FACTOR * horizontalBoost
	local gap = (BASE_LANCER_VISUAL_W * lancerScale) * 0.16
	local anchorY = (aspect < 0.9) and (h * 0.333 + h * 0.06) or  (h * 0.5)

	anchorY = anchorY + yOffset

	drawTitleLayout(w * 0.5, anchorY, 1, lancerScale, gap, angle, alpha)
end

return Title
