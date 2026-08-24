-- Deterministic presentation poses derived from the pause transition owned by State.
local Presentation = {}

local function clamp01(value)
	return math.max(0, math.min(1, value or 0))
end

local function smoothstep(value)
	local t = clamp01(value)
	return t * t * (3 - 2 * t)
end

function Presentation.pose(progress, reducedMotion)
	if reducedMotion then progress = 1 end

	-- Let the context arrive just behind the primary pause controls.
	local contextProgress = smoothstep((clamp01(progress) - 0.15) / 0.85)

	return {
		contextAlpha = contextProgress,
		contextSlide = 12 * (1 - contextProgress),
	}
end

return Presentation
