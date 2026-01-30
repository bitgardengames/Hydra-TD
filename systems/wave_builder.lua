local WaveDefs = require("systems.wave_defs")

local Builder = {}

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function lerpInt(a, b, t)
	return math.floor(lerp(a, b, t) + 0.5)
end

local function deepCopy(tbl)
	if type(tbl) ~= "table" then
		return tbl
	end

	local copy = {}

	for k, v in pairs(tbl) do
		copy[k] = deepCopy(v)
	end

	return copy
end

local function findAnchors(wave)
	local lower, upper

	for i = #WaveDefs.anchors, 1, -1 do
		if WaveDefs.anchors[i].id <= wave then
			lower = WaveDefs.anchors[i]

			break
		end
	end

	for i = 1, #WaveDefs.anchors do
		if WaveDefs.anchors[i].id >= wave then
			upper = WaveDefs.anchors[i]

			break
		end
	end

	return lower, upper
end

function Builder.build(waveIndex)
	local lower, upper = findAnchors(waveIndex)

	-- Exact anchor
	if not upper or lower.id == upper.id then
		return deepCopy(lower)
	end

	local t = (waveIndex - lower.id) / (upper.id - lower.id)

	return {
		gap = lerp(lower.gap, upper.gap, t),
		enemies = {
			grunt = lerpInt(lower.enemies.grunt, upper.enemies.grunt, t),
			runner = lerpInt(lower.enemies.runner, upper.enemies.runner, t),
			tank = lerpInt(lower.enemies.tank, upper.enemies.tank, t),
			splitter = lerpInt(lower.enemies.splitter, upper.enemies.splitter, t),
		},
		ramps = {
			hp = lerp(lower.ramps.hp, upper.ramps.hp, t),
			speed = lerp(lower.ramps.speed, upper.ramps.speed, t),
		}
	}
end

return Builder