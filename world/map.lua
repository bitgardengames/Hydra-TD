local Constants = require("core.constants")
local State = require("core.state")

local REF_COVERAGE_INDEX = 1.8

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
	return (gx - 0.5) * Constants.TILE, (gy - 0.5) * Constants.TILE
end

local function canPlaceAt(gx, gy)
	if not gx then
		return false, "outside"

	end
	if map.isPath[makeKey(gx, gy)] then
		return false, "path"
	end

	if map.blocked[makeKey(gx, gy)] then
		return false, "occupied"
	end

	return true
end

local function clearBlocked()
	map.blocked = {}
end

local function computeCoverageIndex(path, canPlaceAt)
	local covered = {}

	for _, p in ipairs(path) do
		for dx = -1, 1 do
			for dy = -1, 1 do
				if not (dx == 0 and dy == 0) then
					local gx = p[1] + dx
					local gy = p[2] + dy

					if canPlaceAt(gx, gy) then
						covered[gx .. "," .. gy] = true
					end
				end
			end
		end
	end

	local count = 0

	for _ in pairs(covered) do
		count = count + 1
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
		table.insert(map.path, {x, y})
		map.isPath[makeKey(x, y)] = true

		while x ~= bx or y ~= by do
			x = x + dx
			y = y + dy

			-- Each step is exactly 1 tile
			pathLength = pathLength + 1

			table.insert(map.path, {x, y})
			map.isPath[makeKey(x, y)] = true
		end
	end

	-- Build world-space path (visuals, movement, etc.)
	for i, p in ipairs(map.path) do
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

		local dx = bx - ax
		local dy = by - ay
		local dist = math.sqrt(dx * dx + dy * dy)

		totalDist = totalDist + dist
		map.pathDist[i] = totalDist
	end

	map.totalWorldLength = totalDist

	local coverageTiles = computeCoverageIndex(map.path, canPlaceAt)
	local coverageIndex = coverageTiles / pathLength
	local raw = coverageIndex / REF_COVERAGE_INDEX

	map.coverageMult = math.max(0.90, math.min(1.10, raw))

	State.mapCoverageMult = map.coverageMult
end

local function buildPath(mapDef)
    currentMap = mapDef
    loadPath(mapDef.path)
end

local function sampleAtDist(dist, hintSeg)
	-- Clamp
	local pathWorld = map.pathWorld
	local pathDist  = map.pathDist
	local n = #pathDist

	if n == 0 then
		return 0, 0, 1
	end

	if dist <= 0 then
		return pathWorld[1][1], pathWorld[1][2], 1
	end

	local total = map.totalWorldLength or pathDist[n] or 0
	if dist >= total then
		return pathWorld[n][1], pathWorld[n][2], n - 1
	end

	-- Start from hint segment if provided (enemy can cache it)
	local seg = hintSeg or 1
	if seg < 1 then seg = 1 end
	if seg > n - 1 then seg = n - 1 end

	while seg < n - 1 and pathDist[seg + 1] <= dist do
		seg = seg + 1
	end

	local ax, ay = pathWorld[seg][1], pathWorld[seg][2]
	local bx, by = pathWorld[seg + 1][1], pathWorld[seg + 1][2]
	local segStart = pathDist[seg]
	local segEnd   = pathDist[seg + 1]

	local t = 0
	local denom = (segEnd - segStart)
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

	local inv = 1 / math.sqrt(d2)
	return dx * inv, dy * inv, seg
end

return {
	map = map,
	makeKey = makeKey,
	buildPath = buildPath,
	canPlaceAt = canPlaceAt,
	gridToCenter = gridToCenter,
	clearBlocked = clearBlocked,
	sampleAtDist = sampleAtDist,
	sampleDirAtDist = sampleDirAtDist,
}