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

	local count = 48

	while #Trees.list < count do
		local gx = random(2, GRID_W - 1)
		local gy = random(2, GRID_H - 1)

		if nearPath(gx, gy) then
			goto continue
		end

		if Map.isBlocked(gx, gy) then
			goto continue
		end

		local x = (gx - 0.5) * TILE
		local y = (gy - 0.5) * TILE

		Trees.list[#Trees.list + 1] = {
			x = x,
			y = y,
			gx = gx,
			gy = gy,
			style = random(#styles),
			shape = random(2),
			scale = 0.8 + random() * 0.6
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