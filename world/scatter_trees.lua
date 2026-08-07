local Theme = require("core.theme")
local Constants = require("core.constants")
local State = require("core.state")
local Map = require("world.map")
local ScatterCommon = require("world.scatter_common")

local Trees = {}

local lg = love.graphics

local outlineW = Theme.outline.width
local lighting = Theme.lighting
local highlightOffset = lighting.highlightOffset
local highlightScale = lighting.highlightScale
local darkMul = lighting.shadowMul
local shadow = Theme.shadow
local shA = shadow.alpha
local shW = shadow.width
local shH = shadow.height

local TILE = Constants.TILE
local GRID_W = Constants.GRID_W
local GRID_H = Constants.GRID_H

local rng = love.math.newRandomGenerator()

local function random(a, b)
	return rng:random(a, b)
end

local function getTreeWorld()
	local world = Map.getWorld()

	return world and world.tree
end

local function getTreeTrunk()
	local tree = getTreeWorld()

	return (tree and tree.trunk) or Theme.world.treeTrunk
end

local function getTreeTrunkOutline()
	local tree = getTreeWorld()

	return (tree and tree.trunkOutline) or Theme.world.treeTrunkOutline
end

local function getTreeStyles()
	local tree = getTreeWorld()

	return (tree and tree.styles) or Theme.world.treeStyles
end

Trees.list = {}
Trees.occupied = {}

function Trees.clear()
	Trees.list = {}
	Trees.occupied = {}
end

local function setOccupied(gx, gy)
	local col = Trees.occupied[gx]

	if not col then
		col = {}
		Trees.occupied[gx] = col
	end

	col[gy] = true
end

function Trees.hasTreeAt(gx, gy)
	local col = Trees.occupied[gx]

	return col and col[gy] or false
end

local function nearPath(gx, gy)
	return ScatterCommon.isNearPath(Map.map.isPath, gx, gy)
end

