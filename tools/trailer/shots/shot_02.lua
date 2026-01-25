local Camera = require("tools.trailer.camera")
local Constants = require("core.constants")

local mapCX = Constants.GRID_W * Constants.TILE * 0.5
local mapCY = Constants.GRID_H * Constants.TILE * 0.5

return {
    map = 3,
    duration = 6.0,
    next = "shot_03",

    scene = {
        towers = {
            { kind = "lancer",   gx = 10, gy = 7 },
            { kind = "slow",   gx = 8, gy = 9 },
            { kind = "cannon", gx = 12, gy = 7 },
            { kind = "lancer", gx = 12, gy = 4 },
        },
        wave = {
			index = 5,
            start = true,
            warmup = 5.0,
        },
    },

	camera = Camera.pan({
		duration = 6.0,
		from = {x = mapCX, y = mapCY, zoom = 1.28},
		to = {x = mapCX, y = mapCY, zoom = 1.28}
	}),

	text = {
		{
			t = 0.8,
			text = "Strategize",
			dur = 3,
			fadeIn = 0.25,
			fadeOut = 0.4,
		},
	}
}
