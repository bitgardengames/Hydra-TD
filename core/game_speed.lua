local State = require("core.state")

local GameSpeed = {}

-- Keep gameplay speed choices ordered here so every control cycles through the
-- same values. Callers should use cycle() rather than changing State.speed.
GameSpeed.supported = {1, 2}

-- Presentation policy is deliberately expressed in wall-clock seconds. Gameplay
-- cooldowns still consume simulation dt; these multipliers only decide how often
-- an SFX is useful to a listener while accelerated simulation is producing it.
-- UI and important cues remain equally audible at every speed. Repetitive weapon
-- sounds get progressively stronger throttling as more shots occur per real second.
GameSpeed.soundCooldownScale = {
	[1] = { ui = 1.0, important = 1.0, repetitive = 0.50 },
	[2] = { ui = 1.0, important = 1.0, repetitive = 0.75 },
}

function GameSpeed.getSoundCooldownScale(category, speed)
	local policy = GameSpeed.soundCooldownScale[speed or State.speed]
		or GameSpeed.soundCooldownScale[GameSpeed.supported[1]]
	return policy[category] or policy.important
end

function GameSpeed.cycle()
	for i = 1, #GameSpeed.supported do
		if State.speed == GameSpeed.supported[i] then
			State.speed = GameSpeed.supported[(i % #GameSpeed.supported) + 1]
			return State.speed
		end
	end

	-- Recover predictably if a transition or older save supplied another value.
	State.speed = GameSpeed.supported[1]
	return State.speed
end

function GameSpeed.reset()
	State.speed = GameSpeed.supported[1]
	return State.speed
end

return GameSpeed
