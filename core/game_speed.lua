local State = require("core.state")

local GameSpeed = {}

-- Keep gameplay speed choices ordered here so every control cycles through the
-- same values. Callers should use cycle() rather than changing State.speed.
GameSpeed.supported = {1, 2, 4}

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
