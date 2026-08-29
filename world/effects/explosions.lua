local Shared = require("world.effects.shared")
local Theme = require("core.theme")
local Sound = require("systems.sound")
local lg, random = Shared.graphics, Shared.random
local sin, cos, min, max, sqrt, pi = Shared.sin, Shared.cos, Shared.min, Shared.max, Shared.sqrt, Shared.pi

return function(context)
	local record = Shared.family("explosions", 349, nil, {'x','y','vx','vy','r','t','life','type'})
	local Effects = context.Effects
	local function spawnBossDeathExplosion(x, y, radius)
		local ring = Shared.acquire(record.pool)

		ring.x = x
		ring.y = y
		ring.r = radius
		ring.t = 0
		ring.life = 0.25
		ring.type = "ring"

		record.list[#record.list + 1] = ring

		local count = context.particleCount(28, Theme.effects.intensity.critical)

		for i = 1, count do
			local a = (i / count) * pi * 2
			local speed = random(120, 220)

			local p = Shared.acquire(record.pool)

			p.x = x
			p.y = y
			p.vx = cos(a) * speed
			p.vy = sin(a) * speed
			p.r = random(2, 4)
			p.t = 0
			p.life = random() * 0.15 + 0.25
			p.type = "particle"

			record.list[#record.list + 1] = p
		end
	end


	local function spawnImpactParticles(x, y)
		for i = 1, context.particleCount(10, Theme.effects.intensity.strong) do
			local a, speed = random() * pi * 2, 130 + random() * 120
			local p = Shared.acquire(record.pool)
			p.x, p.y, p.vx, p.vy = x, y, cos(a) * speed, sin(a) * speed
			p.r, p.t, p.life, p.type = random(2, 3), 0, 0.18 + random() * 0.2, "particle"
			record.list[#record.list + 1] = p
		end
	end
	local function draw(list)
		-- Explosions
		for i = 1, #list do
			local e = list[i]
			local t = e.t / e.life

			if e.type == "particle" then
				lg.setColor(1, 0.85, 0.55, 1 - t)
				lg.circle("fill", e.x, e.y, e.r * (1 - t * 0.4))
			elseif e.type == "ring" then
				local rr = e.r * (1.2 + t * 1.4)

				lg.setLineWidth(3 * (1 - t) + 1)
				lg.setColor(1, 0.9, 0.6, 0.7 * (1 - t))
				lg.circle("line", e.x, e.y, rr)
			end
		end

		lg.setLineWidth(1)
	end


	function record.update(o, dt, _, drag96)
		if o.type ~= "ring" then Shared.drag(o, dt, drag96) end
	end
	record.spawn = spawnBossDeathExplosion
	record.spawnImpactParticles = spawnImpactParticles
	context.explosions = record
	record.draw = draw
	record.ids = {}
	Effects.spawnBossDeathExplosion = spawnBossDeathExplosion
	return record
end
