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
	local direction = toIndex == fromIndex and 0 or (toIndex > fromIndex and 1 or -1)
	return {
		progress = progress,
		complete = progress >= 1,
		outgoingAlpha = 1 - eased,
		incomingAlpha = eased,
		incomingOffset = reducedMotion and 0 or direction * 18 * (1 - eased),
		markerIndex = fromIndex + (toIndex - fromIndex) * eased,
		rowIndex = fromIndex + (toIndex - fromIndex) * eased,
	}
end

return Transition
