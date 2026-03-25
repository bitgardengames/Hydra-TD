local Constants = require("core.constants")
local State = require("core.state")
local Theme = require("core.theme")

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
	for gx in pairs(map.blocked) do
		map.blocked[gx] = nil
	end

	map.water = {}
end

local function isWaterTile(gx, gy)
	local water = map.water

	if not water then
		return false
	end

	for i = 1, #water do
		local blob = water[i]
		local bx, by, r = blob[1], blob[2], blob[3]

		local dx = gx - bx
		local dy = gy - by

		if dx * dx + dy * dy <= r * r then
			return true
		end
	end

	return false
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

						col[gy] = true
					end
				end
			end
		end
	end

	local count = 0

	for _, col in pairs(covered) do
		for _ in pairs(col) do
			count = count + 1
		end
	end

	return count
end

local function loadPath(points)
	map.path = {}
	map.isPath = {}
	map.pathWorld = {}

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
		map.pathDist[i] = totalDist
	end

	map.totalWorldLength = totalDist

	local coverageTiles = computeCoverageIndex(map.path, canPlaceAt)
	local coverageIndex = coverageTiles / pathLength
	local raw = coverageIndex / REF_COVERAGE_INDEX

	map.coverageMult = max(0.90, min(1.10, raw))

	State.mapCoverageMult = map.coverageMult
end

local function buildPath(mapDef)
	currentMap = mapDef

	map.water = mapDef.water or {}
	--map.terrain = mapDef.terrain or {}

	loadPath(mapDef.path)

	map.palette = Theme.terrain
end

local function getPalette()
	return map.palette
end

function sampleAtDist(dist)
	local pathWorld = map.pathWorld
	local pathDist = map.pathDist
	local total = map.totalWorldLength

	if not pathDist then
		return 0, 0, 1
	end

	local n = #pathDist

	if n == 0 then
		return 0, 0, 1
	end

	if dist <= 0 then
		local p = pathWorld[1]
		return p[1], p[2], 1
	end

	if dist >= total then
		local p = pathWorld[n]
		return p[1], p[2], n - 1
	end

	local seg = 1

	if seg < 1 then
		seg = 1
	elseif seg > n - 1 then
		seg = n - 1
	end

	while seg > 1 and pathDist[seg] > dist do
		seg = seg - 1
	end

	-- Advance segment only if necessary
	local nextDist = pathDist[seg + 1]

	while seg < n - 1 and nextDist <= dist do
		seg = seg + 1
		nextDist = pathDist[seg + 1]
	end

	local ax, ay = pathWorld[seg][1], pathWorld[seg][2]
	local bx, by = pathWorld[seg + 1][1], pathWorld[seg + 1][2]

	local segStart = pathDist[seg]
	local segEnd = nextDist

	local denom = segEnd - segStart

	local t = 0

	if denom > 0 then
		t = (dist - segStart) / denom
	end

	return ax + (bx - ax) * t, ay + (by - ay) * t, seg
end

local function sampleDirAtDist(dist, hintSeg)
	local x1, y1, seg = sampleAtDist(dist, hintSeg)
	local x2, y2 = sampleAtDist(dist + 8, seg) -- 8px lookahead for direction

	local dx = x2 - x1
	local dy = y2 - y1
	local d2 = dx * dx + dy * dy

	if d2 <= 0.000001 then
		return 1, 0, seg
	end

	local inv = 1 / sqrt(d2)

	return dx * inv, dy * inv, seg
end

return {
	map = map,
	makeKey = makeKey,
	buildPath = buildPath,
	getPalette = getPalette,
	canPlaceAt = canPlaceAt,
	gridToCenter = gridToCenter,
	setBlocked = setBlocked,
	isBlocked = isBlocked,
	clearBlocked = clearBlocked,
	sampleAtDist = sampleAtDist,
	sampleDirAtDist = sampleDirAtDist,
}