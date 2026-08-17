local Constants = require("core.constants")
local Theme = require("core.theme")
local MapMod = require("world.map")
local State = require("core.state")
local AbilityDefs = require("systems.ability_defs")
local Abilities = require("systems.abilities")
local Effects = require("world.effects")
local Trees = require("world.scatter_trees")
local Cacti = require("world.scatter_cactus")
local Rocks = require("world.scatter_rocks")
local Mushrooms = require("world.scatter_mushrooms")

local lg = love.graphics
local min = math.min
local sin = math.sin
local abs = math.abs
local sqrt = math.sqrt
local floor = math.floor

local tile = Constants.TILE
local gridW = Constants.GRID_W
local gridH = Constants.GRID_H

local colorGrid = Theme.grid
local outlineW = Theme.outline.width
local COLOR_ACTIVE_FALLBACK = {1, .7, .25}
local COLOR_PREVIEW_FALLBACK = {1, 1, 1}
local COLOR_PREVIEW_INVALID = {1, .2, .2}

local gridToCenter = MapMod.gridToCenter

local function getTerrain()
	local biome = MapMod.map and MapMod.map.biome

	if biome and biome.terrain then
		return biome.terrain
	end

	return Theme.terrain
end

local function hashNoise(x, y, seed)
	local n = sin(x * 127.1 + y * 311.7 + seed * 74.7) * 43758.5453

	return n - floor(n)
end

local grassScatterCanvas
local grassCacheMapRef
local grassCacheTile
local grassCacheW
local grassCacheH
local grassCacheR, grassCacheG, grassCacheB, grassCacheA

local function buildGrassScatterCache(terrain)
	local map = MapMod.map

	if not map or not map.isPath then
		grassScatterCanvas = nil
		grassCacheMapRef = nil
		return
	end

	local grass = terrain.grass
	local gR = grass[1] or 0
	local gG = grass[2] or 0
	local gB = grass[3] or 0
	local gA = grass[4] or 1

	if grassScatterCanvas
		and grassCacheMapRef == map.isPath
		and grassCacheW == gridW
		and grassCacheH == gridH
		and grassCacheTile == tile
		and grassCacheR == gR
		and grassCacheG == gG
		and grassCacheB == gB
		and grassCacheA == gA then
		return
	end

	grassCacheMapRef = map.isPath
	grassCacheW = gridW
	grassCacheH = gridH
	grassCacheTile = tile
	grassCacheR, grassCacheG, grassCacheB, grassCacheA = gR, gG, gB, gA
	grassScatterCanvas = lg.newCanvas(gridW * tile, gridH * tile)

	local colorScatterDark = {gR * 0.94, gG * 0.94, gB * 0.94, 1}
	local colorScatterLight = {gR * 1.06, gG * 1.06, gB * 1.06, 1}

	lg.push("all")
	lg.setCanvas(grassScatterCanvas)
	lg.clear(0, 0, 0, 0)

	for y = 1, gridH do
		for x = 1, gridW do
			local col = map.isPath[x]

			if not (col and col[y]) then
				local seed = (x * 127 + y * 331) % 997
				local r = seed % 4

				if r == 0 then
					local useLight = (seed % 7) < 3

					lg.setColor(useLight and colorScatterLight or colorScatterDark)

					for i = 1, 2 do
						local ox = (seed * (13 + i * 17)) % (tile - 8) + 4
						local oy = (seed * (29 + i * 23)) % (tile - 8) + 4

						lg.rectangle("fill", (x - 1) * tile + ox, (y - 1) * tile + oy, 6, 6, 2)
					end
				end
			end
		end
	end

	lg.pop()
end

local function drawGrass()
	local terrain = getTerrain()
	local grass = terrain.grass

	buildGrassScatterCache(terrain)

	lg.setColor(grass)
	lg.rectangle("fill", 0, 0, gridW * tile, gridH * tile)

	if grassScatterCanvas then
		lg.setColor(1, 1, 1, 1)
		lg.draw(grassScatterCanvas, 0, 0)
	end
end

