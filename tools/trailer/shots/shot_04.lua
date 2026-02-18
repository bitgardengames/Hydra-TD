local Camera = require("tools.trailer.camera")
local Actions = require("tools.trailer.actions")
local Constants = require("core.constants")

local mapCX = Constants.GRID_W * Constants.TILE * 0.5
local mapCY = Constants.GRID_H * Constants.TILE * 0.5

return {
    map = 7,
    duration = 10.0,
	next = "shot_05",

    scene = {
        towers = {
            {kind = "slow",   gx = 11, gy = 7},
            {kind = "slow",   gx = 17, gy = 5},
            {kind = "lancer", gx = 12, gy = 7},
            {kind = "lancer", gx = 12, gy = 9},
            {kind = "poison", gx = 14, gy = 7},
            {kind = "shock", gx = 16, gy = 7},
            {kind = "cannon", gx = 12, gy = 6},
        },

        wave = {
			index = 10,
            start = true,
            warmup = 8,
        },
    },

    actions = {
        {t = 0, fn = Actions.upgradeTowerAt(12, 7, 1)},
        {t = 0, fn = Actions.upgradeTowerAt(12, 9, 1)},
        {t = 0, fn = Actions.upgradeTowerAt(14, 8, 2)},
        {t = 0, fn = Actions.upgradeTowerAt(12, 6, 2)},
        {t = 0, fn = Actions.upgradeTowerAt(16, 7, 1)},
        {t = 0, fn = Actions.upgradeTowerAt(14, 7, 1)},
    },

	camera = function(ctx)
		return Camera.follow{
			getTarget = function()
				return ctx.firstEnemy
			end,

			-- Track immediately
			trackFrom = 0,
			acquireDur = 0,

			lag = 7,
			offset = {y = -6},

			zoomFrom = 3.4,
			zoomTo   = 8.0,
			zoomDelay = 0,
			zoomDur  = 10.0,
		}
	end,

	text = {
		{t = 0.8, text = "SURVIVE", dur = 3, fadeIn = 0.25, fadeOut = 0.4},
	}
}