function Trees.generate()
	Trees.clear()

	local seed = 65432 + State.worldMapIndex * 977
	rng:setSeed(seed + 1)

	local count = 54 -- Should be able to adjust this too, from biome definition

	local styles = getTreeStyles()
	local shapes = getTreeWorld().shapes or {"round", "square"}

	-- Primary clusters
	local clusters = {}
	local clusterCount = random(3, 5)

	for i = 1, clusterCount do
		clusters[#clusters + 1] = {
			gx = random(3, GRID_W - 2),
			gy = random(3, GRID_H - 2),
			radius = random(2, 4),
		}
	end

	-- Smaller groups
	local microClusters = {}
	local microCount = random(4, 8)

	for i = 1, microCount do
		microClusters[#microClusters + 1] = {
			gx = random(2, GRID_W - 1),
			gy = random(2, GRID_H - 1),
			radius = random(1, 2),
		}
	end

	local function inCluster(gx, gy)
		for i = 1, #clusters do
			local c = clusters[i]
			local dx = gx - c.gx
			local dy = gy - c.gy

			if dx * dx + dy * dy <= c.radius * c.radius then
				return true
			end
		end

		for i = 1, #microClusters do
			local c = microClusters[i]
			local dx = gx - c.gx
			local dy = gy - c.gy

			if dx * dx + dy * dy <= c.radius * c.radius then
				return true
			end
		end

		return false
	end

	-- Generation
	while #Trees.list < count do
		local gx = random(2, GRID_W - 1)
		local gy = random(2, GRID_H - 1)

		local isCluster = inCluster(gx, gy)

		-- Individuals
		if not isCluster then
			if random() < 0.55 then
				goto continue
			end
		end

		-- Path avoidance
		if nearPath(gx, gy) then
			goto continue
		end

		if Map.isBlocked(gx, gy) then
			goto continue
		end

		-- Offset
		local cx = (gx - 0.5) * TILE
		local cy = (gy - 0.5) * TILE

		local x = cx + random(-10, 10)
		local y = cy + random(-10, 10)

		Trees.list[#Trees.list + 1] = {
			x = x,
			y = y,
			gx = gx,
			gy = gy,
			style = random(#styles),
			shape = shapes[random(#shapes)],
			scale = 0.8 + random() * 0.6,
		}

		setOccupied(gx, gy)
		Map.setBlocked(gx, gy)

		::continue::
	end

	table.sort(Trees.list, function(a, b)
		return a.y < b.y
	end)
end

function Trees.draw()
	local trees = Trees.list

	if #trees == 0 then
		return
	end

	local styles = getTreeStyles()
	local trunk = getTreeTrunk()
	local trunkOutline = getTreeTrunkOutline()

	for i = 1, #trees do
		local t = trees[i]
		local style = styles[t.style]

		local x = t.x
		local y = t.y
		local s = t.scale

		local canopyY = y - 5 * s
		local canopySize = TILE * 0.28
		local rOuter = canopySize * s + outlineW * 0.5
		local rInner = rOuter - outlineW

		local tw = 4 * s
		local th = 14 * s
		local two = tw + outlineW * 2
		local tho = th + outlineW * 2

		local trunkY = canopyY + rOuter * 0.72

		-- Shadow
		local shadowY = y + rOuter * shW
		local shadowW = rOuter * shW
		local shadowH = rOuter * shH

		lg.setColor(0, 0, 0, shA)
		lg.ellipse("fill", x, shadowY, shadowW, shadowH)

		-- Trunk outline
		lg.setColor(trunkOutline)
		lg.rectangle("fill", x - two * 0.5, trunkY, two, tho, 2 * s)

		-- Trunk fill
		lg.setColor(trunk)
		lg.rectangle("fill", x - tw * 0.5, trunkY + outlineW, tw, th, 2 * s)

		if t.shape == "round" then
			-- Outline
			lg.setColor(style.outline)
			lg.circle("fill", x, canopyY, rOuter)

			-- Base
			lg.setColor(style.fill[1] * darkMul, style.fill[2] * darkMul, style.fill[3] * darkMul)
			lg.circle("fill", x, canopyY, rInner)

			-- Top highlight
			local hx = x
			local hy = canopyY - rInner * highlightOffset
			local hr = rInner * highlightScale

			lg.setColor(style.fill)
			lg.circle("fill", hx, hy, hr)
		elseif t.shape == "square" then
			local outerRadius = 8 * s + outlineW * 0.5
			local innerRadius = outerRadius - outlineW

			-- Outline
			lg.setColor(style.outline)
			lg.rectangle("fill", x - rOuter, canopyY - rOuter, rOuter * 2, rOuter * 2, outerRadius)

			-- Base
			lg.setColor(style.fill[1] * darkMul, style.fill[2] * darkMul, style.fill[3] * darkMul)
			lg.rectangle("fill", x - rInner, canopyY - rInner, rInner * 2, rInner * 2, innerRadius)

			-- Top highlight
			local hx = x
			local hy = canopyY - rInner * highlightOffset

			local hw = rInner * 2 * highlightScale
			local hh = rInner * 2 * highlightScale

			lg.setColor(style.fill)
			lg.rectangle("fill", hx - hw * 0.5, hy - hh * 0.5, hw, hh, innerRadius)
		elseif t.shape == "evergreen" then
			local layers = 3
			local baseSize = TILE * 0.34 * s

			local yOffset = 0

			for i = layers, 1, -1 do
				local tScale = 0.6 + (i / layers) * 0.6
				local w = baseSize * tScale
				local h = w * 0.85

				local ly = canopyY - yOffset
				yOffset = yOffset + h * 0.65

				local x1, y1 = x, ly - h
				local x2, y2 = x - w, ly + h
				local x3, y3 = x + w, ly + h

				-- Outline
				lg.setColor(style.outline)
				lg.polygon("fill", x1, y1, x2, y2, x3, y3)

				-- Inset (thickness already corrected)
				local inset = outlineW * 2.0
				local denom = w + h * 0.35
				local t = inset / denom

				-- Lighting-aligned vertical bias
				local biasY = h * highlightOffset * 0.6

				local function insetPoint(px, py)
					local nx = x + (px - x) * (1 - t)
					local ny = ly + (py - ly) * (1 - t)

					-- Apply downward lighting bias
					return nx, ny + biasY
				end

				local bx1, by1 = insetPoint(x1, y1)
				local bx2, by2 = insetPoint(x2, y2)
				local bx3, by3 = insetPoint(x3, y3)

				-- Base (shadowed)
				lg.setColor(
					style.fill[1] * darkMul,
					style.fill[2] * darkMul,
					style.fill[3] * darkMul
				)
				lg.polygon("fill", bx1, by1, bx2, by2, bx3, by3)

				-- Highlight (same system)
				local hx = x
				local hy = ly - h * highlightOffset

				local function scale(px, py)
					return hx + (px - hx) * highlightScale,
						   hy + (py - hy) * highlightScale
				end

				local hx1, hy1 = scale(bx1, by1)
				local hx2, hy2 = scale(bx2, by2)
				local hx3, hy3 = scale(bx3, by3)

				lg.setColor(style.fill)
				lg.polygon("fill", hx1, hy1, hx2, hy2, hx3, hy3)
			end
		end
	end
end

return Trees