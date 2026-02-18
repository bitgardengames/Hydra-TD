local Constants = require("core.constants")
local Camera = require("core.camera")

local CineCam = {}

local min = math.min
local exp = math.exp

local function smoothstep(t)
	return t * t * (3 - 2 * t)
end

function CineCam.follow(opts)
	local lag = opts.lag or 8

	local ox = (opts.offset and opts.offset.x) or 0
	local oy = (opts.offset and opts.offset.y) or 0

	local fx = opts.startAt and opts.startAt.x
	local fy = opts.startAt and opts.startAt.y

	local ax, ay -- acquire start
	local ease = opts.zoomEase or smoothstep

	return {
		update = function(time)
			-- Resolve target
			local target = opts.getTarget and opts.getTarget() or opts.target

			if not target or target.dead then
				return
			end

			local tx = target.x + ox
			local ty = target.y + oy

			local trackFrom = opts.trackFrom or 0
			local acquireDur = opts.acquireDur or 0

			local inHold = opts.startAt and time < trackFrom
			local inAcquire = acquireDur > 0 and time >= trackFrom and time < trackFrom + acquireDur
			local inFollow = time >= trackFrom + acquireDur

			-- Hold
			if inHold then
				fx = opts.startAt.x
				fy = opts.startAt.y
				Camera.centerOn(fx, fy, opts.zoomFrom or opts.zoom)

				return
			end

			-- Acquire
			if inAcquire then
				if not ax then
					ax, ay = fx, fy
				end

				local p = (time - trackFrom) / acquireDur
				p = ease(min(1, p))

				fx = ax + (tx - ax) * p
				fy = ay + (ty - ay) * p
			-- Follow
			else
				if not fx then
					fx = tx
					fy = ty
				end

				local k = 1 - exp(-lag * love.timer.getDelta())

				fx = fx + (tx - fx) * k
				fy = fy + (ty - fy) * k
			end

			-- Zoom
			local z = opts.zoom

			if opts.zoomFrom and opts.zoomTo and opts.zoomDur then
				local delay = opts.zoomDelay or 0

				if time <= delay then
					z = opts.zoomFrom
				else
					local t = (time - delay) / opts.zoomDur

					t = ease(min(1, t))
					z = opts.zoomFrom + (opts.zoomTo - opts.zoomFrom) * t
				end
			end

			Camera.centerOn(fx, fy, z)
		end
	}
end

function CineCam.pan(opts)
	-- opts.from = { x, y, zoom }
	-- opts.to   = { x, y, zoom }

	return {
		update = function(t)
			local t = min(1, t / opts.duration)
			local p = smoothstep(t)

			local cx = opts.from.x + (opts.to.x - opts.from.x) * p
			local cy = opts.from.y + (opts.to.y - opts.from.y) * p
			local z = opts.from.zoom + (opts.to.zoom - opts.from.zoom) * p

			Camera.centerOn(cx, cy, z)
		end
	}
end

return CineCam