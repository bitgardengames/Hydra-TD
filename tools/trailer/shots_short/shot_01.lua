local Camera = require("tools.trailer.camera")
local Actions = require("tools.trailer.actions")
local Constants = require("core.constants")
local Maps = require("world.map_defs")

-- Insert a straight map
Maps[13] = {
	id = "line",
	nameKey = "map.line",
	path = {
		{4, 8}, {31, 8},
	},
}

return {
	map = 13, -- Using 13 isn't future proof
	duration = 5.0,
	next = "shot_02",

	scene = {
		towers = {
			{kind = "lancer", gx = 23, gy = 6},
			{kind = "cannon", gx = 24, gy = 10},
			{kind = "shock", gx = 26, gy = 10},
		},

		wave = {
			index = 1,
			start = true,
			warmup = 14,
		},
	},

    actions = {
		{t = 0, fn = Actions.upgradeTowerAt(25, 10, 1)},
    },

	camera = function(ctx)
		return Camera.follow{
			getTarget = function()
				return ctx.firstEnemy
			end,

			lag = 9,
			offset = {y = -6},

			zoomFrom = 3.0,
			zoomTo = 3.0,
			zoomDur = 1.0,
			zoomDelay = 0.2,
		}
	end
}