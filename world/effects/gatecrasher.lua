local Shared = require("world.effects.shared")
local lg = Shared.graphics
local max = Shared.max

return function(context)
	local record = Shared.family("gatecrasher", 24, nil, {"x1", "y1", "x2", "y2", "radius", "t", "life"})
	local Effects = context.Effects

	local function spawnGatecrasherLunge(x1, y1, x2, y2, radius)
		local trail = Shared.acquire(record.pool)
		trail.x1, trail.y1, trail.x2, trail.y2 = x1, y1, x2, y2
		trail.radius, trail.t, trail.life = radius or 18, 0, 0.32
		record.list[#record.list + 1] = trail
	end

	function record.draw(list)
		for i = 1, #list do
			local trail = list[i]
			local fade = max(0, 1 - trail.t / trail.life)
			lg.setColor(1, 0.46, 0.14, fade * 0.7)
			lg.setLineWidth(3 + fade * 5)
			lg.line(trail.x1, trail.y1, trail.x2, trail.y2)
			lg.setColor(1, 0.78, 0.28, fade)
			lg.setLineWidth(2 + fade * 2)
			lg.circle("line", trail.x2, trail.y2, trail.radius * (1.45 - fade * 0.45))
		end
	end

	record.ids = {gatecrasher_lunge = function(fx)
		spawnGatecrasherLunge(fx.x1, fx.y1, fx.x2, fx.y2, fx.radius)
	end}
	Effects.spawnGatecrasherLunge = spawnGatecrasherLunge
	return record
end
