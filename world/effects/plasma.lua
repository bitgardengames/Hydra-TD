local Shared = require("world.effects.shared")
local Theme = require("core.theme")
local lg, random = Shared.graphics, Shared.random
local sin, cos, min, max, sqrt, pi = Shared.sin, Shared.cos, Shared.min, Shared.max, Shared.sqrt, Shared.pi

return function(context)
	local record = Shared.family("plasmaParticles", 256, nil, {'x','y','vx','vy','drag','r','t','life'})
	local Effects = context.Effects
	local function spawnPlasmaHit(x, y, vx, vy)
		for i = 1, context.particleCount(8, Theme.effects.intensity.normal) do
			local p = Shared.acquire(record.pool)

			local ang = random() * pi * 2
			--local spd = 70 + random() * 90
			local spd = 80 + random() * 120

			p.x = x
			p.y = y
			p.vx = cos(ang) * spd
			p.vy = sin(ang) * spd

			p.drag = 0.92 + random() * 0.02
			p.r = random(2, 4)

			p.t = 0
			p.life = 0.24

			record.list[#record.list + 1] = p
		end
	end


	local function draw(list)
		-- Plasma Particles
		for i = 1, #list do
			local p = list[i]

			local t = p.t / p.life
			local a = 1 - t

			local r = (p.r or 3) * (1 - t * 0.4)

			-- Outer glow
			lg.setColor(0.8, 0.5, 1.0, a * 0.35)
			lg.circle("fill", p.x, p.y, r * 1.8)

			-- Core
			lg.setColor(0.95, 0.65, 1.0, a)
			lg.circle("fill", p.x, p.y, r)
		end
	end


	record.update = Shared.integrate
	record.spawn = spawnPlasmaHit
	record.draw = draw
	record.ids = {['plasma_hit'] = function(fx) return spawnPlasmaHit(fx.x, fx.y, fx.vx or 0, fx.vy or 0) end}
	Effects.spawnPlasmaHit = spawnPlasmaHit
	return record
end
