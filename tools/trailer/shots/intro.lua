local Camera = require("tools.trailer.camera")
local Actions = require("tools.trailer.actions")
local Constants = require("core.constants")
local Maps = require("world.map_defs")

-- Insert a straight map
Maps[0] = {
	id = "line",
	nameKey = "map.line",
	path = {
		{4, 8}, {31, 8},
	},
}

return {
	map = 0,
	duration = 7.0,

	scene = {
		towers = {
			{kind = "lancer", gx = 23, gy = 7},
			{kind = "cannon", gx = 24, gy = 9},
			{kind = "shock", gx = 26, gy = 9},
			{kind = "plasma", gx = 23, gy = 9},
		},

		wave = {
			index = 2,
			start = true,
			warmup = 11.0,
		},
	},

    actions = {
		{t = 0, fn = Actions.setMoney(9999)},
		{t = 0, fn = Actions.upgradeTowerAt(25, 9, 1)},
    },

	camera = function(ctx)
		return Camera.follow{
			getTarget = function()
				return ctx.firstEnemy
			end,

			lag = 9,
			offset = {y = -6},

			zoomFrom = 8.0,
			zoomTo = 3.0,
			zoomDur = 1.0,
			zoomDelay = 1.0,
		}
	end
}