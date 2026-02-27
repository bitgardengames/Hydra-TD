local Camera = require("tools.trailer.camera")
local Actions = require("tools.trailer.actions")
local Constants = require("core.constants")

return {
    map = 5,
    duration = 21.0,

    scene = {
        towers = {
            {kind = "lancer", gx = 17, gy = 6},
            {kind = "lancer", gx = 20, gy = 5},
            {kind = "poison", gx = 21, gy = 5},
            {kind = "shock", gx = 15, gy = 5},
            {kind = "cannon", gx = 16, gy = 6},
        },

        wave = {
			index = 10,
            start = true,
            warmup = 34,
        },
    },

    actions = {
        {t = 0, fn = Actions.upgradeTowerAt(19, 10, 2)},
        {t = 0, fn = Actions.upgradeTowerAt(19, 11, 1)},
        {t = 0, fn = Actions.upgradeTowerAt(18, 13, 1)},
        {t = 0, fn = Actions.upgradeTowerAt(20, 11, 1)},
    },

	camera = function(ctx)
		local driftStart = 8.0
		local driftDur = 2.6

		local grassGX = 14
		local grassGY = 8

		local grassWX = (grassGX + 0.5) * Constants.TILE - 43
		local grassWY = (grassGY + 0.5) * Constants.TILE

		local bossLockX = nil
		local bossLockY = nil

		local function smoothstep(t)
			return t * t * (3 - 2 * t)
		end

		return Camera.follow{
			getTarget = function()
				-- Before drift
				if ctx.time < driftStart and ctx.firstEnemy then
					return ctx.firstEnemy
				end

				-- Capture boss position once at drift start
				if not bossLockX and ctx.firstEnemy then
					bossLockX = ctx.firstEnemy.x
					bossLockY = ctx.firstEnemy.y
				end

				-- If no boss ever existed, just return grass
				if not bossLockX then
					return {x = grassWX, y = grassWY}
				end

				-- Blend progress
				local t = (ctx.time - driftStart) / driftDur
				t = math.max(0, math.min(1, t))
				t = smoothstep(t)

				-- Interpolated world position
				local x = bossLockX + (grassWX - bossLockX) * t
				local y = bossLockY + (grassWY - bossLockY) * t

				return {x = x, y = y}
			end,

			trackFrom = 0,
			acquireDur = 0,

			lag = 6,
			offset = {y = -4},

			zoomFrom = 3.0,
			zoomTo = 6.0,
			zoomDelay = 0,
			zoomDur = 10.0,
		}
	end,

	logo = {
		t = 10.6, -- when it begins
		dur = 16, -- how long it remains active
	},

	text = {
		{t = 0.8, text = "SURVIVE", dur = 3, fadeIn = 0.25, fadeOut = 0.4},
		{t = 12, text = "Wishlist on Steam", dur = 16, fadeIn = 0.35, fadeOut = 0.45, smallText = true},
	}
}