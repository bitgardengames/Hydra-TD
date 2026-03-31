local Camera = require("tools.trailer.camera")
local Actions = require("tools.trailer.actions")
local Constants = require("core.constants")

local mapCX = Constants.GRID_W * Constants.TILE * 0.5
local mapCY = Constants.GRID_H * Constants.TILE * 0.5

local tile = Constants.TILE

local adjustX = -(tile * 4)
local adjustY = 0

return {
    map = 9,
    duration = 7.0,

    scene = {
        wave = {
			index = 3,
            start = true,
            warmup = 19.0,
        },
    },

	camera = Camera.pan({
		duration = 7.0,
		from = {x = mapCX - adjustX, y = mapCY - adjustY, zoom = 3.0},
		to = {x = mapCX - adjustX, y = mapCY - adjustY, zoom = 3.0}
	}),

    actions = {
		{t = 0, fn = Actions.setMoney(9999)},
		{t = 1.50, fn = Actions.placeTower("slow", 21, 7)},
		{t = 2.50, fn = Actions.placeTower("cannon", 20, 8)},
        {t = 3.50, fn = Actions.placeTower("lancer", 20, 7)},
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