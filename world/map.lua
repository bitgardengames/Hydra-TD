local Constants = require("core.constants")

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

local function loadPath(points)
    map.path = {}
    map.isPath = {}

    for i = 1, #points - 1 do
		local ax, ay = points[i][1], points[i][2]
		local bx, by = points[i + 1][1], points[i + 1][2]
        local dx = (bx > ax) and 1 or (bx < ax and -1 or 0)
        local dy = (by > ay) and 1 or (by < ay and -1 or 0)
        local x, y = ax, ay

        table.insert(map.path, {x, y})
        map.isPath[makeKey(x, y)] = true

        while x ~= bx or y ~= by do
            x = x + dx
            y = y + dy
            table.insert(map.path, {x, y})
            map.isPath[makeKey(x, y)] = true
        end
    end

	-- Build world-space path points
	map.pathWorld = {}

	for i, p in ipairs(map.path) do
		local x, y = gridToCenter(p[1], p[2])

		map.pathWorld[i] = {x, y}
	end
end

local function buildPath(mapDef)
    currentMap = mapDef
    loadPath(mapDef.path)
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

return {
	map = map,
	makeKey = makeKey,
	buildPath = buildPath,
	canPlaceAt = canPlaceAt,
	gridToCenter = gridToCenter,
	clearBlocked = clearBlocked,
}