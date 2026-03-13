local Camera = require("tools.trailer.camera")
local Actions = require("tools.trailer.actions")
local Constants = require("core.constants")

return {
	map = 13,
	duration = 7.0,
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
			warmup = 11.0,
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

			zoomFrom = 8.0,
			zoomTo = 3.0,
			zoomDur = 1.0,
			zoomDelay = 1.0,
		}
	end
}