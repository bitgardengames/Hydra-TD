local Shared = require("world.effects.shared")
local Theme = require("core.theme")
local lg, random = Shared.graphics, Shared.random
local sin, cos, min, max, sqrt, pi = Shared.sin, Shared.cos, Shared.min, Shared.max, Shared.sqrt, Shared.pi

return function(context)
	local record = Shared.family("frost", 288, nil, {'x','y','vx','vy','r','rot','vr','t','life'})
	local Effects = context.Effects
	local function spawnFrostBurst(x, y)
		for i = 1, context.particleCount(9, Theme.effects.intensity.normal) do
			local a = random() * pi * 2
			local sp = 100 + random() * 100

			local f = Shared.acquire(record.pool)

			f.x = x
			f.y = y
			f.vx = cos(a) * sp
			f.vy = sin(a) * sp
			f.r = random(2,4)
			f.rot = random() * pi
			f.vr = (random() - 0.5) * 8
			f.t = 0
			f.life = 0.22

			record.list[#record.list + 1] = f
		end
	end


	local function draw(list)
		-- Frost shards
		for i = 1, #list do
			local f = list[i]
			local t = f.t / f.life

			local alpha = 1 - t
			local size = f.r * (1 - t * 0.4)

			lg.setColor(0.7, 0.9, 1.0, alpha)

			lg.push()
			lg.translate(f.x, f.y)
			lg.rotate(f.rot)

			lg.rectangle("fill", -size * 0.4, -size * 0.6, size * 0.8, size * 1.2)

			lg.pop()
		end
	end


	function record.update(o, dt, _, drag96)
		Shared.drag(o, dt, drag96); o.rot = o.rot + o.vr * dt
	end
	record.spawn = spawnFrostBurst
	record.draw = draw
	record.ids = {['frost_burst'] = function(fx) return spawnFrostBurst(fx.x, fx.y) end}
	Effects.spawnFrostBurst = spawnFrostBurst
	return record
end
