local Sound = require("systems.sound")

local lg = love.graphics
local random = love.math.random
local sin = math.sin
local cos = math.cos
local min = math.min
local max = math.max
local sqrt = math.sqrt
local pi = math.pi

local function swapRemove(list, i)
	local last = #list
	list[i] = list[last]
	list[last] = nil
end

local Effects = {}

Effects.splashes = {}
Effects.explosions = {}
Effects.zaps = {}
Effects.frost = {}
Effects.poison = {}
Effects.lancer = {}

local zapJitter = 4
local halfJitter = zapJitter * 0.5

local function jitter(amount)
	return (random() * 2 - 1) * amount
end

-- Pools
local splashPool = {}
local explosionPool = {}
local zapPool = {}
local frostPool = {}
local poisonPool = {}
local lancerPool = {}

local function acquire(pool)
	local obj = pool[#pool]

	if obj then
		pool[#pool] = nil
		return obj
	end

	return {}
end

local function release(pool, obj)
	for k in pairs(obj) do
		obj[k] = nil
	end

	pool[#pool + 1] = obj
end

-- Zaps
function Effects.spawnZapEffect(x, y, chain)
	local segs = {}

	if chain then
		for i = 1, #chain do
			local seg = chain[i]
			local from = seg.from
			local to = seg.to

			if to and to.x and to.y then
				local x1, y1

				if from then
					x1 = from.x
					y1 = from.renderY or from.y
				else
					x1 = x
					y1 = y
				end

				segs[#segs + 1] = {x1 = x1, y1 = y1, x2 = to.x, y2 = to.y}
			end
		end
	end

	if #segs == 0 then
		segs[1] = {x1 = x, y1 = y, x2 = x, y2 = y}
	end

	local z = acquire(zapPool)

	z.x = x
	z.y = y
	z.segs = segs
	z.t = 0
	z.life = 0.12

	Effects.zaps[#Effects.zaps + 1] = z

	Sound.play("shock")
end

-- Boss Explosion
function Effects.spawnBossDeathExplosion(x, y, radius)
	local ring = acquire(explosionPool)

	ring.x = x
	ring.y = y
	ring.r = radius
	ring.t = 0
	ring.life = 0.25
	ring.type = "ring"

	Effects.explosions[#Effects.explosions + 1] = ring

	local count = 28

	for i = 1, count do
		local a = (i / count) * pi * 2
		local speed = random(120, 220)

		local p = acquire(explosionPool)

		p.x = x
		p.y = y
		p.vx = cos(a) * speed
		p.vy = sin(a) * speed
		p.r = random(2, 4)
		p.t = 0
		p.life = random() * 0.15 + 0.25
		p.type = "particle"

		Effects.explosions[#Effects.explosions + 1] = p
	end
end

-- Cannon Impact
function Effects.spawnCannonImpact(x, y, r)
	local s = acquire(splashPool)

	s.x = x
	s.y = y
	s.r = r
	s.t = 0
	s.life = 0.18

	Effects.splashes[#Effects.splashes + 1] = s

	for i = 1, 10 do
		local a = random() * pi * 2
		local sp = 130 + random() * 120

		local p = acquire(explosionPool)

		p.x = x
		p.y = y
		p.vx = cos(a) * sp
		p.vy = sin(a) * sp
		p.r = random(2, 3)
		p.t = 0
		p.life = 0.18 + random() * 0.2
		p.type = "particle"

		Effects.explosions[#Effects.explosions + 1] = p
	end
end

-- Frost
function Effects.spawnFrostBurst(x, y)
	for i = 1, 6 do
		local a = random() * pi * 2
		local sp = 80 + random() * 80

		local f = acquire(frostPool)

		f.x = x
		f.y = y
		f.vx = cos(a) * sp
		f.vy = sin(a) * sp
		f.r = random(2,3)
		f.rot = random() * pi
		f.vr = (random() - 0.5) * 6
		f.t = 0
		f.life = 0.18

		Effects.frost[#Effects.frost + 1] = f
	end
end

-- Poison
function Effects.spawnPoisonSplash(x, y)
	for i = 1, 5 do
		local a = random() * pi * 2
		local sp = 70 + random() * 70

		local p = acquire(poisonPool)

		p.x = x
		p.y = y
		p.vx = cos(a) * sp
		p.vy = sin(a) * sp
		p.r = random(2,3)
		p.t = 0
		p.life = 0.20

		Effects.poison[#Effects.poison + 1] = p
	end
end

-- Lancer
function Effects.spawnLancerHit(x, y)
	for i = 1, 4 do
		local a = random() * pi * 2
		local sp = 120 + random() * 80

		local l = acquire(lancerPool)

		l.x = x
		l.y = y
		l.vx = cos(a) * sp
		l.vy = sin(a) * sp
		l.len = random(5,7)
		l.t = 0
		l.life = 0.12

		Effects.lancer[#Effects.lancer + 1] = l
	end
end

function Effects.update(dt)
	local splashes = Effects.splashes

	for i = #splashes, 1, -1 do
		local s = splashes[i]
		s.t = s.t + dt

		if s.t >= s.life then
			swapRemove(splashes, i)
			release(splashPool, s)
		end
	end

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
			swapRemove(explosions, i)
			release(explosionPool, e)
		end
	end

	local zaps = Effects.zaps

	for i = #zaps, 1, -1 do
		local z = zaps[i]
		z.t = z.t + dt

		if z.t >= z.life then
			swapRemove(zaps, i)

			if z.segs then
				for j = #z.segs, 1, -1 do
					z.segs[j] = nil
				end
			end

			release(zapPool, z)
		end
	end

	local frost = Effects.frost

	for i = #frost, 1, -1 do
		local f = frost[i]

		f.t = f.t + dt

		f.x = f.x + f.vx * dt
		f.y = f.y + f.vy * dt

		f.vx = f.vx * 0.96
		f.vy = f.vy * 0.96

		f.rot = f.rot + f.vr * dt

		if f.t >= f.life then
			swapRemove(frost, i)
			release(frostPool, f)
		end
	end

	local poison = Effects.poison

	for i = #poison, 1, -1 do
		local p = poison[i]

		p.t = p.t + dt

		p.x = p.x + p.vx * dt
		p.y = p.y + p.vy * dt

		p.vx = p.vx * 0.94
		p.vy = p.vy * 0.94

		if p.t >= p.life then
			swapRemove(poison, i)
			release(poisonPool, p)
		end
	end

	local lancer = Effects.lancer

	for i = #lancer, 1, -1 do
		local l = lancer[i]

		l.t = l.t + dt

		l.x = l.x + l.vx * dt
		l.y = l.y + l.vy * dt

		l.vx = l.vx * 0.92
		l.vy = l.vy * 0.92

		if l.t >= l.life then
			swapRemove(lancer, i)
			release(lancerPool, l)
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

		lg.setLineWidth(2 * ease)
		lg.setColor(1.0, 0.9, 0.7, alpha * 0.2)
		lg.circle("line", s.x, s.y, radius * 0.8)

		if t < 0.1 then
			local flash = 1 - (t / 0.1)

			lg.setColor(1, 1, 1, 0.9 * flash)
			lg.circle("fill", s.x, s.y, radius * 0.45)

			lg.setColor(1, 0.8, 0.6, 0.6 * flash)
			lg.circle("fill", s.x, s.y, radius * 0.75)
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
			local u = min(1, z.t / z.life)
			local a = 1.0 - 0.3 * u
			local d = max(1, count)

			for s = 1, count do
				local seg = segs[s]
				local x1, y1 = seg.x1, seg.y1
				local x2, y2 = seg.x2, seg.y2

				local t = (s - 1) / d
				local jumpA = 1.0 - 0.16 * (s - 1)

				local jx = jitter(halfJitter)
				local jy = jitter(halfJitter)

				-- Spark
				local radius = 2 * (1 - t) + 1
				lg.setColor(0.7, 0.95, 1.0, 0.7 * a * jumpA)
				lg.circle("fill", x2 + jx, y2 + jy, radius)

				local w = (3 * (1 - t) + 1) * (0.8 - 0.4 * u)

				-- Soft glow
				lg.setLineWidth(w * 2.4)
				lg.setColor(0.5, 0.85, 1.0, 0.12 * a * jumpA)
				lg.line(x1, y1, x2, y2)

				-- main lightning strand
				local jx1 = jitter(zapJitter)
				local jy1 = jitter(zapJitter)
				local jx2 = jitter(zapJitter)
				local jy2 = jitter(zapJitter)

				lg.setLineWidth(w)
				lg.setColor(0.6, 0.9, 1.0, a * jumpA)

				local mx = (x1 + x2) * 0.5 + jitter(8)
				local my = (y1 + y2) * 0.5 + jitter(8)

				lg.line(x1 + jx1, y1 + jy1, mx, my)
				lg.line(mx, my, x2 + jx2, y2 + jy2)

				-- Core
				lg.setLineWidth(w * 0.4)
				lg.setColor(1, 1, 1, 0.9 * a * jumpA)
				lg.line(x1, y1, x2, y2)

				-- Tiny fork
				if random() < 0.65 then
					local bx = (x1 + x2) * 0.5
					local by = (y1 + y2) * 0.5

					local dirx = x2 - x1
					local diry = y2 - y1
					local length = sqrt(dirx * dirx + diry * diry)

					if length > 0 then
						dirx = dirx / length
						diry = diry / length
					end

					-- Rotate direction by random angle
					local angle = (random() * 0.9 + 0.35) * pi -- ~20°–160°
					local sign = random() < 0.5 and -1 or 1

					local cosA = cos(angle * sign)
					local sinA = sin(angle * sign)

					local rx = dirx * cosA - diry * sinA
					local ry = dirx * sinA + diry * cosA

					local forkLen = 6 + random() * 10

					lg.setLineWidth(w * 0.7)
					lg.setColor(0.7, 0.95, 1.0, 0.45 * a * jumpA)

					lg.line(bx, by, bx + rx * forkLen + jitter(3), by + ry * forkLen + jitter(3))
				end
			end

			lg.setLineWidth(1)
		end
	end

	-- Frost shards
	local frost = Effects.frost

	for i = 1, #frost do
		local f = frost[i]
		local t = f.t / f.life

		local alpha = 1 - t
		local size = f.r * (1 - t * 0.4)

		lg.setColor(0.7, 0.9, 1.0, alpha)

		lg.push()
		lg.translate(f.x, f.y)
		lg.rotate(f.rot)

		lg.rectangle("fill", -size * 0.4, -size * 0.6, size * 0.8, size * 1.2)

		lg.pop()
	end

	-- Poison splash
	local poison = Effects.poison

	for i = 1, #poison do
		local p = poison[i]
		local t = p.t / p.life

		local alpha = 1 - t
		local r = p.r * (1 - t * 0.3)

		lg.setColor(0.55, 0.9, 0.55, alpha)
		lg.circle("fill", p.x, p.y, r)
	end

	-- Lancer hit
	local lancer = Effects.lancer

	for i = 1, #lancer do
		local l = lancer[i]

		local t = l.t / l.life
		local a = 1 - t

		lg.setColor(1, 1, 1, a)

		lg.line(l.x, l.y, l.x - l.vx * 0.02, l.y - l.vy * 0.02)
	end
end

function Effects.clear()
	for i = #Effects.splashes, 1, -1 do
		Effects.splashes[i] = nil
	end

	for i = #Effects.explosions, 1, -1 do
		Effects.explosions[i] = nil
	end

	for i = #Effects.zaps, 1, -1 do
		Effects.zaps[i] = nil
	end

	for i = #Effects.frost, 1, -1 do
		Effects.frost[i] = nil
	end

	for i = #Effects.lancer, 1, -1 do
		Effects.lancer[i] = nil
	end
end

return Effects