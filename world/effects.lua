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
	tinsert(Effects.zaps, {
		x = x,
		y = y,
		chain = chain,
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
		local chain = z.chain

		if not chain then
			goto continueZap
		end

		local px, py = z.x, z.y
		local count = #chain

		local u = z.t / z.life
		local a = 1.0 - 0.3 * u

		for i = 1, count do
			local seg = chain[i]
			local e = seg.to

			if e and e.hp and e.hp > 0 then
				local x, y = e.x, e.y

				local t = (i - 1) / max(1, count)
				local jumpA = 1.0 - 0.1 * (i - 1)
				local radius = 2 * (1 - t) + 1

				local jx = jitter(halfJitter)
				local jy = jitter(halfJitter)

				lg.setColor(0.6, 0.9, 1.0, 0.6 * a * jumpA)
				lg.circle("fill", x + jx, y + jy, radius)

				local w = (2 * (1 - t) + 1) * (0.8 - 0.4 * u)
				lg.setLineWidth(w)

				local jx1 = jitter(zapJitter)
				local jy1 = jitter(zapJitter)
				local jx2 = jitter(zapJitter)
				local jy2 = jitter(zapJitter)

				lg.setColor(0.6, 0.9, 1.0, a * jumpA)
				lg.line(px + jx1, py + jy1, x + jx2, y + jy2)

				lg.setColor(0.9, 0.9, 1.0, 0.35 * a * jumpA)
				lg.line(px + jx2, py + jy2, x + jx1, y + jy1)

				px, py = x, y
			end
		end

		::continueZap::
	end

	lg.setLineWidth(1)
end

function Effects.clear()
	for i = #Effects.splashes, 1, -1 do Effects.splashes[i] = nil end
	for i = #Effects.explosions, 1, -1 do Effects.explosions[i] = nil end
	for i = #Effects.zaps, 1, -1 do Effects.zaps[i] = nil end
end

return Effects