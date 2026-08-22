-- Deterministic entrance poses for the main menu's one-shot reveal.
local Presentation = {}

local function clamp01(value)
	return math.max(0, math.min(1, value or 0))
end

local function reveal(elapsed, delay, duration, reducedMotion)
	if reducedMotion then return 1 end

	local progress = clamp01((elapsed - delay) / duration)
	return progress * progress * (3 - 2 * progress)
end

function Presentation.pose(elapsed, reducedMotion)
	local title = reveal(elapsed, 0, 0.24, reducedMotion)
	local panel = reveal(elapsed, 0.08, 0.25, reducedMotion)
	local button = reveal(elapsed, 0.18, 0.22, reducedMotion)

	return {
		titleAlpha = title,
		titleLift = 7 * (1 - title),
		panelAlpha = panel,
		panelLift = 5 * (1 - panel),
		buttonAlpha = 1,
		buttonLift = 6 * (1 - button),
		buttonPointerReady = button >= 0.72,
	}
end

return Presentation
