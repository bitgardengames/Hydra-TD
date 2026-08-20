package.loaded["core.state"] = {speed = 1}

local State = require("core.state")
local GameSpeed = require("core.game_speed")

assert(#GameSpeed.supported == 2, "only normal and fast speed should be supported")
assert(GameSpeed.supported[1] == 1, "normal speed should be the first option")
assert(GameSpeed.supported[2] == 2, "fast speed should be the second option")

assert(GameSpeed.cycle() == 2, "speed should advance from 1x to 2x")
assert(GameSpeed.cycle() == 1, "speed should wrap from 2x to 1x")

State.speed = 3
assert(GameSpeed.cycle() == 1, "unsupported legacy speeds should recover to 1x")
assert(GameSpeed.getSoundCooldownScale("repetitive", 3) == 0.50,
	"unsupported speeds should use the normal-speed sound policy")

print("game speed fixtures: ok")
