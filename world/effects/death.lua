local Shared = require("world.effects.shared")
local Theme = require("core.theme")
local lg, random = Shared.graphics, Shared.random
local sin, cos, min, max, sqrt, pi = Shared.sin, Shared.cos, Shared.min, Shared.max, Shared.sqrt, Shared.pi

return function(context)
	local record = Shared.family("death", 32, nil, {'x','y','r','t','life'})
	local Effects = context.Effects
	local function spawnEnemyDeath(x, y, r)
		local d = Shared.acquire(record.pool)

		d.x = x
		d.y = y
		d.r = r or 10
		d.t = 0
		d.life = 0.18

		record.list[#record.list + 1] = d
	end



	local function draw(list)
		-- Enemy death
		for i = 1, #list do
			local fx = list[i]

			local t = fx.t / fx.life
			local te = 1 - (1 - t) * (1 - t)
			local tf = t * t
			local a = 1 - tf
			local r = fx.r * (1 + te * 1.1)

			-- Fill
			lg.setColor(0.88, 0.83, 0.87, a * 0.22)
			lg.circle("fill", fx.x, fx.y, r)

			-- Ring
			lg.setLineWidth(3 * (1 - t) + 1)
			lg.setColor(0.88, 0.83, 0.87, a * 0.88)
			lg.circle("line", fx.x, fx.y, r)
		end

		lg.setLineWidth(1)
	end


	record.spawn = spawnEnemyDeath
	record.draw = draw
	record.ids = {}
	Effects.spawnEnemyDeath = spawnEnemyDeath
	return record
end
