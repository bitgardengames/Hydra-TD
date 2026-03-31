local Camera = require("tools.trailer.camera")
local Actions = require("tools.trailer.actions")
local Constants = require("core.constants")
local Maps = require("world.map_defs")

local mapCX = Constants.GRID_W * Constants.TILE * 0.5
local mapCY = Constants.GRID_H * Constants.TILE * 0.5

local tile = Constants.TILE

local adjustX = tile * 2.8
local adjustY = tile * 3.5

return {
	map = 2,
	duration = 4.0,

	scene = {
		towers = {
			{kind = "plasma", gx = 22, gy = 11},
		},

		wave = {
			index = 4,
			start = true,
			warmup = 27.0,
		},
	},

    actions = {
		{t = 0, fn = Actions.upgradeTowerAt(22, 11, 1)},
    },

	camera = Camera.pan({
		duration = 7.0,
		from = {x = mapCX + adjustX, y = mapCY + adjustY, zoom = 4},
		to = {x = mapCX + adjustX, y = mapCY + adjustY, zoom = 4}
	}),
}