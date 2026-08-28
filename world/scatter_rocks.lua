local Theme = require("core.theme")
local Constants = require("core.constants")
local State = require("core.state")
local Map = require("world.map")
local ScatterCommon = require("world.scatter_common")
local Trees = require("world.scatter_trees")

local Rocks = {}

local lg = love.graphics
local floor = math.floor


local outlineW = Theme.outline.width
local lighting = Theme.lighting
local darkMul = lighting.shadowMul
local highlightOffset = lighting.highlightOffset
local highlightScale = lighting.highlightScale

local TILE = Constants.TILE
local GRID_W = Constants.GRID_W
local GRID_H = Constants.GRID_H

local function getRockStyles(targetMap)
	local world = targetMap and targetMap.biome and targetMap.biome.world
	local rock = world and world.rock

	return (rock and rock.styles) or Theme.world.rockStyles
end

local rng = love.math.newRandomGenerator()

local function random(a, b)
	return rng:random(a, b)
end

Rocks.list = {}

function Rocks.clear()
	Rocks.list = {}
end

function Rocks.generate(targetMap, mapIndex, list, treeOccupied)
	targetMap = targetMap or Map.map
	mapIndex = mapIndex or State.worldMapIndex
	list = list or {}

	local seed = 4321 + mapIndex * 977
	rng:setSeed(seed + 2)

	local count = 28 -- Should be able to modify this per biome

	local styles = getRockStyles(targetMap)

	local function canPlace(gx, gy)
		return not ScatterCommon.isNearPath(targetMap.isPath, gx, gy) and not (treeOccupied and treeOccupied[gx] and treeOccupied[gx][gy])
	end

	local function create(gx, gy)
		local cx = (gx - 0.5) * TILE
		local cy = (gy - 0.5) * TILE

		-- varied position inside tile
		local x = cx + random(-18, 18)
		local y = cy + random(-18, 18)

		local rock = {x = x, y = y, style = random(#styles), scale = 0.90 + random() * 0.80, pair = random() < 0.26} -- 26% pair chance

		if rock.pair then
			rock.pairOffsetX = random(-18, 18)
			rock.pairOffsetY = random(-18, 18)
			rock.pairScale = 0.75 + random() * 0.55 -- Paired rock is usually smaller
		end

		return rock
	end

	ScatterCommon.populate(list, count, random, GRID_W, GRID_H, canPlace, create)
	return list
end

function Rocks.draw(list, targetMap)
	local rocks = list or Rocks.list

	if #rocks == 0 then
		return
	end

	local styles = getRockStyles(targetMap or Map.map)

	for i = 1, #rocks do
		local r = rocks[i]
		local style = styles[r.style]

		if not style or not style.fill or not style.outline then
			goto continue
		end

		local fill = style.fill
		local outline = style.outline

		local rCol = fill[1]
		local gCol = fill[2]
		local bCol = fill[3]

		local oR = outline[1]
		local oG = outline[2]
		local oB = outline[3]

		local x = r.x
		local y = r.y
		local s = r.scale

		local wOuter = 14 * s + outlineW
		local hOuter = 10 * s + outlineW

		local wInner = wOuter - outlineW * 2
		local hInner = hOuter - outlineW * 2

		local outerRadius = 5 * s + outlineW * 0.5
		local innerRadius = outerRadius - outlineW

		-- Outline
		lg.setColor(oR, oG, oB, 1)
		lg.rectangle("fill", x - wOuter * 0.5, y - hOuter * 0.5, wOuter, hOuter, outerRadius)

		-- Fill (shadowed base)
		lg.setColor(rCol * darkMul, gCol * darkMul, bCol * darkMul, 1)
		lg.rectangle("fill", x - wInner * 0.5, y - hInner * 0.5, wInner, hInner, innerRadius)

		-- Highlight
		local hx = x
		local hy = y - hInner * 0.5 * highlightOffset
		local hw = wInner * highlightScale
		local hh = hInner * highlightScale

		lg.setColor(rCol, gCol, bCol, 1)
		lg.rectangle("fill", hx - hw * 0.5, hy - hh * 0.5, hw, hh, innerRadius)

		-- Paired rock
		if r.pair then
			local ps = s * r.pairScale
			local px = x + r.pairOffsetX
			local py = y + r.pairOffsetY

			local pwOuter = 10 * ps + outlineW
			local phOuter = 8 * ps + outlineW

			local pwInner = pwOuter - outlineW * 2
			local phInner = phOuter - outlineW * 2

			local pairOuterRadius = 5 * ps + outlineW * 0.5
			local pairInnerRadius = pairOuterRadius - outlineW

			-- Outline
			lg.setColor(oR, oG, oB, 1)
			lg.rectangle("fill", px - pwOuter * 0.5, py - phOuter * 0.5, pwOuter, phOuter, pairOuterRadius)

			-- Fill
			lg.setColor(rCol * darkMul, gCol * darkMul, bCol * darkMul, 1)
			lg.rectangle("fill", px - pwInner * 0.5, py - phInner * 0.5, pwInner, phInner, pairInnerRadius)

			-- Highlight
			local phx = px
			local phy = py - phInner * 0.5 * highlightOffset
			local phw = pwInner * highlightScale
			local phh = phInner * highlightScale

			lg.setColor(rCol, gCol, bCol, 1)
			lg.rectangle("fill", phx - phw * 0.5, phy - phh * 0.5, phw, phh, pairInnerRadius)
		end

		::continue::
	end
end

return Rocks