local function isWater(gx, gy)
	local water = MapMod.map.water

	if not water then
		return false
	end

	for i = 1, #water do
		local blob = water[i]
		local bx, by, r = blob[1], blob[2], blob[3]

		local dx = gx - bx
		local dy = gy - by
		local d = sqrt(dx * dx + dy * dy)

		local n = hashNoise(gx, gy, i)

		local edge = r * (1 + (n - 0.5) * 0.36)

		if d <= edge then
			return true
		end
	end

	return false
end

local function drawWater()
	local radius = 8
	local water = MapMod.map.water

	if not water then
		return
	end

	local terrain = getTerrain()

	lg.setColor(terrain.water)

	for i = 1, #water do
		local blob = water[i]
		local bx, by, r = blob[1], blob[2], blob[3]

		for y = -r - 1, r + 1 do
			for x = -r - 1, r + 1 do

				local gx = bx + x
				local gy = by + y

				if gx >= 1 and gx <= gridW and gy >= 1 and gy <= gridH then
					if isWater(gx, gy) then

						local wx = (gx - 1) * tile
						local wy = (gy - 1) * tile

						-- Base rounded tile
						lg.rectangle("fill", wx, wy, tile, tile, radius, radius)

						-- Fill horizontal seam
						if isWater(gx + 1, gy) then
							lg.rectangle("fill", wx + tile - radius, wy, radius * 2, tile)
						end

						-- Fill vertical seam
						if isWater(gx, gy + 1) then
							lg.rectangle("fill", wx, wy + tile - radius, tile, radius * 2)
						end
					end
				end
			end
		end
	end
end

local function updatePathColor(color)
	colorPath = color
end

local function updateGrassColor(_)
	grassCacheMapRef = nil
end

local function updateWaterColor(color)
	colorWater = color
end

-- This system is already getting ready for a rework
local function drawScatter(treeMode)
	local biome = MapMod.map and MapMod.map.biome
	local scatter = biome and biome.scatter

	if not scatter then
		return
	end

	if scatter.rocks and scatter.rocks.enabled then
		Rocks.draw()
	end

	if scatter.trees and scatter.trees.enabled then
		Trees.draw(treeMode)
	end

	if scatter.cactus and scatter.cactus.enabled then
		Cacti.draw()
	end

	if scatter.mushrooms and scatter.mushrooms.enabled then
		Mushrooms.draw()
	end
end

local function drawAnimatedScatter()
	local biome = MapMod.map and MapMod.map.biome
	local trees = biome and biome.scatter and biome.scatter.trees

	if trees and trees.enabled then
		Trees.draw("animated")
	end
end

