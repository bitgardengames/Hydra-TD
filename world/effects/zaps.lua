local Shared = require("world.effects.shared")
local Sound = require("systems.sound")
local lg, random = Shared.graphics, Shared.random
local min, max, sqrt, sin, cos, pi = Shared.min, Shared.max, Shared.sqrt, Shared.sin, Shared.cos, Shared.pi
local halfJitter = 2
local function jitter(amount) return (random() * 2 - 1) * amount end
local function zapFactory() return {segs = {}} end

return function(context)
	local record = Shared.family("zaps", 12, zapFactory, {})
	local Effects = context.Effects
	local segPool = {}
	local function acquireZapSeg()
		local seg = segPool[#segPool]

		if seg then
			segPool[#segPool] = nil
			return seg
		end

		return {}
	end

	local function releaseZapSeg(seg)
		seg.x1 = nil
		seg.y1 = nil
		seg.x2 = nil
		seg.y2 = nil

		segPool[#segPool + 1] = seg
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

		record.pool[#record.pool + 1] = z
	end

	-- Zaps
	local function spawnZapEffect(x, y, chain)
		local z = Shared.acquire(record.pool, zapFactory)
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

		record.list[#record.list + 1] = z

		Sound.play("shock")
	end


	local function draw(list)
		-- Zaps
		for i = 1, #list do
			local z = list[i]
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
					local radius = 2.5 * (1 - t) + 1
					lg.setColor(0.7, 0.95, 1.0, 0.7 * a * jumpA)
					lg.circle("fill", x2 + jx, y2 + jy, radius)

					local w = (3 * (1 - t) + 1) * (0.9 - 0.35 * u)

					-- Soft glow
					lg.setLineWidth(w * 2.4)
					lg.setColor(0.5, 0.85, 1.0, 0.18 * a * jumpA)
					lg.line(x1, y1, x2, y2)

					-- Main lightning strand
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

					-- Additional beam
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

					-- Core line
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

					-- Tiny fork
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
		lg.setLineWidth(1)
	end

	record.spawn = spawnZapEffect
	record.draw = draw
	record.release = releaseZap
	record.reset = releaseZap
	record.ids = {zap = function(fx) return spawnZapEffect(fx.x, fx.y, fx.chain) end}
	Effects.spawnZapEffect = spawnZapEffect
	return record
end
