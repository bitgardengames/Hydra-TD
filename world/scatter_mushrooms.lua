local Constants = require("core.constants")
local Theme = require("core.theme")
local State = require("core.state")
local Map = require("world.map")
local ScatterCommon = require("world.scatter_common")

local Mushrooms = {}

local lg = love.graphics

local TILE = Constants.TILE
local GRID_W = Constants.GRID_W
local GRID_H = Constants.GRID_H

local outlineW = Theme.outline.width

local lighting = Theme.lighting
local darkMul = lighting.shadowMul
local highlightOffset = lighting.highlightOffset
local highlightScale = lighting.highlightScale

local shadow = Theme.shadow
local shA = shadow.alpha
local shW = shadow.width
local shH = shadow.height

local rng = love.math.newRandomGenerator()

local function rand(a, b)
	return rng:random(a, b)
end

local function getMushroomStyles()
	local world = Map.getWorld()
	local mushroom = world and world.mushroom

	return (mushroom and mushroom.styles) or {
		{fill = {0.72, 0.42, 0.86}, outline = {0.40, 0.20, 0.50}},
		{fill = {0.46, 0.68, 0.92}, outline = {0.24, 0.36, 0.52}},
		{fill = {0.92, 0.48, 0.62}, outline = {0.52, 0.24, 0.34}},
		{fill = {0.40, 0.72, 0.68}, outline = {0.20, 0.42, 0.38}},
	}
end

Mushrooms.list = {}

function Mushrooms.clear()
	Mushrooms.list = {}
end

local function nearPath(gx, gy)
	return ScatterCommon.isNearPath(Map.map.isPath, gx, gy)
end

function Mushrooms.generate()
	Mushrooms.clear()

	local seed = 9999 + State.worldMapIndex * 977
	rng:setSeed(seed)

	local styles = getMushroomStyles()
	local count = 44
	local occupied = {}

	while #Mushrooms.list < count do
		local gx = rand(2, GRID_W - 1)
		local gy = rand(2, GRID_H - 1)

		occupied[gx] = occupied[gx] or {}

		if occupied[gx][gy] then goto continue end
		if nearPath(gx, gy) then goto continue end
		if Map.isBlocked(gx, gy) then goto continue end

		local cx = (gx - 0.5) * TILE
		local cy = (gy - 0.5) * TILE

		local scale = 0.85 + rand() * 1.05
		if rand() < 0.22 then
			scale = scale * 1.18
		end

		Mushrooms.list[#Mushrooms.list + 1] = {
			x = cx + rand(-14, 14),
			y = cy + rand(-14, 14),

			scale = scale,
			style = rand(#styles),

			stemH = 14 + rand() * 16,
			stemW = 4 + rand() * 3,

			capW = 16 + rand() * 18,
			capH = 7 + rand() * 9,

			lean = -0.18 + rand() * 0.36,
			capLift = rand() * 2.5,
		}

		occupied[gx][gy] = true

		::continue::
	end

	table.sort(Mushrooms.list, function(a, b)
		return a.y < b.y
	end)
end

function Mushrooms.draw()
	local list = Mushrooms.list
	if #list == 0 then return end

	local styles = getMushroomStyles()

	for i = 1, #list do
		local m = list[i]
		local style = styles[m.style]
		if not style then goto continue end

		local s = m.scale
		local x = m.x
		local y = m.y

		local stemH = m.stemH * s
		local stemW = m.stemW * s

		local capW = m.capW * s
		local capH = m.capH * s

		local stemTopY = y - stemH
		local capCY = stemTopY + capH * 0.48 - (m.capLift or 0)

		local stemColor = {0.86, 0.82, 0.76}

		-- Shadow
		lg.setColor(0, 0, 0, shA)
		lg.ellipse("fill", x, y + 1, capW * 0.34 * shW, capH * 0.75 * shH)

		-- Stem
		lg.setColor(style.outline)
		lg.rectangle("fill",
			x - stemW * 0.5 - outlineW,
			y - stemH - outlineW,
			stemW + outlineW * 2,
			stemH + outlineW * 2,
			stemW
		)

		lg.setColor(stemColor[1] * darkMul, stemColor[2] * darkMul, stemColor[3] * darkMul)
		lg.rectangle("fill",
			x - stemW * 0.5,
			y - stemH,
			stemW,
			stemH,
			stemW
		)

		-- Cap body
		local capBodyH = capH * 0.55
		local capBodyY = capCY - capBodyH * 0.5

		lg.setColor(style.outline)
		lg.rectangle("fill",
			x - capW * 0.5 - outlineW,
			capBodyY,
			capW + outlineW * 2,
			capBodyH + outlineW,
			capBodyH * 0.5
		)

		lg.setColor(style.fill[1] * darkMul, style.fill[2] * darkMul, style.fill[3] * darkMul)
		lg.rectangle("fill",
			x - capW * 0.5,
			capBodyY,
			capW,
			capBodyH,
			capBodyH * 0.5
		)

		-- =========================
		-- CAP ARC
		-- =========================
		lg.setColor(style.outline)
		lg.arc("fill", "open", x, capCY, capW * 0.5 + outlineW, math.pi, math.pi * 2, 24)

		lg.setColor(style.fill[1] * darkMul, style.fill[2] * darkMul, style.fill[3] * darkMul)
		lg.arc("fill", "open", x, capCY, capW * 0.5, math.pi, math.pi * 2, 24)

		-- =========================
		-- HIGHLIGHT (ARC + BODY)
		-- =========================
		local hx = x + capW * 0.08 * (m.lean or 0)
		local hy = capCY - capH * highlightOffset

		lg.setColor(style.fill)
		lg.arc("fill", "open", hx, hy, capW * 0.5 * highlightScale, math.pi, math.pi * 2, 24)

		-- 🔥 PROPER highlight body (aligned with lighting system)
		local hx = x
		local hy = capBodyY - capBodyH * highlightOffset

		local hw = capW * highlightScale
		local hh = capBodyH * highlightScale

		lg.setColor(style.fill)
		lg.rectangle("fill",
			hx - hw * 0.5,
			hy,
			hw,
			hh,
			capBodyH * 0.5 * highlightScale
		)

		--[[ Dots
		if capW > 22 then
			local dotCount = 2 + math.floor(rand() * 2)

			for d = 1, dotCount do
				local px = (rand() - 0.5) * capW * 0.7
				local py = -(rand() * capH * 0.55)

				local rr = (1.2 + rand() * 1.8) * s
				local alpha = 0.7 + rand() * 0.18

				lg.setColor(0.94, 0.94, 0.95, alpha)
				lg.circle("fill", x + px, capCY + py, rr)
			end
		end]]

		::continue::
	end
end

return Mushrooms