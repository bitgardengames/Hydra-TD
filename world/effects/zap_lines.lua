local Shared = require("world.effects.shared")
local Theme = require("core.theme")
local lg, random = Shared.graphics, Shared.random
local sin, cos, min, max, sqrt, pi = Shared.sin, Shared.cos, Shared.min, Shared.max, Shared.sqrt, Shared.pi

return function(context)
	local record = Shared.family("zapLines", 32, nil, {'x1','y1','x2','y2','t','life'})
	local Effects = context.Effects
	local function acquireZapLine()
		return Shared.acquire(record.pool)
	end



	local function spawnZapLine(x1, y1, x2, y2)
		local z = acquireZapLine()

		z.x1 = x1
		z.y1 = y1
		z.x2 = x2
		z.y2 = y2

		z.t = 0
		z.life = 0.12

		record.list[#record.list + 1] = z
	end


	local function draw(list)
		for i = 1, #list do
			local z = list[i]

			local u = z.t / z.life
			local a = 1.0 - u

			local x1, y1 = z.x1, z.y1
			local x2, y2 = z.x2, z.y2

			local w = 3 * (0.9 - 0.35 * u)

			-- glow
			lg.setLineWidth(w * 2.2)
			lg.setColor(0.5, 0.85, 1.0, 0.18 * a)
			lg.line(x1, y1, x2, y2)

			-- main bolt
			lg.setLineWidth(w)
			lg.setColor(0.6, 0.9, 1.0, a)

			local mx = (x1 + x2) * 0.5 + (love.math.random() - 0.5) * 8
			local my = (y1 + y2) * 0.5 + (love.math.random() - 0.5) * 8

			lg.line(x1, y1, mx, my)
			lg.line(mx, my, x2, y2)

			-- core
			lg.setLineWidth(w * 0.45)
			lg.setColor(1, 1, 1, 0.9 * a)
			lg.line(x1, y1, x2, y2)

			-- hit spark
			lg.setColor(0.7, 0.95, 1.0, 0.7 * a)
			lg.circle("fill", x2, y2, 2.5)
		end

		lg.setLineWidth(1)
	end


	record.spawn = spawnZapLine
	record.draw = draw
	record.ids = {['zap_line'] = function(fx) return spawnZapLine(fx.x1, fx.y1, fx.x2, fx.y2) end}
	Effects.spawnZapLine = spawnZapLine
	return record
end
