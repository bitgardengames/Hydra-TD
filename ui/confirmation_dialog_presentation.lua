-- Pure, deterministic presentation poses for confirmation dialogs.
local Presentation = {}

Presentation.OPEN_DURATION = 0.18
Presentation.CANCEL_DURATION = 0.14
Presentation.CONFIRM_DURATION = 0.22
Presentation.REDUCED_DURATION = 0.06

local function clamp01(value)
	return math.max(0, math.min(1, value))
end

local function smooth(value)
	return value * value * (3 - 2 * value)
end

function Presentation.duration(state, reducedMotion, closeReason)
	if reducedMotion then return Presentation.REDUCED_DURATION end
	if state == "opening" then return Presentation.OPEN_DURATION end
	if state == "closing" and closeReason == "confirm" then return Presentation.CONFIRM_DURATION end
	if state == "closing" then return Presentation.CANCEL_DURATION end
	return 0
end

function Presentation.pose(state, elapsed, reducedMotion, closeReason)
	if state == "open" then
		return { dimmerAlpha = 0.72, panelAlpha = 1, scale = 1, offsetY = 0, pointerReady = true, complete = true }
	end

	local duration = Presentation.duration(state, reducedMotion, closeReason)
	local progress = duration == 0 and 1 or clamp01(elapsed / duration)
	local eased = smooth(progress)
	local visibility = state == "opening" and eased or 1 - eased
	local scale, offsetY = 1, 0

	if not reducedMotion then
		if state == "opening" then
			scale = 0.97 + 0.03 * eased
			offsetY = 10 * (1 - eased)
		elseif closeReason == "confirm" then
			-- A quick settle communicates acceptance before the panel departs.
			local press = math.sin(math.min(progress / 0.55, 1) * math.pi)
			scale = 1 - 0.025 * press
			offsetY = -3 * eased
		else
			scale = 1 - 0.02 * eased
			offsetY = 7 * eased
		end
	end

	return {
		dimmerAlpha = 0.72 * visibility,
		panelAlpha = visibility,
		scale = scale,
		offsetY = offsetY,
		pointerReady = state == "opening" and progress >= 0.72,
		complete = progress >= 1,
	}
end

return Presentation
