local Shared = require("world.effects.shared")
local Theme = require("core.theme")
local Sound = require("systems.sound")
local lg, random = Shared.graphics, Shared.random
local sin, cos, min, max, sqrt, pi = Shared.sin, Shared.cos, Shared.min, Shared.max, Shared.sqrt, Shared.pi

return function(context)
	local record = Shared.family("placePuffs", 330, nil, {'x','y','vx','vy','r','t','life'})
	local Effects = context.Effects
	local function spawnPlacePuff(x, y)
		for i = 1, context.particleCount(10, Theme.effects.intensity.subtle) do
			local a = random() * pi * 2
			local sp = 110 + random() * 120

			local spawnR = 3 + random() * 3

			local p = Shared.acquire(record.pool)

			p.x = x + cos(a) * spawnR
			p.y = y + sin(a) * spawnR

			p.vx = cos(a) * sp
			p.vy = sin(a) * sp * 0.9 - 4

			p.r = random(2, 4)
			p.t = 0
			p.life = 0.45 + random() * 0.2

			record.list[#record.list + 1] = p
		end
	end

	-- A meteor throws a wider, heavier cloud than tower placement while sharing
	-- the same subdued dust rendering so the impact does not obscure enemies.
	local function spawnMeteorDust(x, y, radius)
		local scale = max(1, (radius or 82) / 82)
		for i = 1, context.particleCount(42, Theme.effects.intensity.strong) do
			local a = random() * pi * 2
			local sp = (135 + random() * 150) * scale
			local spawnR = (8 + random() * 16) * scale
			local p = Shared.acquire(record.pool)

			p.x = x + cos(a) * spawnR
			p.y = y + sin(a) * spawnR
			p.vx = cos(a) * sp
			p.vy = sin(a) * sp * 0.72 - 18
			p.r = random(5, 9) * scale
			p.t = 0
			p.life = 0.65 + random() * 0.35

			record.list[#record.list + 1] = p
		end
	end


	local function draw(list)
		for i = 1, #list do
			local p = list[i]
			local t = p.t / p.life

			local alpha = (1 - t)
			local r = p.r * (1 + t * 0.6)

			lg.setColor(0.8, 0.75, 0.7, alpha * 0.5)
			lg.circle("fill", p.x, p.y, r)
		end
	end


	function record.update(o, dt, _, _, drag92) Shared.drag(o, dt, drag92) end
	record.spawn = spawnPlacePuff
	record.draw = draw
	record.ids = {}
	Effects.spawnPlacePuff = spawnPlacePuff
	Effects.spawnMeteorDust = spawnMeteorDust
	return record
end
