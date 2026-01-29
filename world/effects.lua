local Sound = require("systems.sound")

local lg = love.graphics
local random = love.math.random
local tinsert = table.insert
local tremove = table.remove
local sin = math.sin
local cos = math.cos
local min = math.min
local max = math.max
local pi = math.pi

local Effects = {}

Effects.splashes = {}
Effects.explosions = {}
Effects.zaps = {}

local zapJitter = 2
local halfJitter = zapJitter * 0.5

local function jitter(amount)
	return (random() * 2 - 1) * amount
end

function Effects.spawnZapEffect(x, y, chain)
	-- Snapshot the chain into immutable segments so visuals are not dependent
	-- on enemy hp / removal after damage is applied.
	local segs = {}

	if chain then
		for i = 1, #chain do
			local seg = chain[i]
			local from = seg.from
			local to   = seg.to

			-- "to" must exist to draw a segment
			if to and to.x and to.y then
				-- IMPORTANT: first hop may have from == nil; anchor it to the tower origin.
				local x1, y1
				if from and from.x and from.y then
					x1, y1 = from.x, from.y
				else
					x1, y1 = x, y
				end

				segs[#segs + 1] = {
					x1 = x1,
					y1 = y1,
					x2 = to.x,
					y2 = to.y,
				}
			end
		end
	end

	-- Fallback: if somehow no segments were recorded, at least draw a tiny pop at origin
	if #segs == 0 then
		segs[1] = { x1 = x, y1 = y, x2 = x, y2 = y }
	end

	table.insert(Effects.zaps, {
		x = x,
		y = y,
		segs = segs,
		t = 0,
		life = 0.12,
	})

	Sound.play("shock")
end

function Effects.spawnBossDeathExplosion(x, y, radius)
	local count = 28

	-- Core ring
	tinsert(Effects.explosions, {
		x = x,
		y = y,
		r = radius,
		t = 0,
		life = 0.35,
		type = "ring",
	})

	-- Radial particles
	for i = 1, count do
		local a = (i / count) * pi * 2
		local speed = random(120, 220)

		tinsert(Effects.explosions, {
			x = x,
			y = y,
			vx = cos(a) * speed,
			vy = sin(a) * speed,
			r = random(2, 4),
			t = 0,
			life = random() * 0.15 + 0.35,
			type = "particle",
		})
	end
end

function Effects.update(dt)
	-- Cannon splashes
	local splashes = Effects.splashes

	for i = #splashes, 1, -1 do
		local s = splashes[i]
		s.t = s.t + dt

		if s.t >= s.life then
			tremove(splashes, i)
		end
	end

	-- Explosions
	local explosions = Effects.explosions

	for i = #explosions, 1, -1 do
		local e = explosions[i]
		e.t = e.t + dt

		if e.type == "particle" then
			e.x = e.x + e.vx * dt
			e.y = e.y + e.vy * dt

			e.vx = e.vx * 0.96
			e.vy = e.vy * 0.96
		end

		if e.t >= e.life then
			tremove(explosions, i)
		end
	end

	-- Zaps
	local zaps = Effects.zaps

	for i = #zaps, 1, -1 do
		local z = zaps[i]
		z.t = z.t + dt

		if z.t >= z.life then
			tremove(zaps, i)
		end
	end
end

function Effects.draw()
	-- Cannon splash rings
	local splashes = Effects.splashes
	for i = 1, #splashes do
		local s = splashes[i]
		local t = s.t / s.life

		local ease = t * (2 - t)
		local radius = s.r * ease
		radius = radius + sin(s.t * 40) * (1 - t) * 1.5

		local alpha = (1 - t) * 0.85

		if t < 0.15 then
			alpha = 0.9
		end

		lg.setColor(1, 0.75, 0.45, alpha * 0.25)
		lg.circle("fill", s.x, s.y, radius * 0.92)

		lg.setLineWidth(3 * (1 - t) + 1)
		lg.setColor(1.0, 0.85, 0.55, alpha)
		lg.circle("line", s.x, s.y, radius)

		if t < 0.05 then
			lg.setColor(1, 1, 1, 0.8)
			lg.circle("fill", s.x, s.y, radius * 0.4)
		end
	end

	lg.setLineWidth(1)

	-- Explosions
	local explosions = Effects.explosions

	for i = 1, #explosions do
		local e = explosions[i]
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

	-- Zaps
	local zaps = Effects.zaps

	for i = 1, #zaps do
		local z = zaps[i]
		local segs = z.segs

		if segs then
			local count = #segs
			local u = math.min(1, z.t / z.life)
			local a = 1.0 - 0.3 * u

			for s = 1, count do
				local seg = segs[s]
				local x1, y1 = seg.x1, seg.y1
				local x2, y2 = seg.x2, seg.y2

				local t = (s - 1) / math.max(1, count)
				local jumpA = 1.0 - 0.1 * (s - 1)
				local radius = 2 * (1 - t) + 1

				local jx = jitter(halfJitter)
				local jy = jitter(halfJitter)

				lg.setColor(0.6, 0.9, 1.0, 0.6 * a * jumpA)
				lg.circle("fill", x2 + jx, y2 + jy, radius)

				local w = (2 * (1 - t) + 1) * (0.8 - 0.4 * u)
				lg.setLineWidth(w)

				local jx1 = jitter(zapJitter)
				local jy1 = jitter(zapJitter)
				local jx2 = jitter(zapJitter)
				local jy2 = jitter(zapJitter)

				lg.setColor(0.6, 0.9, 1.0, a * jumpA)
				lg.line(x1 + jx1, y1 + jy1, x2 + jx2, y2 + jy2)

				lg.setColor(0.9, 0.9, 1.0, 0.35 * a * jumpA)
				lg.line(x1 + jx2, y1 + jy2, x2 + jx1, y2 + jy1)
			end

			lg.setLineWidth(1)
		end
	end
end

function Effects.clear()
	for i = #Effects.splashes, 1, -1 do Effects.splashes[i] = nil end
	for i = #Effects.explosions, 1, -1 do Effects.explosions[i] = nil end
	for i = #Effects.zaps, 1, -1 do Effects.zaps[i] = nil end
end

return Effects