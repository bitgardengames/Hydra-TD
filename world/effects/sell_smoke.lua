local Shared = require("world.effects.shared")
local Theme = require("core.theme")

local lg, random = Shared.graphics, Shared.random
local sin, pi = Shared.sin, Shared.pi

return function(context)
	local record = Shared.family("sellSmoke", 48, nil,
		{'x','y','vx','vy','r','t','life','phase'})
	local Effects = context.Effects

	local function spawnSellSmoke(x, y)
		for i = 1, context.particleCount(8, Theme.effects.intensity.subtle) do
			local p = Shared.acquire(record.pool)
			local side = random() * 2 - 1

			p.x = x + side * random(3, 12)
			p.y = y + random(-5, 7)
			p.vx = side * random(7, 20)
			p.vy = -random(24, 48)
			p.r = random(4, 7)
			p.t = 0
			p.life = 0.42 + random() * 0.22
			p.phase = random() * pi * 2

			record.list[#record.list + 1] = p
		end
	end

	function record.update(p, dt, frameExponent)
		p.x = p.x + p.vx * dt
		p.y = p.y + p.vy * dt
		p.vx = p.vx * (0.97 ^ frameExponent)
		p.vy = p.vy * (0.94 ^ frameExponent)
	end

	local function draw(list)
		for i = 1, #list do
			local p = list[i]
			local progress = p.t / p.life
			local fade = (1 - progress) * (1 - progress)
			local radius = p.r * (1 + progress * 0.85)
			local drift = sin(progress * pi * 2 + p.phase) * 3

			lg.setColor(0.72, 0.70, 0.68, fade * 0.42)
			lg.circle("fill", p.x + drift, p.y, radius)
			lg.setColor(0.90, 0.88, 0.84, fade * 0.22)
			lg.circle("fill", p.x + drift - radius * 0.2, p.y - radius * 0.2, radius * 0.62)
		end
	end

	record.spawn = spawnSellSmoke
	record.draw = draw
	record.ids = {}
	Effects.spawnSellSmoke = spawnSellSmoke
	return record
end
