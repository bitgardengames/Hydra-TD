local Theme = require("core.theme")
local Constants = require("core.constants")
local State = require("core.state")
local Map = require("world.map")

local Trees = {}

local lg = love.graphics

local trunk = Theme.world.treeTrunk
local trunkOutline = Theme.world.treeTrunkOutline
local styles = Theme.world.treeStyles
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
	local path = Map.map.isPath

	for dx = -1, 1 do
		for dy = -1, 1 do
			local x = gx + dx
			local y = gy + dy

			local col = path[x]

			if col and col[y] then
				return true
			end
		end
	end

	return false
end

function Trees.generate()
	Trees.clear()

	local seed = 65432 + State.worldMapIndex * 977
	rng:setSeed(seed + 1)

	local count = 54

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
			shape = random(2),
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

		if t.shape == 1 then
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
		else
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
		end
	end
end

return Trees