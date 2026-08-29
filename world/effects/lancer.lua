local Shared = require("world.effects.shared")
local Theme = require("core.theme")
local lg, random = Shared.graphics, Shared.random
local sin, cos, min, max, sqrt, pi = Shared.sin, Shared.cos, Shared.min, Shared.max, Shared.sqrt, Shared.pi

return function(context)
	local record = Shared.family("lancer", 192, nil, {'x','y','vx','vy','len','t','life'})
	local Effects = context.Effects
	local function spawnLancerHit(x, y)
		for i = 1, context.particleCount(6, Theme.effects.intensity.normal) do
			local a = random() * pi * 2
			local sp = 150 + random() * 110

			local l = Shared.acquire(record.pool)

			l.x = x
			l.y = y
			l.vx = cos(a) * sp
			l.vy = sin(a) * sp
			l.len = random(6, 9)
			l.t = 0
			l.life = 0.14

			record.list[#record.list + 1] = l
		end
	end


	local function draw(list)
		-- Lancer hit
		for i = 1, #list do
			local l = list[i]

			local t = l.t / l.life
			local a = 1 - t

			lg.setColor(1, 1, 1, a)

			lg.line(l.x, l.y, l.x - l.vx * 0.02, l.y - l.vy * 0.02)
		end
		lg.setLineWidth(1)
	end


	function record.update(o, dt, _, _, drag92) Shared.drag(o, dt, drag92) end
	record.spawn = spawnLancerHit
	record.draw = draw
	record.ids = {['lancer_hit'] = function(fx) return spawnLancerHit(fx.x, fx.y) end}
	Effects.spawnLancerHit = spawnLancerHit
	return record
end
