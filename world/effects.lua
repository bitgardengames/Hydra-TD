local Sound = require("systems.sound")

local lg = love.graphics
local random = love.math.random
local sin = math.sin
local cos = math.cos
local min = math.min
local max = math.max
local sqrt = math.sqrt
local atan2 = math.atan2
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
Effects.death = {}
Effects.plasmaParticles = {}

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
local deathPool = {}
local plasmaParticlePool = {}

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

local zapSegPool = {}

local function acquireZapSeg()
	local seg = zapSegPool[#zapSegPool]

	if seg then
		zapSegPool[#zapSegPool] = nil
		return seg
	end

	return {}
end

local function releaseZapSeg(seg)
	seg.x1 = nil
	seg.y1 = nil
	seg.x2 = nil
	seg.y2 = nil

	zapSegPool[#zapSegPool + 1] = seg
end

local function clearZapSegs(segs)
	if not segs then
		return
	end

	for i = #segs, 1, -1 do
		local seg = segs[i]
		segs[i] = nil
		releaseZapSeg(seg)
	end
end

local function releaseZap(z)
	clearZapSegs(z.segs)
	z.x = nil
	z.y = nil
	z.t = nil
	z.life = nil

	zapPool[#zapPool + 1] = z
end

-- Zaps
function Effects.spawnZapEffect(x, y, chain)
	local z = acquire(zapPool)
	local segs = z.segs

	if not segs then
		segs = {}
		z.segs = segs
	else
		clearZapSegs(segs)
	end

	if chain then
		for i = 1, #chain do
			local link = chain[i]
			local from = link.from
			local to = link.to

			if to and to.x and to.y then
				local seg = acquireZapSeg()

				--[[if from then
					seg.x1 = from.x
					seg.y1 = from.renderY or from.y
				else
					seg.x1 = x
					seg.y1 = y
				end]]

				if i == 1 then
					-- First segment comes from the provided origin
					seg.x1 = x
					seg.y1 = y
				elseif from then
					-- Chained segments still use enemy positions
					seg.x1 = from.rx or from.x
					seg.y1 = from.renderY or from.ry or from.y
					--seg.y1 = from.renderY or from.ry
				else
					seg.x1 = x
					seg.y1 = y
				end

				seg.x2 = to.rx or to.x
				seg.y2 = to.ry or to.y

				segs[#segs + 1] = seg
			end
		end
	end

	if #segs == 0 then
		local seg = acquireZapSeg()
		seg.x1 = x
		seg.y1 = y
		seg.x2 = x
		seg.y2 = y
		segs[1] = seg
	end

	z.x = x
	z.y = y
	z.t = 0
	z.life = 0.16

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
	for i = 1, 9 do
		local a = random() * pi * 2
		local sp = 100 + random() * 100

		local f = acquire(frostPool)

		f.x = x
		f.y = y
		f.vx = cos(a) * sp
		f.vy = sin(a) * sp
		f.r = random(2,4)
		f.rot = random() * pi
		f.vr = (random() - 0.5) * 8
		f.t = 0
		f.life = 0.22

		Effects.frost[#Effects.frost + 1] = f
	end
end

-- Poison
function Effects.spawnPoisonSplash(x, y)
	for i = 1, 7 do -- was 5
		local a = random() * pi * 2
		local sp = 90 + random() * 90

		local p = acquire(poisonPool)

		p.x = x
		p.y = y
		p.vx = cos(a) * sp
		p.vy = sin(a) * sp
		p.r = random(2, 4)
		p.t = 0
		p.life = 0.24

		Effects.poison[#Effects.poison + 1] = p
	end
end

-- Lancer
function Effects.spawnLancerHit(x, y)
	for i = 1, 6 do
		local a = random() * pi * 2
		local sp = 150 + random() * 110

		local l = acquire(lancerPool)

		l.x = x
		l.y = y
		l.vx = cos(a) * sp
		l.vy = sin(a) * sp
		l.len = random(6, 9)
		l.t = 0
		l.life = 0.14

		Effects.lancer[#Effects.lancer + 1] = l
	end
end

-- Plasma
function Effects.spawnPlasmaHit(x, y, vx, vy)
	for i = 1, 8 do
		local p = acquire(plasmaParticlePool)

		local ang = random() * pi * 2
		--local spd = 70 + random() * 90
		local spd = 80 + random() * 120

		p.x = x
		p.y = y
		p.vx = cos(ang) * spd
		p.vy = sin(ang) * spd

		p.drag = 0.92 + random() * 0.02
		p.r = random(2, 4)

		p.t = 0
		p.life = 0.24

		Effects.plasmaParticles[#Effects.plasmaParticles + 1] = p
	end
end

function Effects.spawnEnemyDeath(x, y, r)
	local d = acquire(deathPool)

	d.x = x
	d.y = y
	d.r = r or 10
	d.t = 0
	d.life = 0.18

	Effects.death[#Effects.death + 1] = d
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
			releaseZap(z)
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

		p.vx = p.vx * (p.drag or 0.94)
		p.vy = p.vy * (p.drag or 0.94)

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

	local plasmaParticles = Effects.plasmaParticles

	for i = #plasmaParticles, 1, -1 do
		local p = plasmaParticles[i]

		p.t = p.t + dt

		p.x = p.x + p.vx * dt
		p.y = p.y + p.vy * dt

		if p.t >= p.life then
			local dead = plasmaParticles[i]

			plasmaParticles[i] = plasmaParticles[#plasmaParticles]
			plasmaParticles[#plasmaParticles] = nil
			release(plasmaParticlePool, dead)
		end
	end

	local death = Effects.death

	for i = #death, 1, -1 do
		local d = death[i]

		d.t = d.t + dt

		if d.t >= d.life then
			swapRemove(death, i)
			release(deathPool, d)
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

				-- Spark (unchanged)
				local radius = 2.5 * (1 - t) + 1
				lg.setColor(0.7, 0.95, 1.0, 0.7 * a * jumpA)
				lg.circle("fill", x2 + jx, y2 + jy, radius)

				local w = (3 * (1 - t) + 1) * (0.9 - 0.35 * u)

				-- Soft glow
				lg.setLineWidth(w * 2.4)
				lg.setColor(0.5, 0.85, 1.0, 0.18 * a * jumpA)
				lg.line(x1, y1, x2, y2)

				-- Main lightning strand (anchored endpoints)
				lg.setLineWidth(w)
				lg.setColor(0.6, 0.9, 1.0, a * jumpA)

				do
					local bends = random(1, 2)
					local px = x1
					local py = y1

					for b = 1, bends do
						local bt = b / (bends + 1)

						local bx = x1 + (x2 - x1) * bt + jitter(10)
						local by = y1 + (y2 - y1) * bt + jitter(10)

						lg.line(px, py, bx, by)

						px = bx
						py = by
					end

					lg.line(px, py, x2, y2)
				end

				-- Additional beam (slightly offset, also anchored)
				lg.setLineWidth(w * 0.65)
				lg.setColor(0.7, 0.95, 1.0, 0.55 * a * jumpA)

				do
					local offset = 2.5
					local ox = jitter(offset)
					local oy = jitter(offset)

					local bends = random(1, 2)
					local px = x1
					local py = y1

					for b = 1, bends do
						local bt = b / (bends + 1)

						local bx = x1 + (x2 - x1) * bt + ox + jitter(6)
						local by = y1 + (y2 - y1) * bt + oy + jitter(6)

						lg.line(px, py, bx, by)

						px = bx
						py = by
					end

					lg.line(px, py, x2, y2)
				end

				-- Core (now jittered, but endpoints still locked)
				lg.setLineWidth(w * 0.4)
				lg.setColor(1, 1, 1, 0.9 * a * jumpA)

				do
					local bends = 1
					local px = x1
					local py = y1

					for b = 1, bends do
						local bt = b / (bends + 1)

						local bx = x1 + (x2 - x1) * bt + jitter(4)
						local by = y1 + (y2 - y1) * bt + jitter(4)

						lg.line(px, py, bx, by)

						px = bx
						py = by
					end

					lg.line(px, py, x2, y2)
				end

				-- Tiny fork (unchanged)
				if random() < 0.45 then
					local bx = (x1 + x2) * 0.5
					local by = (y1 + y2) * 0.5

					local dirx = x2 - x1
					local diry = y2 - y1
					local length = sqrt(dirx * dirx + diry * diry)

					if length > 0 then
						dirx = dirx / length
						diry = diry / length
					end

					local angle = (random() * 0.9 + 0.35) * pi
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

		--lg.setColor(0.55, 0.9, 0.55, alpha)
		--lg.circle("fill", p.x, p.y, r)
		
		lg.setColor(0.35, 0.75, 0.35, alpha)
		lg.circle("fill", p.x, p.y, r)

		-- Inner core (denser, sharper)
		lg.setColor(0.55, 0.9, 0.55, alpha)
		lg.circle("fill", p.x, p.y, r * 0.6)
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

	-- Plasma Particles
	local plasmaParticles = Effects.plasmaParticles

	for i = 1, #plasmaParticles do
		local p = plasmaParticles[i]

		local t = p.t / p.life
		local a = 1 - t

		local r = (p.r or 3) * (1 - t * 0.4)

		-- Outer glow
		lg.setColor(0.8, 0.5, 1.0, a * 0.35)
		lg.circle("fill", p.x, p.y, r * 1.8)

		-- Core
		lg.setColor(0.95, 0.65, 1.0, a)
		lg.circle("fill", p.x, p.y, r)
	end

	-- Enemy death
	local death = Effects.death

	for i = 1, #death do
		local fx = death[i]

		local t = fx.t / fx.life
		local te = 1 - (1 - t) * (1 - t)
		local tf = t * t
		local a = 1 - tf
		local r = fx.r * (1 + te * 1.1)

		-- Fill
		lg.setColor(0.88, 0.83, 0.87, a * 0.22)
		lg.circle("fill", fx.x, fx.y, r)

		-- Ring
		lg.setLineWidth(3 * (1 - t) + 1)
		lg.setColor(0.88, 0.83, 0.87, a * 0.88)
		lg.circle("line", fx.x, fx.y, r)
	end

	lg.setLineWidth(1)
end

function Effects.clear()
	for i = #Effects.splashes, 1, -1 do
		Effects.splashes[i] = nil
	end

	for i = #Effects.explosions, 1, -1 do
		Effects.explosions[i] = nil
	end

	for i = #Effects.zaps, 1, -1 do
		local z = Effects.zaps[i]
		Effects.zaps[i] = nil
		releaseZap(z)
	end

	for i = #Effects.frost, 1, -1 do
		Effects.frost[i] = nil
	end

	for i = #Effects.lancer, 1, -1 do
		Effects.lancer[i] = nil
	end

	for i = #Effects.death, 1, -1 do
		release(deathPool, Effects.death[i])
		Effects.death[i] = nil
	end
end

return Effects