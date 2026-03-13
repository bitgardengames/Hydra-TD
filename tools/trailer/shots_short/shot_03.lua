local Camera = require("tools.trailer.camera")
local Actions = require("tools.trailer.actions")
local Constants = require("core.constants")

local mapCX = Constants.GRID_W * Constants.TILE * 0.5
local mapCY = Constants.GRID_H * Constants.TILE * 0.5

local tile = Constants.TILE

local adjustX = tile * 5
local adjustY = tile * 2

return {
	map = 12,
	duration = 5.0,
	next = "shot_04",

	scene = {
		towers = {
			{kind = "poison", gx = 11,  gy = 10},
			{kind = "shock",  gx = 12, gy = 11},
			{kind = "lancer",  gx = 13, gy = 10},
		},

		wave = {
			index = 6,
			start = true,
			warmup = 22,
		},
	},

	actions = {
		{t = 1.0, fn = Actions.upgradeTowerAt(11,  10, 1)},
		{t = 2.0, fn = Actions.upgradeTowerAt(12, 11, 1)},
		{t = 3.0, fn = Actions.upgradeTowerAt(13,  10, 1)},
	},

	camera = Camera.pan({
		duration = 8.0,
		from = {x = mapCX - adjustX, y = mapCY + adjustY, zoom = 3.0},
		to = {x = mapCX - adjustX, y = mapCY + adjustY, zoom = 3.0}
	}),
}
