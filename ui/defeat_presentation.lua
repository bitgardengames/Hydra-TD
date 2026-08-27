-- Pure presentation values for the game-over screen's defeat vignette.
local Presentation = {}

local period = 3
local minimumAlpha = 0.06
local maximumAlpha = 0.09

function Presentation.vignetteAlpha(elapsed, reducedMotion)
	if reducedMotion then return minimumAlpha end

	local phase = ((elapsed or 0) % period) / period
	local pulse = 0.5 + 0.5 * math.sin(phase * math.pi * 2)
	return minimumAlpha + (maximumAlpha - minimumAlpha) * pulse
end

return Presentation
