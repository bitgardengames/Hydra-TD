local Camera = require("tools.trailer.camera")
local Actions = require("tools.trailer.actions")
local Constants = require("core.constants")

local mapCX = Constants.GRID_W * Constants.TILE * 0.5
local mapCY = Constants.GRID_H * Constants.TILE * 0.5

return {
	map = 5,
	duration = 6.0,
	next = "shot_05",

	scene = {
		towers = {
			{ kind = "poison", gx = 9,  gy = 9 },
			{ kind = "shock",  gx = 8, gy = 9 },
			{ kind = "lancer",  gx = 12, gy = 8 },
			{ kind = "slow",  gx = 12, gy = 11 },
		},
		wave = {
			index = 6,
			start = true,
			warmup = 26,
		},
	},

	actions = {
		{ t = 1.55, fn = Actions.upgradeTowerAt(8,  9, 1) }, -- shock +1
		{ t = 2.55, fn = Actions.upgradeTowerAt(12, 8, 1) }, -- lancer +1
		{ t = 3.55, fn = Actions.upgradeTowerAt(9,  9, 1) }, -- poison +1
	},

	camera = Camera.pan({
		duration = 6.0,
		from = {x = mapCX, y = mapCY, zoom = 1.28},
		to = {x = mapCX, y = mapCY, zoom = 1.28}
	}),

	text = {
		{
			t = 0.8,
			text = "Upgrade",
			dur = 3,
			fadeIn = 0.25,
			fadeOut = 0.4,
		},
	},
}
