local MapPreviewCache = {}

local Maps = require("world.map_defs")
local MapMod = require("world.map")
local Constants = require("core.constants")
local MapRender = require("world.map_render")
local Camera = require("core.camera")
local State = require("core.state")
local Trees = require("world.scatter_trees")
local Cacti = require("world.scatter_cactus")
local Rocks = require("world.scatter_rocks")
local Mushrooms = require("world.scatter_mushrooms")

local lg = love.graphics

local mapW = Constants.GRID_W * Constants.TILE
local mapH = Constants.GRID_H * Constants.TILE

local cache = {}

local function buildPreviewPath(pathWorld, previewW, previewH, winW, winH, cameraScale)
	if not pathWorld or #pathWorld < 2 then
		return nil
	end

	local centerX, centerY = mapW * 0.5, mapH * 0.5
	local cameraX = centerX - winW / (2 * cameraScale)
	local cameraY = centerY - winH / (2 * cameraScale)
	local scaleX = previewW / winW
	local scaleY = previewH / winH
	local points = {}
	local totalLength = 0

	for i, worldPoint in ipairs(pathWorld) do
		local x = (worldPoint[1] - cameraX) * cameraScale * scaleX
		local y = (worldPoint[2] - cameraY) * cameraScale * scaleY
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

function MapPreviewCache.buildAll(w, h)
	local winW, winH = lg.getDimensions()
	local previousMapIndex = State.worldMapIndex
	local previousMap = {}

	for mapIndex, mapDef in ipairs(Maps) do
		local context = MapMod.createRenderContext(mapDef)
		local canvas = lg.newCanvas(w, h, {msaa = 8})
		local scatter = context.map.biome and context.map.biome.scatter

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

			MapRender.renderGameplayFramedToCanvas(canvas)
		end)

		cache[mapDef.id] = {
			canvas = canvas,
			previewPath = buildPreviewPath(context.map.pathWorld, w, h, winW, winH, Camera.wscale),
		}
	end

	State.worldMapIndex = previousMapIndex
end

function MapPreviewCache.get(mapId)
	return cache[mapId]
end

return MapPreviewCache
