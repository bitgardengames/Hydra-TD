local Shared = require("world.effects.shared")
local Theme = require("core.theme")
local Sound = require("systems.sound")
local lg, random = Shared.graphics, Shared.random
local sin, cos, min, max, sqrt, pi = Shared.sin, Shared.cos, Shared.min, Shared.max, Shared.sqrt, Shared.pi

return function(context)
	local record = Shared.family("towerTransformations", 0, nil, {'x','y','t','life','color','range','cadencePulse','finalTier','particles'})
	local Effects = context.Effects
	local function spawnTowerTransformation(x, y, opts)
		opts = opts or {}
		local e = Shared.acquire(record.pool)
		e.x, e.y = x, y
		e.t = 0
		e.life = opts.finalTier and 0.62 or 0.42
		e.color = opts.color or Theme.ui.good
		e.range = opts.range
		e.cadencePulse = opts.cadencePulse
		e.finalTier = opts.finalTier
		e.particles = {}

		local count = context.particleCount(opts.finalTier and 14 or 8, Theme.effects.intensity.normal)
		for i = 1, count do
			local angle = random() * pi * 2
			e.particles[i] = {
				angle = angle,
				speed = random(22, opts.finalTier and 58 or 42),
				radius = random() * 5,
			}
		end
		record.list[#record.list + 1] = e
	end

	local function draw(list)
		-- Short, low-opacity tower-local upgrade feedback, drawn beneath the louder
		-- combat effects so enemies remain readable.
		for i = 1, #list do
			local e = list[i]
			local u = min(1, e.t / e.life)
			local fade = (1 - u) * 0.78
			local c = e.color

			lg.setLineWidth(1 + (1 - u) * 2)
			lg.setColor(c[1], c[2], c[3], fade)
			lg.circle("line", e.x, e.y, 13 + u * (e.finalTier and 31 or 19))

			if e.range then
				local rangeU = u * (2 - u)
				lg.setLineWidth(1.5)
				lg.setColor(c[1], c[2], c[3], fade * 0.42)
				lg.circle("line", e.x, e.y, e.range * (0.86 + rangeU * 0.14))
			end

			for p = 1, #e.particles do
				local particle = e.particles[p]
				local distance = particle.radius + particle.speed * u
				lg.setColor(c[1], c[2], c[3], fade * 0.72)
				lg.circle("fill", e.x + cos(particle.angle) * distance,
					e.y + sin(particle.angle) * distance, e.finalTier and 2 or 1.5)
			end

			if e.finalTier then
				local spin = e.t * 8
				lg.setLineWidth(2)
				lg.setColor(c[1], c[2], c[3], fade * 0.8)
				for arm = 0, 3 do
					local a = spin + arm * pi * 0.5
					lg.line(e.x + cos(a) * 17, e.y + sin(a) * 17,
						e.x + cos(a) * (25 + 7 * u), e.y + sin(a) * (25 + 7 * u))
				end
			end
		end
		lg.setLineWidth(1)
	end


	record.spawn = spawnTowerTransformation
	record.draw = draw
	record.ids = {}
	Effects.spawnTowerTransformation = spawnTowerTransformation
	return record
end
