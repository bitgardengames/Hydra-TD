local Constants = require("core.constants")
local Theme = require("core.theme")
local State = require("core.state")
local Map = require("world.map")
local Trees = require("world.scatter_trees")

local Cactus = {}

local lg = love.graphics

local outlineW = Theme.outline.width

local lighting = Theme.lighting
local darkMul = lighting.shadowMul
local highlightOffset = lighting.highlightOffset
local highlightScale = lighting.highlightScale

local shadow = Theme.shadow
local shA = shadow.alpha
local shW = shadow.width
local shH = shadow.height

local TILE = Constants.TILE
local GRID_W = Constants.GRID_W
local GRID_H = Constants.GRID_H

local rng = love.math.newRandomGenerator()

local function rand(a, b)
	return rng:random(a, b)
end

local function getCactusStyles()
	local world = Map.getWorld()
	local cactus = world and world.cactus

	return cactus and cactus.styles
end

Cactus.list = {}

function Cactus.clear()
	Cactus.list = {}
end

local function nearPath(gx, gy)
	local path = Map.map.isPath

	for dx = -1, 1 do
		for dy = -1, 1 do
			local col = path[gx + dx]

			if col and col[gy + dy] then
				return true
			end
		end
	end

	return false
end

local function drawPart(x, baseY, w, h, style)
	local fill = style.fill
	local outline = style.outline

	local cy = baseY - h * 0.5

	local wOuter = w + outlineW * 2
	local hOuter = h + outlineW * 2

	local innerRadius = w * 0.5
	local outerRadius = innerRadius + outlineW

	-- Outline
	lg.setColor(outline)
	lg.rectangle("fill", x - wOuter * 0.5, cy - hOuter * 0.5, wOuter, hOuter, outerRadius)

	-- Base
	lg.setColor(fill[1] * darkMul, fill[2] * darkMul, fill[3] * darkMul, 1)
	lg.rectangle("fill", x - w * 0.5, cy - h * 0.5, w, h, innerRadius)

	-- Highlight
	local hx = x
	local hy = cy - h * 0.5 * highlightOffset
	local hw = w * highlightScale
	local hh = h * highlightScale

	lg.setColor(fill)
	lg.rectangle("fill", hx - hw * 0.5, hy - hh * 0.5, hw, hh, innerRadius * highlightScale)
end

-- Flower
local function drawFlower(x, y, scale, color)
	local outline = {0.24, 0.12, 0.10}

	local rx = 6.5 * scale
	local ry = 2.6 * scale

	lg.setColor(outline)
	lg.ellipse("fill", x, y, rx + outlineW, ry + outlineW)

	lg.setColor(color[1] * darkMul, color[2] * darkMul, color[3] * darkMul, 1)
	lg.ellipse("fill", x, y, rx, ry)

	lg.setColor(color)
	lg.ellipse("fill", x, y - ry * highlightOffset, rx * highlightScale, ry * highlightScale)
end

function Cactus.generate()
	Cactus.clear()

	local seed = 8888 + State.worldMapIndex * 977
	rng:setSeed(seed)

	local count = 10 + rand(0, 6)
	local styles = getCactusStyles()

	local occupied = {}

	while #Cactus.list < count do
		local gx = rand(2, GRID_W - 1)
		local gy = rand(2, GRID_H - 1)

		occupied[gx] = occupied[gx] or {}

		if occupied[gx][gy] then goto continue end
		if nearPath(gx, gy) then goto continue end
		if Map.isBlocked(gx, gy) then goto continue end
		if Trees.hasTreeAt and Trees.hasTreeAt(gx, gy) then goto continue end

		local cx = (gx - 0.5) * TILE
		local cy = (gy - 0.5) * TILE

		local shape = (rand() < 0.14) and "round" or "tall"
		local hasFlower = rand() < 0.35

		local armMode = 0

		if shape ~= "round" then
			local r = rand()

			if r < 0.10 then
				armMode = 0
			elseif r < 0.58 then
				armMode = 1
			else
				armMode = 2
			end
		end

		local side1 = rand() < 0.5 and -1 or 1
		local side2 = (armMode == 2) and -side1 or side1

		Cactus.list[#Cactus.list + 1] = {
			x = cx + rand(-10, 10),
			y = cy + rand(-10, 10),

			style = rand(#styles),
			scale = 0.85 + rand() * 0.55,

			shape = shape,
			hasFlower = hasFlower,

			armMode = armMode,

			heightBias = rand(),
			widthBias = rand(),

			arm1 = {side = side1, height = rand(), width = rand(), offset = rand(), y = rand()},
			arm2 = {side = side2, height = rand(), width = rand(), offset = rand(), y = rand()},
		}

		occupied[gx][gy] = true

		::continue::
	end

	table.sort(Cactus.list, function(a, b)
		return a.y < b.y
	end)
end

function Cactus.draw()
	local list = Cactus.list
	if #list == 0 then return end

	local styles = getCactusStyles()
	local flowerColor = {0.95, 0.45, 0.55}

	for i = 1, #list do
		local c = list[i]
		local style = styles[c.style]

		local x = c.x
		local baseY = c.y
		local s = c.scale

		local h, w

		if c.shape == "round" then
			h = TILE * (0.32 + c.heightBias * 0.10) * s
			w = TILE * (0.34 + c.widthBias * 0.12) * s
		else
			h = TILE * (0.62 + c.heightBias * 0.40) * s
			w = TILE * (0.15 + c.widthBias * 0.05) * s
		end

		-- ✅ FIXED SHADOW (tight, radius-based like trees)
		local radius = w * 0.5
		lg.setColor(0, 0, 0, shA)
		lg.ellipse("fill", x, baseY + 1, radius * shW * 2.0, radius * shH * 2.0)

		if c.shape == "round" then
			local cy = baseY - h * 0.5
			local rx = w * 0.5
			local ry = h * 0.5

			lg.setColor(style.outline)
			lg.ellipse("fill", x, cy, rx + outlineW, ry + outlineW)

			lg.setColor(style.fill[1] * darkMul, style.fill[2] * darkMul, style.fill[3] * darkMul)
			lg.ellipse("fill", x, cy, rx, ry)

			lg.setColor(style.fill)
			lg.ellipse("fill", x, cy - ry * highlightOffset, rx * highlightScale, ry * highlightScale)

			if c.hasFlower then
				local top = cy - ry
				drawFlower(x, top - 3.5 * s, 0.7 * s, flowerColor)
			end
		else
			local function drawArm(a)
				local armW = w * (0.55 + a.width * 0.20)
				local armH = h * (0.38 + a.height * 0.30)

				local edgeX = x + (w * 0.5) * a.side
				local armX = edgeX + (w * (0.16 + a.offset * 0.34)) * a.side
				local armY = baseY - h * (0.44 + a.y * 0.32)

				drawPart(armX, armY, armW, armH, style)
			end

			if c.armMode >= 1 then drawArm(c.arm1) end
			if c.armMode >= 2 then drawArm(c.arm2) end

			drawPart(x, baseY, w, h, style)

			if c.hasFlower then
				local top = baseY - h
				drawFlower(x, top - 3.5 * s, 0.7 * s, flowerColor)
			end
		end
	end
end

return Cactus