local function drawPath()
	local pathThickness = tile
	local path = MapMod.map.path
	local pathLen = #path

	local outlineThickness = pathThickness
	local halfOutline = outlineThickness * 0.5

	local fillThickness = pathThickness - outlineW * 2
	local halfFill = fillThickness * 0.5

	local terrain = getTerrain()

	-- Outline
	lg.setColor(terrain.pathOutline)

	for i = 1, pathLen - 1 do
		local a = path[i]
		local b = path[i + 1]

		local ax, ay = gridToCenter(a[1], a[2])
		local bx, by = gridToCenter(b[1], b[2])

		local dx = b[1] - a[1]
		local dy = b[2] - a[2]

		local trimA, trimB = false, false

		if i > 1 then
			local p = path[i - 1]
			trimA = (p[1] ~= b[1] and p[2] ~= b[2])
		end

		if i < pathLen - 1 then
			local n = path[i + 2]
			trimB = (n[1] ~= a[1] and n[2] ~= a[2])
		end

		if dx ~= 0 then
			local x1 = min(ax, bx)
			local w = abs(bx - ax)

			if trimA then
				x1 = x1 + halfOutline
				w = w - halfOutline
			end

			if trimB then
				w = w - halfOutline
			end

			lg.rectangle("fill", x1, ay - halfOutline, w, outlineThickness)
		else
			local y1 = min(ay, by)
			local h = abs(by - ay)

			if trimA then
				y1 = y1 + halfOutline
				h = h - halfOutline
			end

			if trimB then
				h = h - halfOutline
			end

			lg.rectangle("fill", ax - halfOutline, y1, outlineThickness, h)
		end
	end

	for i = 2, pathLen - 1 do
		local prev = path[i - 1]
		local cur = path[i]
		local next = path[i + 1]

		local dx1 = cur[1] - prev[1]
		local dy1 = cur[2] - prev[2]
		local dx2 = next[1] - cur[1]
		local dy2 = next[2] - cur[2]

		if dx1 ~= dx2 or dy1 ~= dy2 then
			local cx, cy = gridToCenter(cur[1], cur[2])
			lg.circle("fill", cx, cy, halfOutline)
		end
	end

	-- Fill
	lg.setColor(terrain.path)

	for i = 1, pathLen - 1 do
		local a = path[i]
		local b = path[i + 1]

		local ax, ay = gridToCenter(a[1], a[2])
		local bx, by = gridToCenter(b[1], b[2])

		local dx = b[1] - a[1]
		local dy = b[2] - a[2]

		local trimA, trimB = false, false

		if i > 1 then
			local p = path[i - 1]
			trimA = (p[1] ~= b[1] and p[2] ~= b[2])
		end

		if i < pathLen - 1 then
			local n = path[i + 2]
			trimB = (n[1] ~= a[1] and n[2] ~= a[2])
		end

		if dx ~= 0 then
			local x1 = min(ax, bx)
			local w = abs(bx - ax)

			if trimA then
				x1 = x1 + halfFill
				w = w - halfFill
			end

			if trimB then
				w = w - halfFill
			end

			lg.rectangle("fill", x1, ay - halfFill, w, fillThickness)
		else
			local y1 = min(ay, by)
			local h = abs(by - ay)

			if trimA then
				y1 = y1 + halfFill
				h = h - halfFill
			end

			if trimB then
				h = h - halfFill
			end

			lg.rectangle("fill", ax - halfFill, y1, fillThickness, h)
		end
	end

	for i = 2, pathLen - 1 do
		local prev = path[i - 1]
		local cur = path[i]
		local next = path[i + 1]

		local dx1 = cur[1] - prev[1]
		local dy1 = cur[2] - prev[2]
		local dx2 = next[1] - cur[1]
		local dy2 = next[2] - cur[2]

		if dx1 ~= dx2 or dy1 ~= dy2 then
			local cx, cy = gridToCenter(cur[1], cur[2])
			lg.circle("fill", cx, cy, halfFill)
		end
	end
end

local function drawWorld()
	drawGrass()
	drawWater()
	drawPath()
	drawScatter()
end

local function drawEntityMarker(entity, color, alpha, radius)
	local x, y = entity.rx or entity.x, entity.ry or entity.renderY or entity.y
	lg.setColor(color[1], color[2], color[3], .18 * alpha)
	lg.circle("fill", x, y, radius)
	lg.setColor(color[1], color[2], color[3], .95 * alpha)
	lg.setLineWidth(2)
	lg.circle("line", x, y, radius)
end

local function drawIncomingMeteor(effect, clock)
	local duration = effect.expires - effect.started
	local progress = duration > 0 and math.min(1, (clock - effect.started) / duration) or 1
	-- Begin above the battlefield so the strike has an observable approach rather
	-- than appearing at the cursor. The side is chosen once when the meteor is
	-- launched, keeping its angle consistent while allowing either approach.
	local direction = effect.approachDirection or -1
	local startX = effect.x + direction * 270
	local startY = -110
	local meteorX = startX + (effect.x - startX) * progress
	local meteorY = startY + (effect.y - startY) * progress
	local trailX = meteorX - (effect.x - startX) * .15
	local trailY = meteorY - (effect.y - startY) * .15
	local pulse = .8 + .2 * sin(clock * 18)
	local flightX, flightY = effect.x - startX, effect.y - startY
	local flightLength = sqrt(flightX * flightX + flightY * flightY)
	local unitX, unitY = flightX / flightLength, flightY / flightLength
	local perpendicularX, perpendicularY = -unitY, unitX

	lg.setColor(1, .22, .04, .22)
	lg.setLineWidth(41)
	lg.line(trailX, trailY, meteorX, meteorY)
	lg.setColor(1, .62, .12, .7)
	lg.setLineWidth(17)
	lg.line(trailX, trailY, meteorX, meteorY)
	-- Loose embers make the trail feel like burning debris rather than a static
	-- beam. Hash noise gives each ember its own stable sideways drift.
	for i = 1, 9 do
		local distance = 24 + i * 10 + (clock * 75 + i * 7) % 12
		local drift = (hashNoise(i, effect.started, 17) * 2 - 1) * (5 + i * .7)
		local emberX = meteorX - unitX * distance + perpendicularX * drift
		local emberY = meteorY - unitY * distance + perpendicularY * drift
		local emberRadius = 2 + hashNoise(i, effect.started, 29) * 3
		lg.setColor(1, .25, .03, .45)
		lg.circle("fill", emberX, emberY, emberRadius * 1.8)
		lg.setColor(1, .78, .18, .9)
		lg.circle("fill", emberX, emberY, emberRadius)
	end
	lg.setColor(1, .9, .48, .95)
	lg.circle("fill", meteorX, meteorY, 30 * pulse)
	lg.setColor(.24, .12, .1, 1)
	lg.circle("fill", meteorX, meteorY, 18)

	lg.setColor(1, .28, .08, .14 + progress * .14)
	lg.circle("fill", effect.x, effect.y, effect.radius * (.84 + .08 * pulse))
	lg.setColor(1, .5, .12, .72)
	lg.setLineWidth(2)
	lg.circle("line", effect.x, effect.y, effect.radius)
