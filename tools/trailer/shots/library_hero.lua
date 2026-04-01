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
local adjustY = tile - 16 -- 13 for library capsule, 14 for main capsule

return {
	map = 99,
	duration = 10.0,

	scene = {
		towers = {
			{kind = "cannon", gx = 18, gy = 6},
			{kind = "cannon", gx = 18, gy = 7},
			{kind = "lancer", gx = 20, gy = 6},
			{kind = "plasma", gx = 19, gy = 7},

			{kind = "lancer", gx = 17, gy = 9},
			--{kind = "poison", gx = 19, gy = 9},
		},

		wave = {
			index = 7,
			start = true,
			warmup = 8.0,
		},
	},

    actions = {
		--{t = 0, fn = Actions.upgradeTowerAt(21, 10, 1)},
    },

	camera = Camera.pan({
		duration = 7.0,
		--from = {x = mapCX + adjustX, y = mapCY - adjustY, zoom = 3.0},
		--to = {x = mapCX + adjustX, y = mapCY - adjustY, zoom = 3.0}

		from = {x = mapCX + adjustX, y = mapCY - adjustY, zoom = 1.5},
		to = {x = mapCX + adjustX, y = mapCY - adjustY, zoom = 1.5}
	}),
}