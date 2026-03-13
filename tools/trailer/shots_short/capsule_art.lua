local Camera = require("tools.trailer.camera")
local Actions = require("tools.trailer.actions")
local Constants = require("core.constants")

local mapCX = Constants.GRID_W * Constants.TILE * 0.5
local mapCY = Constants.GRID_H * Constants.TILE * 0.5

local tile = Constants.TILE

local adjustX = tile * 2
local adjustY = tile

return {
	map = 1,
	duration = 10.0,
	next = "shot_02",

	scene = {
		towers = {
			{kind = "shock", gx = 16, gy = 7},
			{kind = "lancer", gx = 17, gy = 7},
			{kind = "cannon", gx = 18, gy = 7},
			{kind = "poison", gx = 16, gy = 8},
			{kind = "slow", gx = 20, gy = 7},
		},

		wave = {
			index = 19,
			start = true,
			warmup = 12.0,
		},
	},

    actions = {
		{t = 0, fn = Actions.upgradeTowerAt(16, 7, 1)},
		{t = 0, fn = Actions.upgradeTowerAt(17, 7, 1)},
		{t = 0, fn = Actions.upgradeTowerAt(18, 7, 1)},
		{t = 0, fn = Actions.upgradeTowerAt(16, 8, 2)},
    },

	--[[camera = Camera.pan({
		duration = 7.0,
		from = {x = mapCX - adjustX, y = mapCY - adjustY, zoom = 2.0},
		to = {x = mapCX - adjustX, y = mapCY - adjustY, zoom = 2.0}
	}),]]
}