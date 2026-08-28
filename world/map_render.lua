local DrawWorld = require("render.draw_world")
local Constants = require("core.constants")

local MapRender = {}

local lg = love.graphics

local MAP_W = Constants.GRID_W * Constants.TILE
local MAP_H = Constants.GRID_H * Constants.TILE

-- Menu previews reproduce the authored gameplay composition, independently of
-- the window that happens to be active while the cache is being built.
local PREVIEW_VIEWPORT_W = 1920
local PREVIEW_VIEWPORT_H = 1080
local PREVIEW_CAMERA_SCALE = 1.6

function MapRender.gameplayPreviewTransform(destinationW, destinationH)
	local destinationScale = math.min(
		destinationW / PREVIEW_VIEWPORT_W,
		destinationH / PREVIEW_VIEWPORT_H
	)
	local renderedW = PREVIEW_VIEWPORT_W * destinationScale
	local renderedH = PREVIEW_VIEWPORT_H * destinationScale

	return {
		viewportW = PREVIEW_VIEWPORT_W,
		viewportH = PREVIEW_VIEWPORT_H,
		cameraScale = PREVIEW_CAMERA_SCALE,
		destinationScale = destinationScale,
		offsetX = (destinationW - renderedW) * 0.5,
		offsetY = (destinationH - renderedH) * 0.5,
		cameraX = MAP_W * 0.5 - PREVIEW_VIEWPORT_W / (2 * PREVIEW_CAMERA_SCALE),
		cameraY = MAP_H * 0.5 - PREVIEW_VIEWPORT_H / (2 * PREVIEW_CAMERA_SCALE),
	}
end

function MapRender.renderWorldToCanvas(canvas, scale, context)
	lg.setCanvas(canvas)
	lg.clear(0, 0, 0, 0)

	lg.push()
	lg.origin()
	lg.scale(scale, scale)

	local map = context and context.map
	local decorations = context and context.decorations
	DrawWorld.drawGrass(map)
	DrawWorld.drawPath(map)
	-- Tree canopies are animated separately so the rest of the world can stay cached.
	DrawWorld.drawScatter("static", map, decorations)

	lg.pop()
	lg.setCanvas()
end

function MapRender.renderGameplayFramedToCanvas(canvas, context, transform)
	local canvasW, canvasH = canvas:getDimensions()
	transform = transform or MapRender.gameplayPreviewTransform(canvasW, canvasH)

	lg.setCanvas(canvas)
	lg.clear(0, 0, 0, 0)

	lg.push()
	lg.origin()

	lg.translate(transform.offsetX, transform.offsetY)
	local scale = transform.cameraScale * transform.destinationScale
	lg.scale(scale, scale)
	lg.translate(-transform.cameraX, -transform.cameraY)

	local map = context and context.map
	local decorations = context and context.decorations
	DrawWorld.drawGrass(map)
	DrawWorld.drawPath(map)
	DrawWorld.drawScatter(nil, map, decorations)

	lg.pop()
	lg.setCanvas()
end

-- Full-map rendering is retained for exports and tools that need the complete
-- authored grid. Menu previews use renderGameplayFramedToCanvas above so their
-- composition matches what the player sees after entering the map.
function MapRender.renderFullMapToCanvas(canvas, context)
	local canvasW, canvasH = canvas:getDimensions()

	lg.setCanvas(canvas)
	lg.clear(0, 0, 0, 0)

	lg.push()
	lg.origin()
	lg.scale(canvasW / MAP_W, canvasH / MAP_H)

	local map = context and context.map
	local decorations = context and context.decorations
	DrawWorld.drawGrass(map)
	DrawWorld.drawPath(map)
	DrawWorld.drawScatter(nil, map, decorations)

	lg.pop()
	lg.setCanvas()
end

return MapRender
