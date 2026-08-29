-- Pure timing helpers for the victory reward reveal. Keeping this independent
-- of LÖVE makes the sequence deterministic and easy to fixture-test.
local RewardReveal = {}

RewardReveal.STAGGER = 0.12
RewardReveal.DURATION = 0.72
RewardReveal.GLINT_DURATION = 0.9

local function clamp(value)
	return math.max(0, math.min(1, value))
end

function RewardReveal.delayFor(index)
	return math.max(0, (index - 1) * RewardReveal.STAGGER)
end

function RewardReveal.sample(elapsed, delay, reducedMotion)
	local progress = clamp((elapsed - delay) / RewardReveal.DURATION)
	local eased = 1 - (1 - progress) ^ 3
	local glint = clamp((elapsed - delay) / RewardReveal.GLINT_DURATION)
	local scale = 1 + math.sin(progress * math.pi) * (1 - progress) * 0.09
	return {
		progress = progress,
		alpha = reducedMotion and 1 or eased,
		lift = reducedMotion and 0 or 12 * (1 - eased),
		scale = reducedMotion and 1 or scale,
		glint = glint,
		complete = elapsed >= delay + RewardReveal.GLINT_DURATION,
	}
end

return RewardReveal
