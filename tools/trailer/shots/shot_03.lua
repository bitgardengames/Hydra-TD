local Camera = require("tools.trailer.camera")
local Actions = require("tools.trailer.actions")
local Constants = require("core.constants")

local mapCX = Constants.GRID_W * Constants.TILE * 0.5
local mapCY = Constants.GRID_H * Constants.TILE * 0.5

local tile = Constants.TILE

local adjustX = tile * 6
local adjustY = -(tile)

return {
	map = 5,
	duration = 6.5,
	next = "shot_04",

	scene = {
		towers = {
			{kind = "poison", gx = 9,  gy = 9},
			{kind = "shock",  gx = 8, gy = 9},
			{kind = "lancer",  gx = 12, gy = 8},
			{kind = "slow",  gx = 14, gy = 11},
		},

		wave = {
			index = 6,
			start = true,
			warmup = 31.3,
		},
	},

	actions = {
		{t = 2.55, fn = Actions.upgradeTowerAt(8,  9, 1)},
		{t = 3.55, fn = Actions.upgradeTowerAt(12, 8, 1)},
		{t = 4.55, fn = Actions.upgradeTowerAt(9,  9, 1)},
	},

	camera = Camera.pan({
		duration = 6.0,
		from = {x = mapCX - adjustX, y = mapCY - adjustY, zoom = 2.8},
		to = {x = mapCX - adjustX, y = mapCY - adjustY, zoom = 2.8}
	}),

	text = {
		{t = 0.8, text = "UPGRADE", dur = 3, fadeIn = 0.25, fadeOut = 0.4},
	},
}
