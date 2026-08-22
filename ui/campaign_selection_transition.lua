local Transition = {}

Transition.DURATION = 0.22

local function clamp01(value)
	return math.max(0, math.min(1, value))
end

local function smoothstep(value)
	value = clamp01(value)
	return value * value * (3 - 2 * value)
end

function Transition.sample(fromIndex, toIndex, elapsed, reducedMotion)
	local progress = reducedMotion and 1 or clamp01(elapsed / Transition.DURATION)
	local eased = smoothstep(progress)
	return {
		progress = progress,
		complete = progress >= 1,
		markerIndex = fromIndex + (toIndex - fromIndex) * eased,
		rowIndex = fromIndex + (toIndex - fromIndex) * eased,
	}
end

return Transition
