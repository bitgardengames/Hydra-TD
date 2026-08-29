local Shared = require("world.effects.shared")
local Theme = require("core.theme")
local Sound = require("systems.sound")
local lg, random = Shared.graphics, Shared.random
local sin, cos, min, max, sqrt, pi = Shared.sin, Shared.cos, Shared.min, Shared.max, Shared.sqrt, Shared.pi

return function(context)
	local record = Shared.family("splashes", 32, nil, {'x','y','r','t','life'})
	local Effects = context.Effects
	local function spawnCannonImpact(x, y, r)
		local s = Shared.acquire(record.pool)

		s.x = x
		s.y = y
		s.r = r
		s.t = 0
		s.life = 0.18

		record.list[#record.list + 1] = s

		context.explosions.spawnImpactParticles(x, y)
	end

	local function draw(list)
		-- Cannon splash rings
		for i = 1, #list do
			local s = list[i]
			local t = s.t / s.life

			local ease = t * (2 - t)
			local radius = s.r * ease
			radius = radius + sin(s.t * 40) * (1 - t) * 1.5

			local alpha = (1 - t) * 0.85

			if t < 0.15 then
				alpha = 0.9
			end

			lg.setColor(1, 0.75, 0.45, alpha * 0.25)
			lg.circle("fill", s.x, s.y, radius * 0.92)

			lg.setLineWidth(3 * (1 - t) + 1)
			lg.setColor(1.0, 0.85, 0.55, alpha)
			lg.circle("line", s.x, s.y, radius)

			lg.setLineWidth(2 * ease)
			lg.setColor(1.0, 0.9, 0.7, alpha * 0.2)
			lg.circle("line", s.x, s.y, radius * 0.8)

			if t < 0.1 then
				local flash = 1 - (t / 0.1)

				lg.setColor(1, 1, 1, 0.9 * flash)
				lg.circle("fill", s.x, s.y, radius * 0.45)

				lg.setColor(1, 0.8, 0.6, 0.6 * flash)
				lg.circle("fill", s.x, s.y, radius * 0.75)
			end
		end

		lg.setLineWidth(1)
	end


	record.spawn = spawnCannonImpact
	record.draw = draw
	record.ids = {['cannon_impact'] = function(fx) return spawnCannonImpact(fx.x, fx.y, fx.r) end}
	Effects.spawnCannonImpact = spawnCannonImpact
	return record
end
