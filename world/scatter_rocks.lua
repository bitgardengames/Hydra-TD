local Theme = require("core.theme")
local Constants = require("core.constants")
local State = require("core.state")
local Map = require("world.map")
local Trees = require("world.scatter_trees")

local Rocks = {}

local lg = love.graphics
local floor = math.floor
local treeAt = Trees.hasTreeAt

local styles = Theme.world.rockStyles
local outlineW = Theme.outline.width

local TILE = Constants.TILE
local GRID_W = Constants.GRID_W
local GRID_H = Constants.GRID_H

local rng = love.math.newRandomGenerator()

local function random(a, b)
	return rng:random(a, b)
end

Rocks.list = {}

function Rocks.clear()
	Rocks.list = {}
end

local function nearPath(gx, gy)
	local path = Map.map.isPath

	for dx = -1,1 do
		for dy = -1,1 do
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

function Rocks.generate()
	Rocks.clear()

	local seed = 4321 + State.worldMapIndex * 977
	rng:setSeed(seed + 2)

	local count = 28
	local occupied = {}

	while #Rocks.list < count do
		local gx = random(2, GRID_W - 1)
		local gy = random(2, GRID_H - 1)

		occupied[gx] = occupied[gx] or {}

		if occupied[gx][gy] then
			goto continue
		end

		if nearPath(gx, gy) then
			goto continue
		end

		if treeAt(gx, gy) then
			goto continue
		end

		local cx = (gx - 0.5) * TILE
		local cy = (gy - 0.5) * TILE

		-- varied position inside tile
		local x = cx + random(-18, 18)
		local y = cy + random(-18, 18)

		local rock = {
			x = x,
			y = y,
			style = random(#styles),

			-- slightly larger upper bound
			scale = 0.90 + random() * 0.80,

			-- 30% chance of a paired rock
			pair = random() < 0.30
		}

		if rock.pair then
			rock.pairOffsetX = random(-18, 18)
			rock.pairOffsetY = random(-18, 18)

			-- paired rock is usually smaller
			rock.pairScale = 0.75 + random() * 0.55
		end

		Rocks.list[#Rocks.list + 1] = rock
		occupied[gx][gy] = true

		::continue::
	end
end

function Rocks.draw()
	local rocks = Rocks.list
	if #rocks == 0 then return end

	for i = 1, #rocks do
		local r = rocks[i]
		local style = styles[r.style]

		local x = r.x
		local y = r.y
		local s = r.scale

		local wOuter = 14 * s + outlineW
		local hOuter = 10 * s + outlineW

		local wInner = wOuter - outlineW * 2
		local hInner = hOuter - outlineW * 2

		local outerRadius = 5 * s + outlineW * 0.5
		local innerRadius = outerRadius - outlineW

		-- outline
		lg.setColor(style.outline)
		lg.rectangle("fill", x - wOuter * 0.5, y - hOuter * 0.5, wOuter, hOuter, outerRadius)

		-- fill
		lg.setColor(style.fill)
		lg.rectangle("fill", x - wInner * 0.5, y - hInner * 0.5, wInner, hInner, innerRadius)

		-- paired rock
		if r.pair then
			local ps = s * r.pairScale
			local px = x + r.pairOffsetX
			local py = y + r.pairOffsetY

			local pwOuter = 10 * ps + outlineW
			local phOuter = 8 * ps + outlineW

			local pwInner = pwOuter - outlineW * 2
			local phInner = phOuter - outlineW * 2

			local baseRadius = 5 * ps
			local outerRadius = baseRadius + outlineW * 0.5
			local innerRadius = baseRadius - outlineW * 0.25

			lg.setColor(style.outline)
			lg.rectangle("fill", px - pwOuter * 0.5, py - phOuter * 0.5, pwOuter, phOuter, outerRadius)

			lg.setColor(style.fill)
			lg.rectangle("fill", px - pwInner * 0.5, py - phInner * 0.5, pwInner, phInner, innerRadius)
		end
	end
end

return Rocks