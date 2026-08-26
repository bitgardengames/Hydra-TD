local MapPreviewCache = {}

local Maps = require("world.map_defs")
local MapMod = require("world.map")
local Constants = require("core.constants")
local MapRender = require("world.map_render")
local State = require("core.state")
local Trees = require("world.scatter_trees")
local Cacti = require("world.scatter_cactus")
local Rocks = require("world.scatter_rocks")
local Mushrooms = require("world.scatter_mushrooms")

local lg = love.graphics

local mapW = Constants.GRID_W * Constants.TILE
local mapH = Constants.GRID_H * Constants.TILE

-- Previews are keyed by both map and destination size.  A single 16:9 canvas
-- used to be shared by every UI presentation, which meant at least one of the
-- presentations would resample it.  Keeping each native-sized render here is
-- deliberately a memory-for-image-quality tradeoff.
local cache = {}

local function buildPreviewPath(pathWorld, previewW, previewH)
	if not pathWorld or #pathWorld < 2 then
		return nil
	end

	local scaleX = previewW / mapW
	local scaleY = previewH / mapH
	local points = {}
	local totalLength = 0

	for i, worldPoint in ipairs(pathWorld) do
		local x = worldPoint[1] * scaleX
		local y = worldPoint[2] * scaleY
		if i > 1 then
			local previous = points[i - 1]
			local dx, dy = x - previous.x, y - previous.y
			totalLength = totalLength + math.sqrt(dx * dx + dy * dy)
		end
		points[i] = {x = x, y = y, distance = totalLength}
	end

	return {points = points, totalLength = totalLength}
end

local function clearTable(t)
	for k in pairs(t) do
		t[k] = nil
	end
end

local function copyTable(dst, src)
	clearTable(dst)

	for k, v in pairs(src) do
		dst[k] = v
	end

	return dst
end

local function withMapContext(context, previousMap, fn)
	local activeMap = MapMod.map
	copyTable(previousMap, activeMap)
	copyTable(activeMap, context.map)

	local ok, err = pcall(fn)

	copyTable(activeMap, previousMap)

	if not ok then
		error(err)
	end
end

local function build(mapIndex, mapDef, w, h)
	local previousMapIndex = State.worldMapIndex
	local previousMap = {}
	local context = MapMod.createRenderContext(mapDef)
	local canvas = lg.newCanvas(w, h, {msaa = 8})
	local scatter = context.map.biome and context.map.biome.scatter

	-- Hydra TD's world art uses nearest-neighbour filtering.  The preview is
	-- still rendered at native size; this only prevents accidental smoothing if
	-- a caller ever draws the canvas through a transformed parent.
	canvas:setFilter("nearest", "nearest")
	State.worldMapIndex = mapIndex
	withMapContext(context, previousMap, function()
		MapMod.clearBlocked()

		if scatter then
			if scatter.rocks and scatter.rocks.enabled then
				Rocks.generate(scatter.rocks)
			else
				Rocks.clear()
			end

			if scatter.trees and scatter.trees.enabled then
				Trees.generate(scatter.trees)
			else
				Trees.clear()
			end

			if scatter.cactus and scatter.cactus.enabled then
				Cacti.generate(scatter.cactus)
			else
				Cacti.clear()
			end

			if scatter.mushrooms and scatter.mushrooms.enabled then
				Mushrooms.generate()
			else
				Mushrooms.clear()
			end
		else
			Rocks.clear()
			Trees.clear()
			Cacti.clear()
			Mushrooms.clear()
		end

		MapRender.renderFullMapToCanvas(canvas)
	end)

	State.worldMapIndex = previousMapIndex
	return {
		canvas = canvas,
		previewPath = buildPreviewPath(context.map.pathWorld, w, h),
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

function MapPreviewCache.clear()
	for _, sizes in pairs(cache) do
		for _, entry in pairs(sizes) do
			if entry.canvas then entry.canvas:release() end
		end
	end
	cache = {}
end

return MapPreviewCache
