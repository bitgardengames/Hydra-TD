local Shared = require("world.effects.shared")
local Theme = require("core.theme")
local Sound = require("systems.sound")
local lg, random = Shared.graphics, Shared.random
local sin, cos, min, max, sqrt, pi = Shared.sin, Shared.cos, Shared.min, Shared.max, Shared.sqrt, Shared.pi

return function(context)
	local record = Shared.family("presentation", 0, nil, {'kind','t','life','x','y','path','particles'})
	local Effects = context.Effects
	local function presentationEvent(kind, opts)
		opts = opts or {}
		if kind == "boss_spawn" then
			-- The incoming cue traces the route only until the boss is actually on the
			-- field. Its lifetime can overlap the spawn event on fast frames, so stop
			-- drawing the route immediately while allowing the remaining presentation
			-- cues (such as the screen-edge warning) to finish normally.
			for i = 1, #record.list do
				local active = record.list[i]
				if active.kind == "boss_incoming" then active.path = nil end
			end
		end
		local e = Shared.acquire(record.pool)
		e.kind, e.t = kind, 0
		e.life = opts.life or ((kind == "boss_incoming") and 0.8 or 0.45)
		e.x, e.y = opts.x, opts.y
		e.path = opts.path
		e.particles = nil
		if kind == "wave_cleared" or kind == "boss_defeated" then
			e.particles = {}
			local count = context.particleCount(kind == "boss_defeated" and 16 or 10,
				Theme.effects.intensity.normal)
			for i = 1, count do
				e.particles[i] = {angle = random() * pi * 2, distance = random(24, 70)}
			end
		end
		record.list[#record.list + 1] = e
	end

	local function draw(list)
		for i = 1, #list do
			local e = list[i]
			local u = min(1, e.t / e.life)
			local alpha = sin(pi * u)
			if e.kind == "boss_incoming" and e.path and #e.path > 1 then
				local upto = max(2, math.ceil(#e.path * min(1, u * 1.7)))
				lg.setLineWidth(10 + 5 * alpha)
				lg.setColor(Theme.ui.warn[1], Theme.ui.warn[2], Theme.ui.warn[3], 0.28 * alpha)
				for p = 2, upto do lg.line(e.path[p - 1][1], e.path[p - 1][2], e.path[p][1], e.path[p][2]) end
			elseif e.x and e.y then
				local c = (e.kind == "wave_cleared" or e.kind == "boss_defeated") and Theme.ui.good or Theme.ui.warn
				lg.setLineWidth(2 + 2 * (1 - u))
				lg.setColor(c[1], c[2], c[3], 0.75 * (1 - u))
				lg.circle("line", e.x, e.y, 12 + u * 55)
				for _, p in ipairs(e.particles or {}) do
					local d = p.distance * u
					lg.circle("fill", e.x + cos(p.angle) * d, e.y + sin(p.angle) * d, 2)
				end
			end
		end
		lg.setLineWidth(1)
	end


	local function drawOverlay(list)
		for i = 1, #list do
			local e = list[i]
			if e.kind == "boss_incoming" or e.kind == "boss_spawn" then
				local a = sin(pi * min(1, e.t / e.life)) * 0.16
				local w, h = lg.getDimensions()
				lg.setColor(Theme.ui.warn[1], Theme.ui.warn[2], Theme.ui.warn[3], a)
				lg.setLineWidth(18)
				lg.rectangle("line", 9, 9, w - 18, h - 18)
			end
		end
		lg.setLineWidth(1)
	end



	record.spawn = presentationEvent
	record.drawOverlay = drawOverlay
	record.draw = draw
	record.ids = {}
	Effects.presentationEvent = presentationEvent
	return record
end
