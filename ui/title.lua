local Theme = require("core.theme")
local Entities = require("ui.draw_entities")

local Title = {}

local lg = love.graphics
local pi = math.pi
local min = math.min
local max = math.max
local rad = math.rad
local floor = math.floor
local sin = math.sin

-- =========================================================
-- Constants
-- =========================================================

local BASE_LANCER_VISUAL_W = 50
local FONT_RATIO = 0.72
local BANNER_LANCER_SCALE_FACTOR = 0.0048

local ROTATE_TIME = 1.8
local HOLD_TIME   = 5.0

local SERVO_AMPLITUDE = rad(0.35)
local SERVO_SPEED     = 1.8

local TITLE_TEXT = "HYDRA TD"

-- =========================================================
-- Title text cache (render-only data)
-- =========================================================

local titleCache = {
	canvas = nil,
	fontPx = nil,
	textW = 0,
	textH = 0,
	pad   = 0,
}

function Title.invalidateCache()
	if titleCache.canvas then
		titleCache.canvas:release()
	end

	titleCache.canvas = nil
	titleCache.fontPx = nil
end

local function buildTitleCanvas(lancerScale)
	local fontPx = floor(BASE_LANCER_VISUAL_W * lancerScale * FONT_RATIO)

	if titleCache.canvas and titleCache.fontPx == fontPx then
		return
	end

	Title.invalidateCache()

	local prevCanvas = lg.getCanvas()

	local font = lg.newFont("assets/fonts/PTSans.ttf", fontPx)
	lg.setFont(font)

	local textW = font:getWidth(TITLE_TEXT)
	local textH = font:getHeight()

	local outline = floor(5 * (lancerScale / 2) + 0.5)
	local pad = outline + 2

	local canvas = lg.newCanvas(textW + pad * 2, textH + pad * 2)

	lg.setCanvas(canvas)
	lg.clear(0, 0, 0, 0)

	-- Outline
	lg.setColor(0, 0, 0, 0.55)
	for ox = -outline, outline do
		for oy = -outline, outline do
			if ox ~= 0 or oy ~= 0 then
				lg.print(TITLE_TEXT, pad + ox, pad + oy)
			end
		end
	end

	-- Fill
	lg.setColor(Theme.tower.lancer)
	lg.print(TITLE_TEXT, pad, pad)

	lg.setCanvas(prevCanvas)

	titleCache.canvas = canvas
	titleCache.fontPx = fontPx
	titleCache.textW  = textW
	titleCache.textH  = textH
	titleCache.pad    = pad
end

-- =========================================================
-- Lancer idle animation (unchanged)
-- =========================================================

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
	if state.dir ~= 1 then a, b = b, a end

	state.angle = a + (b - a) * p

	if state.hold > 0 then
		local fade = min(1, state.hold / 0.6)
		state.angle = state.angle
			+ sin(timeNow * SERVO_SPEED) * SERVO_AMPLITUDE * fade
	end
end

-- =========================================================
-- Menu title draw (pixel-identical)
-- =========================================================

function Title.draw(opts)
	opts = opts or {}

	local x = opts.x or 0
	local y = opts.y or 0
	local scale = opts.scale or 1
	local angle = opts.angle or -pi / 6
	local alpha = opts.alpha or 1

	local GAP = opts.gap or 26
	local LANCER_SCALE = opts.lancerScale or 2.2
	local LANCER_Y_OFFSET = opts.lancerYOffset or -7
	local TEXT_Y_OFFSET = 3

	buildTitleCanvas(LANCER_SCALE)

	local lancerVisualW = BASE_LANCER_VISUAL_W * LANCER_SCALE

	-- IMPORTANT: layout uses *text width*, not canvas width
	local groupW = lancerVisualW + GAP + titleCache.textW
	local OPTICAL_CENTER_BIAS = titleCache.textW * 0.020
	local baseX = -groupW * 0.5 - OPTICAL_CENTER_BIAS

	lg.push()
	lg.translate(x, y)
	lg.scale(scale, scale)

	-- Lancer
	lg.push()
	lg.translate(baseX + lancerVisualW * 0.5, LANCER_Y_OFFSET)
	lg.scale(LANCER_SCALE, LANCER_SCALE)
	Entities.drawTowerCore("lancer", 0, 0, {angle = angle, alpha = alpha, shadow = false})
	lg.pop()

	-- Title text
	lg.setColor(1, 1, 1, alpha)
	lg.draw(
		titleCache.canvas,
		baseX + lancerVisualW + GAP - titleCache.pad,
		-titleCache.textH * 0.5 + TEXT_Y_OFFSET - titleCache.pad
	)

	lg.pop()
end

-- Banner draw (also identical)
function Title.drawBannerStyle(w, h, opts)
	opts = opts or {}

	local angle = opts.angle or -pi / 6
	local alpha = opts.alpha or 1

	local aspect = w / h
	local horizontalBoost = min(2.4, max(1.0, aspect))

	local LANCER_SCALE = min(w, h) * BANNER_LANCER_SCALE_FACTOR * horizontalBoost
	buildTitleCanvas(LANCER_SCALE)

	local lancerVisualW = BASE_LANCER_VISUAL_W * LANCER_SCALE
	local GAP = lancerVisualW * 0.16

	local centerY = h * 0.5
	local anchorY = (aspect < 0.9)
		and (h * 0.333 + h * 0.06)
		or centerY

	local TEXT_BASELINE_BIAS = titleCache.textH * 0.08
	local TEXT_OPTICAL_BIAS  = titleCache.textW * 0.020

	local groupW = lancerVisualW + GAP + titleCache.textW + titleCache.pad * 2 - 1
	local baseX = (w - groupW) * 0.5 - TEXT_OPTICAL_BIAS

	-- Lancer
	lg.push()
	lg.translate(baseX + lancerVisualW * 0.5, anchorY)
	lg.scale(LANCER_SCALE, LANCER_SCALE)
	Entities.drawTowerCore("lancer", 0, 0, {angle = angle, alpha = alpha, shadow = false})
	lg.pop()

	-- Title text
	lg.setColor(1, 1, 1, alpha)
	lg.draw(
		titleCache.canvas,
		baseX + lancerVisualW + GAP - titleCache.pad,
		anchorY - titleCache.textH * 0.5 + TEXT_BASELINE_BIAS - titleCache.pad
	)
end

return Title