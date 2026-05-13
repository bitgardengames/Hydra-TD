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
