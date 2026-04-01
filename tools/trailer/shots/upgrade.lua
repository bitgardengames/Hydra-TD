local Camera = require("tools.trailer.camera")
local Actions = require("tools.trailer.actions")
local Constants = require("core.constants")

local mapCX = Constants.GRID_W * Constants.TILE * 0.5
local mapCY = Constants.GRID_H * Constants.TILE * 0.5

local tile = Constants.TILE

local adjustX = tile * 4.2
local adjustY = tile * 2

return {
	map = 12,
	duration = 7.0,

	scene = {
		towers = {
			{kind = "poison", gx = 11,  gy = 9},
			--{kind = "plasma", gx = 9,  gy = 8},
			{kind = "shock",  gx = 12, gy = 10},
			{kind = "lancer",  gx = 13, gy = 9},
		},

		wave = {
			index = 7,
			start = true,
			warmup = 22,
		},
	},

	actions = {
		{t = 0, fn = Actions.setMoney(9999)},
		{t = 1.50, fn = Actions.upgradeTowerAt(11,  9, 1)},
		--{t = 1.50, fn = Actions.upgradeTowerAt(9,  8, 1)},
		{t = 2.50, fn = Actions.upgradeTowerAt(12, 10, 1)},
		{t = 3.50, fn = Actions.upgradeTowerAt(13,  9, 1)},
	},

	camera = Camera.pan({
		duration = 8.0,
		from = {x = mapCX - adjustX, y = mapCY + adjustY, zoom = 3.0},
		to = {x = mapCX - adjustX, y = mapCY + adjustY, zoom = 3.0}
	}),

	text = {
		{t = 0.8, text = "UPGRADE", dur = 3, fadeIn = 0.25, fadeOut = 0.4},
	},
}