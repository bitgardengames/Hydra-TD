local Camera = require("tools.trailer.camera")
local Actions = require("tools.trailer.actions")
local Constants = require("core.constants")

local mapCX = Constants.GRID_W * Constants.TILE * 0.5
local mapCY = Constants.GRID_H * Constants.TILE * 0.5

local tile = Constants.TILE

local adjustX = tile * 2
local adjustY = tile

return {
	map = 13,
	duration = 8.0,
	next = "shot_02",

	scene = {
		towers = {
			--{kind = "lancer", gx = 26, gy = 6},
			--{kind = "lancer", gx = 27, gy = 6},
		},

		wave = {
			start = true,
			warmup = 8.0,
		},
	},

    actions = {
		--{t = 0, fn = Actions.upgradeTowerAt(27, 10, 1)},
    },

	camera = Camera.pan({
		duration = 7.0,
		from = {x = mapCX - adjustX, y = mapCY - adjustY, zoom = 2.0},
		to = {x = mapCX - adjustX, y = mapCY - adjustY, zoom = 2.0}
	}),
}