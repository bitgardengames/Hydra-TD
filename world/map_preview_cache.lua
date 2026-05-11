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

local function cloneMapData(src)
	local out = {}

	for k, v in pairs(src) do
		out[k] = v
	end

	return out
end

local function withMapContext(context, fn)
	local activeMap = MapMod.map
	local previousMap = cloneMapData(activeMap)

	for k in pairs(activeMap) do
		activeMap[k] = nil
	end

	for k, v in pairs(context.map) do
		activeMap[k] = v
	end

	local ok, err = pcall(fn)

	for k in pairs(activeMap) do
		activeMap[k] = nil
	end

	for k, v in pairs(previousMap) do
		activeMap[k] = v
	end

	if not ok then
		error(err)
	end
end

local function clonePathWorld(path)
	local out = {}
	for i = 1, #path do
		out[i] = {path[i][1], path[i][2]}
	end
	return out
end

function MapPreviewCache.buildAll(w, h)
	local winW, winH = lg.getDimensions()
	local previousMapIndex = State.worldMapIndex

	for mapIndex, mapDef in ipairs(Maps) do
		local context = MapMod.createRenderContext(mapDef)
		local canvas = lg.newCanvas(w, h, {msaa = 8})
		local scatter = context.map.biome and context.map.biome.scatter

		State.worldMapIndex = mapIndex
		withMapContext(context, function()
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
		end)

		MapRender.renderGameplayFramedToCanvas(canvas, context)

		cache[mapDef.id] = {
			canvas = canvas,
			pathWorld = clonePathWorld(context.map.pathWorld),
			mapW = mapW,
			mapH = mapH,
			winW = winW,
			winH = winH,
			camScale = Camera.wscale,
		}
	end

	State.worldMapIndex = previousMapIndex
end

function MapPreviewCache.get(mapId)
	return cache[mapId]
end

return MapPreviewCache
