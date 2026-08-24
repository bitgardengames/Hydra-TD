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

	return {
		titleAlpha = title,
		titleLift = 7 * (1 - title),
	}
end

return Presentation
