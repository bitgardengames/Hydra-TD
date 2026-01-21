local Camera  = require("tools.trailer.camera")
local Actions = require("tools.trailer.actions")

return {
	map = 2,
	duration = 5.0,
	next = "shot_02",

	scene = {
		towers = {
			{kind = "lancer", gx = 10, gy = 6},
		},

		wave = {
			start = true,
			warmup = 1,
		},
	},

	camera = Camera.pan({
		from = {x = 0,   y = 0, zoom = 1.0},
		to = {x = -60, y = -20, zoom = 1.15},
		duration = 5.0,
	}),
}