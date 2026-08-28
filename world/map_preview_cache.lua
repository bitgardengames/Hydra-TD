local MapPreviewCache = {}

local Constants = require("core.constants")
local Maps = require("world.map_defs")
local MapMod = require("world.map")
local MapRender = require("world.map_render")
local Scatter = require("world.scatter")

local lg = love.graphics

-- Previews are keyed by both map and destination size.  A single 16:9 canvas
-- used to be shared by every UI presentation, which meant at least one of the
-- presentations would resample it.  Keeping each native-sized render here is
-- deliberately a memory-for-image-quality tradeoff.
local cache = {}

-- Fit the authored 16:9 preview into destination bounds and keep the result
-- integral so its canvas can be drawn 1:1 on pixel boundaries. Integer sizes
-- such as 118×66 are necessarily rounded approximations of the exact 16:9
-- ratio, rather than dimensions that should be stretched to fill the bounds.
function MapPreviewCache.fitDimensions(maxW, maxH)
	local scale = math.min(maxW / 16, maxH / 9)
	local w = math.max(1, math.floor(16 * scale + 0.5))
	local h = math.max(1, math.floor(9 * scale + 0.5))
	return w, h
end

local function buildPreviewPath(pathWorld, transform)
	if not pathWorld or #pathWorld < 2 then
		return nil
	end

	-- Apply the same centered viewport transform used to render the preview so
	-- callers that animate along this path remain aligned with the map image.
	local scale = transform.cameraScale * transform.destinationScale
	local points = {}
	local totalLength = 0

	for i, worldPoint in ipairs(pathWorld) do
		local x = transform.offsetX + (worldPoint[1] - transform.cameraX) * scale
		local y = transform.offsetY + (worldPoint[2] - transform.cameraY) * scale
		if i > 1 then
			local previous = points[i - 1]
			local dx, dy = x - previous.x, y - previous.y
			totalLength = totalLength + math.sqrt(dx * dx + dy * dy)
		end
		points[i] = {x = x, y = y, distance = totalLength}
	end

	return {
		points = points,
		totalLength = totalLength,
		tileLength = Constants.TILE * scale,
	}
end

local function build(mapIndex, mapDef, w, h)
	local context = MapMod.createRenderContext(mapDef)
	context.mapIndex = mapIndex
	context.decorations = Scatter.generate(context.map, mapIndex)
	local canvas = lg.newCanvas(w, h, {msaa = 8})
	local previewTransform = MapRender.gameplayPreviewTransform(w, h)

	-- Hydra TD's world art uses nearest-neighbour filtering.  The preview is
	-- still rendered at native size; this only prevents accidental smoothing if
	-- a caller ever draws the canvas through a transformed parent.
	canvas:setFilter("nearest", "nearest")
	MapRender.renderGameplayFramedToCanvas(canvas, context, previewTransform)

	return {
		canvas = canvas,
		previewPath = buildPreviewPath(context.map.pathWorld, previewTransform),
	}
end

function MapPreviewCache.buildAll(w, h)
	w, h = math.max(1, math.floor(w + 0.5)), math.max(1, math.floor(h + 0.5))
	for mapIndex, mapDef in ipairs(Maps) do
		local sizes = cache[mapDef.id] or {}
		cache[mapDef.id] = sizes
		local key = w .. "x" .. h
		if not sizes[key] then sizes[key] = build(mapIndex, mapDef, w, h) end
	end
end

function MapPreviewCache.get(mapId, w, h)
	local sizes = cache[mapId]
	if not w or not h then return nil end

	w, h = math.max(1, math.floor(w + 0.5)), math.max(1, math.floor(h + 0.5))
	local key = w .. "x" .. h
	if sizes and sizes[key] then return sizes[key] end

	for mapIndex, mapDef in ipairs(Maps) do
		if mapDef.id == mapId then
			sizes = sizes or {}
			cache[mapId] = sizes
			sizes[key] = build(mapIndex, mapDef, w, h)
			return sizes[key]
		end
	end
end

function MapPreviewCache.getFitted(mapId, maxW, maxH)
	local w, h = MapPreviewCache.fitDimensions(maxW, maxH)
	return MapPreviewCache.get(mapId, w, h), w, h
end

function MapPreviewCache.clear()
	for _, sizes in pairs(cache) do
		for _, entry in pairs(sizes) do
			if entry.canvas then entry.canvas:release() end
		end
	end
	cache = {}
end

return MapPreviewCache
