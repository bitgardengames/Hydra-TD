local Camera = require("tools.trailer.camera")
local Actions = require("tools.trailer.actions")
local Constants = require("core.constants")
local Maps = require("world.map_defs")

-- Insert a straight map
Maps[99] = {
	id = "line",
	nameKey = "map.line",
	path = {
		{4, 8}, {31, 8},
	},
}

local mapCX = Constants.GRID_W * Constants.TILE * 0.5
local mapCY = Constants.GRID_H * Constants.TILE * 0.5

local tile = Constants.TILE

local adjustX = tile
local adjustY = tile

return {
	map = 99,
	duration = 8.0,

	scene = {
		towers = {
			{kind = "cannon", gx = 18, gy = 7},
			{kind = "shock", gx = 19, gy = 7},
			
			{kind = "poison", gx = 18, gy = 9},
			{kind = "lancer", gx = 19, gy = 9},
			
			{kind = "slow", gx = 20, gy = 7},
		},

		wave = {
			index = 4,
			start = true,
			warmup = 9.0,
		},
	},

    actions = {
		--{t = 0, fn = Actions.upgradeTowerAt(21, 10, 1)},
    },

	camera = Camera.pan({
		duration = 7.0,
		from = {x = mapCX + adjustX - 32, y = mapCY - adjustY - 36, zoom = 1.4},
		to = {x = mapCX + adjustX - 32, y = mapCY - adjustY - 36, zoom = 1.4}
	}),
}