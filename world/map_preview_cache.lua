local MapPreviewCache = {}

local Maps = require("world.map_defs")
local State = require("core.state")
local MapRender = require("world.map_render")

local lg = love.graphics

local cache = {}

function MapPreviewCache.buildAll(w, h)
	for i, map in ipairs(Maps) do
		State.worldMapIndex = i

		if resetGame then
			resetGame()
		end

		local canvas = lg.newCanvas(w, h, {msaa = 8})

		MapRender.renderToCanvas(canvas)

		cache[map.id] = canvas
	end
end

function MapPreviewCache.get(mapId)
	return cache[mapId]
end

return MapPreviewCache