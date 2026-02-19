local Camera = require("tools.trailer.camera")
local Actions = require("tools.trailer.actions")
local Constants = require("core.constants")

local mapCX = Constants.GRID_W * Constants.TILE * 0.5
local mapCY = Constants.GRID_H * Constants.TILE * 0.5

local tile = Constants.TILE

local adjustX = tile * 1
local adjustY = tile * 2

return {
    map = 12,
    duration = 8.0,
    next = "shot_03",

    scene = {
        wave = {
			index = 2,
            start = true,
            warmup = 5.0,
        },
    },

	camera = Camera.pan({
		duration = 7.0,
		from = {x = mapCX - adjustX, y = mapCY - adjustY, zoom = 3.0},
		to = {x = mapCX - adjustX, y = mapCY - adjustY, zoom = 3.0}
	}),

    actions = {
		{t = 2.25, fn = Actions.placeTower("lancer", 14, 7)},
		{t = 3.25, fn = Actions.placeTower("cannon", 16, 6)},
        {t = 4.25, fn = Actions.placeTower("lancer", 18, 7)},
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