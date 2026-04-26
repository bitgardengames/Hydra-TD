local Constants = require("core.constants")
local State = require("core.state")
local Theme = require("core.theme")
local Biomes = require("world.biomes")

local REF_COVERAGE_INDEX = 1.8
local TILE = Constants.TILE

local min = math.min
local max = math.max
local sqrt = math.sqrt
local floor = math.floor

local map = {
	blocked = {},
	isPath = {},
	path = {},
	pathWorld = {},
	pathSegLen = {},
	samples = {},
	sampleStep = 1, -- pixels (2–4 ideal)
}

local currentMap = nil

local function makeKey(gx, gy)
	return gx .. "," .. gy
end

local function gridToCenter(gx, gy)
	return (gx - 0.5) * TILE, (gy - 0.5) * TILE
end

local function setBlocked(gx, gy)
	local col = map.blocked[gx]

	if not col then
		col = {}
		map.blocked[gx] = col
	end

	col[gy] = true
end

local function isBlocked(gx, gy)
	local col = map.blocked[gx]

	return col and col[gy]
end

local function clearBlocked()
	map.blocked = {}
	map.water = {}
end

local function canPlaceAt(gx, gy)
	if not gx then
		return false
	end

	local path = map.isPath[gx]

	if path and path[gy] then
		return false, "path"
	end

	if isBlocked(gx, gy) then
		return false, "occupied"
	end

	return true
end

local function computeCoverageIndex(path, canPlaceAtFn)
	local covered = {}
	local count = 0

	for i = 1, #path do
		local p = path[i]
		local px = p[1]
		local py = p[2]

		for dx = -1, 1 do
			for dy = -1, 1 do
				if not (dx == 0 and dy == 0) then
					local gx = px + dx
					local gy = py + dy

					if canPlaceAtFn(gx, gy) then
						local col = covered[gx]

						if not col then
							col = {}
							covered[gx] = col
						end

						if not col[gy] then
							col[gy] = true
							count = count + 1
						end
					end
				end
			end
		end
	end

	return count
end

local function loadPath(points)
	map.path = {}
	map.isPath = {}
	map.pathWorld = {}
	map.pathSegLen = {}

	local pathLength = 0 -- measured in tiles

	for i = 1, #points - 1 do
		local ax, ay = points[i][1], points[i][2]
		local bx, by = points[i + 1][1], points[i + 1][2]

		local dx = (bx > ax) and 1 or (bx < ax and -1 or 0)
		local dy = (by > ay) and 1 or (by < ay and -1 or 0)

		local x, y = ax, ay

		-- Insert first point of the segment
		local idx = #map.path + 1
		map.path[idx] = {x, y}

		map.isPath[x] = map.isPath[x] or {}
		map.isPath[x][y] = true

		while x ~= bx or y ~= by do
			x = x + dx
			y = y + dy

			-- Each step is exactly 1 tile
			pathLength = pathLength + 1

			local j = #map.path + 1
			map.path[j] = {x, y}

			map.isPath[x] = map.isPath[x] or {}
			map.isPath[x][y] = true
		end
	end

	-- Build world-space path (visuals, movement, etc.)
	for i = 1, #map.path do
		local p = map.path[i]
		local wx, wy = gridToCenter(p[1], p[2])

		map.pathWorld[i] = {wx, wy}
	end

	-- Store length and pressure normalization
	map.pathLength = pathLength

	map.pathDist = {}

	local totalDist = 0

	map.pathDist[1] = 0

	for i = 2, #map.pathWorld do
		local ax, ay = map.pathWorld[i - 1][1], map.pathWorld[i - 1][2]
		local bx, by = map.pathWorld[i][1], map.pathWorld[i][2]

		local ddx = bx - ax
		local ddy = by - ay
		local dist = sqrt(ddx * ddx + ddy * ddy)

		totalDist = totalDist + dist
		map.pathSegLen[i - 1] = dist
		map.pathDist[i] = totalDist
	end

	map.totalWorldLength = totalDist
	map.lastSecondThreshold = totalDist * 0.90

	local coverageTiles = computeCoverageIndex(map.path, canPlaceAt)
	local coverageIndex = coverageTiles / pathLength
	local raw = coverageIndex / REF_COVERAGE_INDEX

	map.coverageMult = max(0.90, min(1.10, raw))

	State.mapCoverageMult = map.coverageMult
end

local function buildSamples()
	local pathWorld = map.pathWorld
	local samples = {}
	map.samples = samples

	local step = map.sampleStep
	local total = map.totalWorldLength

	local seg = 1
	local segStartDist = 0

	for d = 0, total, step do
		-- Advance segment (NO while loop)
		while true do
			local segLen = map.pathSegLen[seg] or 0

			if d <= segStartDist + segLen or seg >= #pathWorld - 1 then
				break
			end

			segStartDist = segStartDist + segLen
			seg = seg + 1
		end

		local ax, ay = pathWorld[seg][1], pathWorld[seg][2]
		local bx, by = pathWorld[seg + 1][1], pathWorld[seg + 1][2]

		local dx = bx - ax
		local dy = by - ay
		local segLen = map.pathSegLen[seg] or 0

		local t = 0
		if segLen > 0 then
			t = (d - segStartDist) / segLen
		end

		local x = ax + dx * t
		local y = ay + dy * t

		samples[#samples + 1] = {x, y}
	end

	map.sampleCount = #samples
end

local function buildPath(mapDef)
	currentMap = mapDef

	map.water = mapDef.water or {}
	--map.terrain = mapDef.terrain or {}

	loadPath(mapDef.path)
	buildSamples()

	map.biomeId = mapDef.biome or mapDef.palette or "default"
	map.biome = Biomes.resolve(mapDef)
end

local function sampleFast(dist)
	local samples = map.samples
	local step = map.sampleStep

	if not samples then
		return 0, 0
	end

	local sampleCount = map.sampleCount or #samples

	if sampleCount == 0 then
		return 0, 0
	end

	if dist <= 0 then
		local p = samples[1]

		return p[1], p[2]
	end

	local total = map.totalWorldLength

	if dist >= total then
		local p = samples[sampleCount]

		return p[1], p[2]
	end

	local idx = dist / step
	local idxFloor = floor(idx)
	local i = idxFloor + 1

	local a = samples[i]
	local b = samples[i + 1] or a

	local t = idx - idxFloor

	return a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t
end

local function getBiome()
	return map.biome
end

local function getTerrain()
	return map.biome and map.biome.terrain
end

local function getWorld()
	return map.biome and map.biome.world
end

return {
	map = map,
	makeKey = makeKey,
	buildPath = buildPath,
	getBiome = getBiome,
	getTerrain = getTerrain,
	getWorld = getWorld,
	canPlaceAt = canPlaceAt,
	gridToCenter = gridToCenter,
	setBlocked = setBlocked,
	isBlocked = isBlocked,
	clearBlocked = clearBlocked,
	sampleFast = sampleFast,
}
