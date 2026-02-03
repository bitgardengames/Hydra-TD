local Camera  = require("tools.trailer.camera")
local Actions = require("tools.trailer.actions")
local Constants = require("core.constants")

local mapCX = Constants.GRID_W * Constants.TILE * 0.5
local mapCY = Constants.GRID_H * Constants.TILE * 0.5

local tile = Constants.TILE

local adjustX = tile * 6
local adjustY = tile * 3

return {
    map = 2,
    duration = 7.3,
    next = "shot_03",

    scene = {
        towers = {
            { kind = "lancer", gx = 13, gy = 6 },
            { kind = "slow", gx = 10, gy = 6 },
        },

        wave = {
			index = 2,
            start = true,
            warmup = 5.0,
        },
    },

	camera = Camera.pan({
		duration = 7.0,
		from = {x = mapCX - adjustX, y = mapCY - adjustY, zoom = 2.6},
		to = {x = mapCX - adjustX, y = mapCY - adjustY, zoom = 2.6}
	}),

    actions = {
		{ t = 0, fn = Actions.upgradeTowerAt(9, 9, 2)},
        { t = 0.3, fn = Actions.startWave() },

		{ t = 2.55, fn = Actions.placeTower("cannon", 11, 4) },
		{ t = 3.55, fn = Actions.placeTower("lancer", 15, 6) },
        { t = 4.55, fn = Actions.placeTower("cannon", 13, 4) },
    },

	text = {
		{
			t = 0.8,
			text = "BUILD",
			dur = 3,
			fadeIn = 0.25,
			fadeOut = 0.4,
		},
	}
}
