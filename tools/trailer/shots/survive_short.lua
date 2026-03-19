local Camera = require("core.camera")
local Actions = require("tools.trailer.actions")
local Constants = require("core.constants")

local target = {x = 0, y = 0}

local function clamp01(x)
	if x < 0 then return 0 end
	if x > 1 then return 1 end

	return x
end

local function smoothstep(t)
	return t * t * (3 - 2 * t)
end

return {
	map = 3,
	duration = 5,

	scene = {
		towers = {
			{kind = "lancer", gx = 18, gy = 13},
			{kind = "lancer", gx = 19, gy = 11},
			{kind = "poison", gx = 19, gy = 10},
			{kind = "shock", gx = 16, gy = 13},
			{kind = "cannon", gx = 20, gy = 11},
		},

		wave = {
			index = 10,
			start = true,
			warmup = 28,
		},
	},

	actions = {
		{t = 0, fn = Actions.upgradeTowerAt(19, 10, 2)},
		{t = 0, fn = Actions.upgradeTowerAt(19, 11, 3)},
		{t = 0, fn = Actions.upgradeTowerAt(18, 13, 2)},
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

		local lag = 9
		local fx, fy = nil, nil

		local zoomFrom = 3.0
		local zoomTo = 3.0
		local zoomDelay = 0
		local zoomDur = 10.0

		local DT = 1 / 60
		local camT = 0

		local function getTarget()
			if camT < driftStart and ctx.firstEnemy then
				target.x = ctx.firstEnemy.x
				target.y = ctx.firstEnemy.y
				return target
			end

			if not bossLockX then
				bossLockX = fx
				bossLockY = fy
			end

			if not bossLockX then
				target.x = grassWX
				target.y = grassWY
				return target
			end

			local t = (camT - driftStart) / driftDur
			t = smoothstep(clamp01(t))

			target.x = bossLockX + (grassWX - bossLockX) * t
			target.y = bossLockY + (grassWY - bossLockY) * t

			return target
		end

		return {
			update = function(_time)
				-- Quantized camera clock (ignores dt spikes in sequence mode)
				camT = camT + DT

				local tgt = getTarget()
				if not tgt then
					return
				end

				local tx = tgt.x
				local ty = tgt.y

				if not fx then
					fx = tx
					fy = ty
				end

				-- Fixed smoothing timestep
				local k = 1 - math.exp(-lag * DT)
				fx = fx + (tx - fx) * k
				fy = fy + (ty - fy) * k

				-- Zoom uses camT too
				local z = zoomFrom
				if camT <= zoomDelay then
					z = zoomFrom
				else
					local t = (camT - zoomDelay) / zoomDur
					t = smoothstep(clamp01(t))
					z = zoomFrom + (zoomTo - zoomFrom) * t
				end

				Camera.centerOn(fx, fy, z)
			end
		}
	end,
}