end

local function drawAbilityPreview()
	local active, clock = Abilities.getActive()
	for _, activeEffect in ipairs(active) do
		if activeEffect.kind == "meteor_incoming" then
			drawIncomingMeteor(activeEffect, clock)
		end
		local def = activeEffect.abilityId and AbilityDefs[activeEffect.abilityId]
		local sustained = def and def.sustained
		local remaining = activeEffect.expires - clock
		local alpha = Effects.expirationPulse(remaining, clock)
		local color = (def and def.target and def.target.color) or COLOR_ACTIVE_FALLBACK
		if sustained and sustained.area and activeEffect.x then
			lg.setColor(color[1], color[2], color[3], .16 * alpha)
			lg.circle("fill", activeEffect.x, activeEffect.y, activeEffect.radius)
			lg.setColor(color[1], color[2], color[3], .8 * alpha)
			lg.setLineWidth(2)
			lg.circle("line", activeEffect.x, activeEffect.y, activeEffect.radius)
		end
		if sustained and sustained.entityMarker then
			local entities, entityCount = activeEffect.towers, activeEffect.towers and #activeEffect.towers or 0
			if not entities and def.target and def.target.entities == "enemies" then
				entities, entityCount = Abilities.getEntitiesInActiveArea(activeEffect, "enemies")
			end
			for i = 1, entityCount do drawEntityMarker(entities[i], color, alpha, 21) end
		end
	end

	local targeting = State.abilityTargeting
	if not (targeting and targeting.x) then return end
	local preview = Abilities.getTargetPreview(targeting.x, targeting.y)
	if not preview then return end
	local effect, target = preview.effect, preview.def.target
	local color = preview.valid and (target and target.color or COLOR_PREVIEW_FALLBACK) or COLOR_PREVIEW_INVALID
	if effect.radius then
		lg.setColor(color[1], color[2], color[3], .2)
		lg.circle("fill", targeting.x, targeting.y, effect.radius)
		lg.setColor(color[1], color[2], color[3], 1)
		lg.setLineWidth(2)
		lg.circle("line", targeting.x, targeting.y, effect.radius)
	end
	for i = 1, preview.count do drawEntityMarker(preview.affected[i], color, 1, 23) end
end

local function drawGrid()
	local fade = State.placingFade or 0
	if fade == 0 then return end

	lg.setColor(colorGrid[1], colorGrid[2], colorGrid[3], colorGrid[4] * fade)

	for x = 0, gridW do
		lg.line(x * tile, 0, x * tile, gridH * tile)
	end

	for y = 0, gridH do
		lg.line(0, y * tile, gridW * tile, y * tile)
	end
end

return {
	drawGrass = drawGrass,
	drawWater = drawWater,
	drawPath = drawPath,
	drawScatter = drawScatter,
	drawAnimatedScatter = drawAnimatedScatter,
	drawGrid = drawGrid,
	drawWorld = drawWorld,
	drawAbilityPreview = drawAbilityPreview,
	updatePathColor = updatePathColor,
	updateGrassColor = updateGrassColor,
	updateWaterColor = updateWaterColor,
}
