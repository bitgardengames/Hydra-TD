local Camera  = require("tools.trailer.camera")
local Actions = require("tools.trailer.actions")
local Constants = require("core.constants")

local mapCX = Constants.GRID_W * Constants.TILE * 0.5
local mapCY = Constants.GRID_H * Constants.TILE * 0.5

return {
    map = 4,
    duration = 7.0,
    next = "shot_04",

    scene = {
        towers = {
            { kind = "cannon", gx = 12, gy = 8 },
            { kind = "shock", gx = 9, gy = 9 },
            { kind = "slow", gx = 14, gy = 9 },
        },

        wave = {
			index = 6,
            start = true,
            warmup = 5.0,
        },
    },

	camera = Camera.pan({
		duration = 7.0,
		from = {x = mapCX, y = mapCY, zoom = 1.28},
		to = {x = mapCX, y = mapCY, zoom = 1.28}
	}),

    actions = {
		{ t = 0, fn = Actions.upgradeTowerAt(9, 9, 2)},
        { t = 0.3, fn = Actions.startWave() },

		{ t = 2.55, fn = Actions.placeTower("cannon", 12, 7) },
		{ t = 3.55, fn = Actions.placeTower("lancer", 14, 7) },
        { t = 4.55, fn = Actions.placeTower("poison", 12, 9) },
    },

	text = {
		{
			t = 0.8,
			text = "Build",
			dur = 3,
			fadeIn = 0.25,
			fadeOut = 0.4,
		},
	}
}
