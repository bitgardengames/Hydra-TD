local Theme = require("core.theme")
local Constants = require("core.constants")
local State = require("core.state")
local Map = require("world.map")
local Trees = require("world.scatter_trees")

local Cactus = {}

local lg = love.graphics

local styles = {
	{fill = {0.34, 0.62, 0.30}, outline = {0.18, 0.34, 0.16}},
	{fill = {0.28, 0.56, 0.26}, outline = {0.14, 0.30, 0.14}},
	{fill = {0.40, 0.68, 0.36}, outline = {0.20, 0.38, 0.18}},
}

local outlineW = Theme.outline.width

local lighting = Theme.lighting
local darkMul = lighting.shadowMul
local highlightOffset = lighting.highlightOffset
local highlightScale = lighting.highlightScale

local shadow = Theme.shadow
local shA = shadow.alpha

local TILE = Constants.TILE
local GRID_W = Constants.GRID_W
local GRID_H = Constants.GRID_H

local rng = love.math.newRandomGenerator()

local function rand(a, b)
	return rng:random(a, b)
end

Cactus.list = {}

function Cactus.clear()
	Cactus.list = {}
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

function Cactus.generate()
	Cactus.clear()

	local seed = 8888 + State.worldMapIndex * 977
	rng:setSeed(seed)

	local count = 16 + rand(0, 8)

	while #Cactus.list < count do
		local gx = rand(2, GRID_W - 1)
		local gy = rand(2, GRID_H - 1)

		if nearPath(gx, gy) then goto continue end
		if Map.isBlocked(gx, gy) then goto continue end
		if Trees.hasTreeAt and Trees.hasTreeAt(gx, gy) then goto continue end

		local cx = (gx - 0.5) * TILE
		local cy = (gy - 0.5) * TILE

		local cactus = {
			x = cx + rand(-10, 10),
			y = cy + rand(-10, 10),

			style = rand(#styles),
			scale = 0.8 + rand() * 0.5,

			arms = rand() < 0.65,

			-- Stable shape variation
			heightBias = rand(),
			widthBias = rand(),
			armHeightBias = rand(),
			armOffsetBias = rand(),
		}

		Cactus.list[#Cactus.list + 1] = cactus

		::continue::
	end

	table.sort(Cactus.list, function(a, b)
		return a.y < b.y
	end)
end

function Cactus.draw()
	local list = Cactus.list
	if #list == 0 then return end

	for i = 1, #list do
		local c = list[i]
		local style = styles[c.style]

		local x = c.x
		local baseY = c.y
		local s = c.scale

		-- Stable dimensions
		local h = TILE * (0.55 + c.heightBias * 0.35) * s
		local w = TILE * (0.14 + c.widthBias * 0.06) * s

		local topY = baseY - h
		local radius = w * 0.5

		-- Shadow (grounded)
		lg.setColor(0, 0, 0, shA)
		lg.ellipse("fill", x, baseY + 1, w * 1.4, h * 0.28)

		-- === MAIN BODY ===

		-- Outline
		lg.setColor(style.outline)
		lg.rectangle("fill", x - w * 0.5 - outlineW * 0.5, topY, w + outlineW, h, radius + outlineW * 0.5)
		lg.circle("fill", x, topY, radius + outlineW * 0.5)

		-- Base (shadowed)
		lg.setColor(
			style.fill[1] * darkMul,
			style.fill[2] * darkMul,
			style.fill[3] * darkMul
		)
		lg.rectangle("fill", x - w * 0.5, topY, w, h, radius)
		lg.circle("fill", x, topY, radius)

		-- Highlight
		local hx = x
		local hy = topY + radius * 0.5

		lg.setColor(style.fill)
		lg.circle("fill", hx, hy, radius * highlightScale)

		-- === ARMS ===
		if c.arms then
			local armH = h * (0.35 + c.armHeightBias * 0.25)
			local armW = w * 0.7
			local offsetX = w * (0.9 + c.armOffsetBias * 0.2)

			for dir = -1, 1, 2 do
				local ax = x + offsetX * dir
				local ay = baseY - h * (0.45 + c.armHeightBias * 0.15)

				local ar = armW * 0.5

				-- Outline
				lg.setColor(style.outline)
				lg.rectangle("fill", ax - armW * 0.5 - outlineW * 0.5, ay - armH, armW + outlineW, armH, ar + outlineW * 0.5)
				lg.circle("fill", ax, ay - armH, ar + outlineW * 0.5)

				-- Base
				lg.setColor(
					style.fill[1] * darkMul,
					style.fill[2] * darkMul,
					style.fill[3] * darkMul
				)
				lg.rectangle("fill", ax - armW * 0.5, ay - armH, armW, armH, ar)
				lg.circle("fill", ax, ay - armH, ar)

				-- Highlight
				lg.setColor(style.fill)
				lg.circle("fill", ax, ay - armH + ar * 0.5, ar * highlightScale)
			end
		end
	end
end

return Cactus