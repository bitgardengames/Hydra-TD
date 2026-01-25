local Camera  = require("tools.trailer.camera")
local Actions = require("tools.trailer.actions")
local Constants = require("core.constants")

local mapCX = Constants.GRID_W * Constants.TILE * 0.5
local mapCY = Constants.GRID_H * Constants.TILE * 0.5

return {
	map = 2,
	duration = 9.0,
	next = "shot_02",

	scene = {
		towers = {
			{kind = "lancer", gx = 17, gy = 6},
			{kind = "lancer", gx = 18, gy = 4},
		},

		wave = {
			start = true,
			warmup = 3.0,
		},
	},

	--[[camera = Camera.pan({
		duration = 6.0,
		from = {x = mapCX, y = mapCY, zoom = 1.28},
		to = {x = mapCX, y = mapCY, zoom = 1.28}
	}),]]

	camera = function(ctx)
		return Camera.follow{
			getTarget = function()
				return ctx.firstEnemy
			end,

			lag = 9,
			offset = {y = -6},

			-- Stay locked on the grunt the entire shot
			-- No handoff, no release

			-- Slow, subtle breathing out
			zoomFrom = 8.0,
			zoomTo   = 3.6,   -- IMPORTANT: do NOT go all the way to 1.28 here
			zoomDur  = 2.0,   -- entire shot lifespan
			zoomDelay = 1.5,  -- hold… let the moment land
		}
	end
}