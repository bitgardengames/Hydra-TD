local Constants = require("core.constants")
local Theme = require("core.theme")
local State = require("core.state")
local Map = require("world.map")
local ScatterCommon = require("world.scatter_common")
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

-- Gestures should read as occasional bits of environmental life, rather than as
-- another source of combat motion.  Each cactus gets its own values from the
-- placement RNG so drawing never has to sample randomness.
local MIN_IDLE_INTERVAL = 5.5
local IDLE_INTERVAL_VARIANCE = 4.0
local MIN_GESTURE_DURATION = 0.34
local GESTURE_DURATION_VARIANCE = 0.20
local WIGGLES_PER_GESTURE = 2

local function rand(a, b)
	return rng:random(a, b)
end

local function getCactusStyles(targetMap)
	local world = targetMap and targetMap.biome and targetMap.biome.world
	local cactus = world and world.cactus

	return cactus and cactus.styles
end

Cactus.list = {}

function Cactus.clear()
	Cactus.list = {}
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

function Cactus.generate(targetMap, mapIndex, list, treeOccupied)
	targetMap = targetMap or Map.map
	mapIndex = mapIndex or State.worldMapIndex
	list = list or {}

	local seed = 8888 + mapIndex * 977
	rng:setSeed(seed)

	local count = 10 + rand(0, 6)
	local styles = getCactusStyles(targetMap)

	local function canPlace(gx, gy)
		return not ScatterCommon.isNearPath(targetMap.isPath, gx, gy)
			and not Map.isBlockedForMap(targetMap, gx, gy)
			and not (treeOccupied and treeOccupied[gx] and treeOccupied[gx][gy])
	end

	local function create(gx, gy)
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
		local animInterval = MIN_IDLE_INTERVAL + rand() * IDLE_INTERVAL_VARIANCE

		return {
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

			idlePhase = rand() * animInterval,
			idleInterval = animInterval,
			idleDuration = MIN_GESTURE_DURATION + rand() * GESTURE_DURATION_VARIANCE,
			motionDirection = rand() < 0.5 and -1 or 1,
		}

	end

	ScatterCommon.populate(list, count, rand, GRID_W, GRID_H, canPlace, create)

	table.sort(list, function(a, b)
		return a.y < b.y
	end)
	return list
end

local function smoothstep(t)
	t = math.max(0, math.min(1, t))
	return t * t * (3 - 2 * t)
end

local function gestureAmount(cactus, presentationTime)
	local interval = cactus.idleInterval
	local duration = cactus.idleDuration
	if not interval or not duration or interval <= 0 or duration <= 0 then
		return 0
	end

	local localTime = ((presentationTime or 0) + (cactus.idlePhase or 0)) % interval
	if localTime >= duration then
		return 0
	end

	-- Repeat the smooth rise and fall twice within the same short active window.
	-- Keeping the interval unchanged ensures that gestures remain rare.
	local wiggleProgress = (localTime / duration) * WIGGLES_PER_GESTURE
	local cycleProgress = wiggleProgress % 1
	return smoothstep(math.min(cycleProgress * 2, (1 - cycleProgress) * 2))
end

function Cactus.draw(list, targetMap, presentationTime)
	list = list or Cactus.list
	if #list == 0 then
		return
	end

	local styles = getCactusStyles(targetMap or Map.map)
	local flowerColor = {0.95, 0.45, 0.55}

	for i = 1, #list do
		local c = list[i]
		local style = styles[c.style]

		local x = c.x
		local baseY = c.y
		local s = c.scale
		local gesture = gestureAmount(c, presentationTime)
		local direction = c.motionDirection or 1

		local h, w

		if c.shape == "round" then
			h = TILE * (0.32 + c.heightBias * 0.10) * s
			w = TILE * (0.34 + c.widthBias * 0.12) * s
		else
			h = TILE * (0.62 + c.heightBias * 0.40) * s
			w = TILE * (0.15 + c.widthBias * 0.05) * s
		end

		-- Round cacti are much shorter than their tall counterparts, so keep their
		-- ground shadow tight to the body instead of using the full sprite width.
		local radius = c.shape == "round" and w * 0.5 or w
		lg.setColor(0, 0, 0, shA)
		lg.ellipse("fill", x, baseY + 1, radius * shW, radius * shH)

		if c.shape == "round" then
			-- Anchor the squash at the soil line.  A small opposing horizontal
			-- stretch preserves the body's visual volume without lifting its base.
			lg.push()
			lg.translate(x, baseY)
			lg.scale(1 + gesture * 0.035, 1 - gesture * 0.05)
			lg.translate(-x, -baseY)

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

			lg.pop()
		else
			local function drawArm(a)
				local armW = w * (0.55 + a.width * 0.20)
				local armH = h * (0.38 + a.height * 0.30)

				local edgeX = x + (w * 0.5) * a.side
				local armX = edgeX + (w * (0.16 + a.offset * 0.34)) * a.side
				local armY = baseY - h * (0.44 + a.y * 0.32)

				-- Rotate around the point where the arm meets the trunk.  Opposite
				-- arms naturally fan in opposite directions, while motionDirection
				-- keeps the character of each cactus deterministic.
				lg.push()
				lg.translate(edgeX, armY)
				lg.rotate(a.side * direction * gesture * 0.045)
				lg.translate(-edgeX, -armY)
				drawPart(armX, armY, armW, armH, style)
				lg.pop()
			end

			if c.armMode >= 1 then
				drawArm(c.arm1)
			end
			if c.armMode >= 2 then
				drawArm(c.arm2)
			end

			drawPart(x, baseY, w, h, style)

			if c.hasFlower then
				local top = baseY - h
				drawFlower(x, top - 3.5 * s, 0.7 * s, flowerColor)
			end
		end
	end
end

return Cactus
