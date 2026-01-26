local Theme = require("core.theme")
local Entities = require("ui.draw_entities")

local Title = {}

local lg = love.graphics
local pi = math.pi
local min = math.min
local max = math.max
local rad = math.rad
local floor = math.floor

local BASE_LANCER_VISUAL_W = 50
local FONT_RATIO = 0.72
local BANNER_LANCER_SCALE_FACTOR = 0.0048

local ROTATE_TIME = 1.8
local HOLD_TIME = 5.0

local SERVO_AMPLITUDE = rad(0.35)
local SERVO_SPEED = 1.8

local function deriveTitleFont(lancerScale)
	local fontPx = floor(BASE_LANCER_VISUAL_W * lancerScale * FONT_RATIO)

	return love.graphics.newFont("assets/fonts/PTSans.ttf", fontPx)
end

function Title.updateLancerIdle(state, dt, timeNow)
    local ROTATE_TIME = 1.8
    local HOLD_TIME   = 5.0

    if state.startupHold > 0 then
        state.startupHold = state.startupHold - dt
        state.angle = -math.pi / 6
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

    local a, b
    if state.dir == 1 then
        a, b = state.from, state.to
    else
        a, b = state.to, state.from
    end

    state.angle = a + (b - a) * p

    if state.hold > 0 then
        local SERVO_AMPLITUDE = math.rad(0.35)
        local SERVO_SPEED = 1.8
        local fade = math.min(1, state.hold / 0.6)

        local servo = math.sin(timeNow * SERVO_SPEED)
            * SERVO_AMPLITUDE
            * fade

        state.angle = state.angle + servo
    end
end

function Title.draw(opts)
	opts = opts or {}

	local x = opts.x or 0
	local y = opts.y or 0
	local scale = opts.scale or 1
	local angle = opts.angle or -math.pi / 6
	local alpha = opts.alpha or 1

	local GAP = opts.gap or 26
	local LANCER_SCALE = opts.lancerScale or 2.2
	local LANCER_Y_OFFSET = opts.lancerYOffset or -7

	local font = opts.font or deriveTitleFont(LANCER_SCALE)

	lg.push()
	lg.translate(x, y)
	lg.scale(scale, scale)

	lg.setFont(font)

	local text = "HYDRA TD"
	local textW = font:getWidth(text)
	local textH = font:getHeight()
	local TEXT_Y_OFFSET = 3

	-- derived visual width
	local lancerVisualW = BASE_LANCER_VISUAL_W * LANCER_SCALE

	local groupW = lancerVisualW + GAP + textW
	local baseX = -groupW * 0.5

	-- Lancer
	lg.push()
	lg.translate(baseX + lancerVisualW * 0.5, LANCER_Y_OFFSET)
	lg.scale(LANCER_SCALE, LANCER_SCALE)

	Entities.drawTowerCore("lancer", 0, 0, {angle  = angle, alpha  = alpha, shadow = false})

	lg.pop()

	-- Outline
	local outline = 5 * (LANCER_SCALE / 2) + 0.5

	lg.setColor(0, 0, 0, 0.55 * alpha)

	for ox = -outline, outline do
		for oy = -outline, outline do
			if ox ~= 0 or oy ~= 0 then
				lg.print(text, baseX + lancerVisualW + GAP + ox, -textH * 0.5 + TEXT_Y_OFFSET + oy)
			end
		end
	end

	-- Fill
	lg.setColor(Theme.tower.lancer[1], Theme.tower.lancer[2], Theme.tower.lancer[3], alpha)
	lg.print(text, baseX + lancerVisualW + GAP, -textH * 0.5 + TEXT_Y_OFFSET)

	lg.pop()
end

function Title.drawBannerStyle(w, h, opts)
	opts = opts or {}

	local angle = opts.angle or -pi / 6
	local alpha = opts.alpha or 1

	local aspect = w / h
	local horizontalBoost = min(2.4, max(1.0, aspect))

	local LANCER_SCALE = min(w, h) * BANNER_LANCER_SCALE_FACTOR * horizontalBoost
	local lancerVisualW = BASE_LANCER_VISUAL_W * LANCER_SCALE
	local GAP = lancerVisualW * 0.16

	-- Vertical anchors
	local centerY = h * 0.5
	local upperThirdY = h * 0.333
	local upperThirdDrop = h * 0.06

	-- Final anchor
	local anchorY

	if aspect < 0.9 then
		anchorY = upperThirdY + upperThirdDrop
	else
		anchorY = centerY
	end

	local font = deriveTitleFont(LANCER_SCALE)
	lg.setFont(font)

	local text = "HYDRA TD"
	local textW = font:getWidth(text)
	local textH = font:getHeight()

	local outline = 5 * (LANCER_SCALE / 2) + 0.5
	local OUTLINE_PAD = outline

	-- Group width
	local TEXT_BASELINE_BIAS = textH * 0.08
	local TEXT_OPTICAL_BIAS = textW * 0.020
	local groupW = lancerVisualW + GAP + textW + OUTLINE_PAD * 2
	local baseX = (w - groupW) * 0.5 - TEXT_OPTICAL_BIAS

	-- Draw lancer
	lg.push()
	lg.translate(baseX + lancerVisualW * 0.5, anchorY)
	lg.scale(LANCER_SCALE, LANCER_SCALE)

	Entities.drawTowerCore("lancer", 0, 0, {angle  = angle, alpha  = alpha, shadow = false})

	lg.pop()

	-- Draw title
	lg.setColor(0, 0, 0, 0.55 * alpha)

	for ox = -outline, outline do
		for oy = -outline, outline do
			if ox ~= 0 or oy ~= 0 then
				lg.print(text, baseX + lancerVisualW + GAP + ox, anchorY - textH * 0.5 + TEXT_BASELINE_BIAS + oy)
			end
		end
	end

	lg.setColor(Theme.tower.lancer[1], Theme.tower.lancer[2], Theme.tower.lancer[3], alpha)
	lg.print(text, baseX + lancerVisualW + GAP, anchorY - textH * 0.5 + TEXT_BASELINE_BIAS)
end

function Title.drawMenuAnimatedBannerStyle(w, h, t, opts)
    opts = opts or {}

    local angle = Title.computeLancerAngle(t, opts)

    Title.drawBannerStyle(w, h, {alpha = opts.alpha, angle = angle})
end

return Title