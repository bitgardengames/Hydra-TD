local Shared = require("world.effects.shared")
local Theme = require("core.theme")
local lg, random = Shared.graphics, Shared.random
local sin, cos, min, max, sqrt, pi = Shared.sin, Shared.cos, Shared.min, Shared.max, Shared.sqrt, Shared.pi

return function(context)
	local record = Shared.family("poison", 224, nil, {'x','y','vx','vy','drag','dragMultiplier','r','t','life'})
	local Effects = context.Effects
	local poisonDragBase = 0.94
	local poisonFixedStepMultiplier = poisonDragBase ^ (Shared.fixedStep * 60)
	local function spawnPoisonSplash(x, y)
		for i = 1, context.particleCount(7, Theme.effects.intensity.normal) do
			local a = random() * pi * 2
			local sp = 90 + random() * 90

			local p = Shared.acquire(record.pool)

			p.x = x
			p.y = y
			p.vx = cos(a) * sp
			p.vy = sin(a) * sp
			p.drag = poisonDragBase
			p.dragMultiplier = poisonFixedStepMultiplier
			p.r = random(2, 4)
			p.t = 0
			p.life = 0.24

			record.list[#record.list + 1] = p
		end
	end


	local function draw(list)
		-- Poison splash
		for i = 1, #list do
			local p = list[i]
			local t = p.t / p.life

			local alpha = 1 - t
			local r = p.r * (1 - t * 0.3)

			lg.setColor(0.35, 0.75, 0.35, alpha)
			lg.circle("fill", p.x, p.y, r)

			-- Inner core
			lg.setColor(0.55, 0.9, 0.55, alpha)
			lg.circle("fill", p.x, p.y, r * 0.6)
		end
	end


	function record.update(o, dt, frameExponent)
		Shared.integrate(o, dt)
		local drag = o.dragMultiplier
		if dt ~= Shared.fixedStep then drag = o.drag ^ frameExponent end
		o.vx, o.vy = o.vx * drag, o.vy * drag
	end
	record.spawn = spawnPoisonSplash
	record.draw = draw
	record.ids = {['poison_splash'] = function(fx) return spawnPoisonSplash(fx.x, fx.y) end}
	Effects.spawnPoisonSplash = spawnPoisonSplash
	return record
end
