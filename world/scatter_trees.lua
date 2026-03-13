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

local TILE = Constants.TILE
local GRID_W = Constants.GRID_W
local GRID_H = Constants.GRID_H

local rng = love.math.newRandomGenerator()

local function random(a, b)
	return rng:random(a, b)
end

Trees.list = {}

function Trees.clear()
	Trees.list = {}
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

		Map.setBlocked(gx, gy)

		::continue::
	end

	-- Depth sort (top to bottom)
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

		local trunkY = canopyY + rOuter * 0.8

		-- shadow
		lg.setColor(0, 0, 0, 0.18)
		lg.ellipse("fill", x, y + rOuter * 1.2, rOuter * 1.2, rOuter * 0.5)

		-- trunk outline
		lg.setColor(trunkOutline)
		lg.rectangle("fill", x - two * 0.5, trunkY, two, tho, 2 * s)

		-- trunk fill
		lg.setColor(trunk)
		lg.rectangle("fill", x - tw * 0.5, trunkY + outlineW, tw, th, 2 * s)

		if t.shape == 1 then
			lg.setColor(style.outline)
			lg.circle("fill", x, canopyY, rOuter)

			lg.setColor(style.fill)
			lg.circle("fill", x, canopyY, rInner)
		else
			local outerRadius = 8 * s + outlineW * 0.5
			local innerRadius = outerRadius - outlineW

			lg.setColor(style.outline)
			lg.rectangle("fill", x - rOuter, canopyY - rOuter, rOuter * 2, rOuter * 2, outerRadius)

			lg.setColor(style.fill)
			lg.rectangle("fill", x - rInner, canopyY - rInner, rInner * 2, rInner * 2, innerRadius)
		end
	end
end

return Trees