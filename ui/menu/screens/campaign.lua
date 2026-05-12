local Sound = require("systems.sound")
local Difficulty = require("systems.difficulty")
local Fonts = require("core.fonts")
local Theme = require("core.theme")
local State = require("core.state")
local Save = require("core.save")
local Maps = require("world.map_defs")
local MapPreviewCache = require("world.map_preview_cache")
local Camera = require("core.camera")
local Text = require("ui.text")
local Button = require("ui.button")
local Medals = require("ui.medals")
local Backdrop = require("scenes.backdrop")
local Steam = require("core.steam")
local L = require("core.localization")

local lg = love.graphics
local floor = math.floor
local format = string.format

local Screen = {}

-- Colors
local colorText = Theme.ui.text
local colorShadow = Theme.ui.shadow
local colorDim = Theme.ui.screenDim
local colorBackdrop = Theme.ui.backdrop
local colorHover = {0.94, 0.94, 0.94}
local colorEnabled = {0.88, 0.88, 0.88}
local colorDisabled = {0.65, 0.65, 0.65}
local colorOutline = Theme.outline.color

-- Layout
local outlineW = Theme.outline.width
local baseRadius = 6 * 3
local outerRadius = baseRadius + outlineW * 0.5
local innerRadius = baseRadius - outlineW * 0.25

local PAD_PREVIEW = 44
local PAD_TITLE = 60
local PAD_META = 18
local TITLE_OFFSET = -22

local paddingX = 28
local paddingY = 28

local btnW = 240
local btnH = 42
local gap = 62

-- Arrow navigation
local ARROW_SIZE = 20
local PATH_TRIM_START = 34
local PATH_TRIM_END = 72

-- State
local campaignButtons = {}
local pulseTime = 0
local DIFFICULTY_ORDER = {"easy", "normal", "hard"}

local function getDifficultyIndex(key)
	for i, difficultyKey in ipairs(DIFFICULTY_ORDER) do
		if difficultyKey == key then
			return i
		end
	end

	return 2
end

local function cycleDifficulty(dir)
	local current = Save.data.settings.difficulty or Difficulty.default
	local index = getDifficultyIndex(current)
	local nextIndex = index + dir

	if nextIndex < 1 then
		nextIndex = #DIFFICULTY_ORDER
	elseif nextIndex > #DIFFICULTY_ORDER then
		nextIndex = 1
	end

	local nextDifficulty = DIFFICULTY_ORDER[nextIndex]

	Save.data.settings.difficulty = nextDifficulty
	Difficulty.set(nextDifficulty)
	Save.flush()
	Sound.play("uiMove")
end

local function difficultyButtonLabel()
	local current = Save.data.settings.difficulty or Difficulty.default

	return format("%s: %s", L("settings.difficulty"), L("difficulty." .. current))
end

-- Helpers
local function isMapLocked(i)
	return not Save.isMapUnlocked(i, Maps[i].id)
end

local function drawPathCurrent(entry, previewX, previewY, pw, ph, pulseT)
	local path = entry.pathWorld
	if not path or #path < 2 then return end

	local function toScreen(wx, wy)
		-- same logic as MapRender
		local winW = entry.winW or love.graphics.getWidth()
		local winH = entry.winH or love.graphics.getHeight()

		local sx = pw / winW
		local sy = ph / winH

		local z = entry.camScale or Camera.wscale

		local mapW = entry.mapW
		local mapH = entry.mapH

		local cx = mapW * 0.5
		local cy = mapH * 0.5

		local camWX = cx - (winW / (2 * z))
		local camWY = cy - (winH / (2 * z))

		-- apply camera transform
		local screenX = (wx - camWX) * z
		local screenY = (wy - camWY) * z

		-- apply canvas scaling
		screenX = screenX * sx
		screenY = screenY * sy

		return previewX + screenX, previewY + screenY
	end

	-- Precompute segment lengths
	local lengths = {}
	local points = {}
	local totalLen = 0

	for i = 1, #path do
		local px, py = toScreen(path[i][1], path[i][2])
		points[i] = {px, py}
	end

	for i = 1, #points - 1 do
		local x1, y1 = points[i][1], points[i][2]
		local x2, y2 = points[i + 1][1], points[i + 1][2]

		local dx = x2 - x1
		local dy = y2 - y1
		local len = math.sqrt(dx*dx + dy*dy)

		lengths[i] = len
		totalLen = totalLen + len
	end

	if totalLen <= 0 then return end

	-- Animate along path
	local speed = 140
	local trimStart = math.min(PATH_TRIM_START, totalLen * 0.45)
	local trimEnd = math.min(PATH_TRIM_END, totalLen * 0.45)
	local animLen = totalLen - trimStart - trimEnd
	if animLen <= 0 then
		return
	end

	local dist = trimStart + ((pulseT * speed) % animLen)
	local tailDist = 55
	local tailMaxAlpha = 0.28
	local fadeWindow = math.min(36, animLen * 0.2)
	local fadeIn = 1
	local fadeOut = 1

	if fadeWindow > 0 then
		fadeIn = math.min(1, (dist - trimStart) / fadeWindow)
		fadeOut = math.min(1, (trimStart + animLen - dist) / fadeWindow)
	end

	local headAlphaScale = math.min(fadeIn, fadeOut)

	local acc = 0

	for i = 1, #lengths do
		local segLen = lengths[i]

		if dist <= acc + segLen then
			local t = (dist - acc) / segLen

			local x1, y1 = points[i][1], points[i][2]
			local x2, y2 = points[i + 1][1], points[i + 1][2]

			local px = x1 + (x2 - x1) * t
			local py = y1 + (y2 - y1) * t

			-- Tail glow along the travelled section for a subtle routing cue.
			local tail = 0

			while tail < tailDist do
				local trailDist = math.max(trimStart, dist - tail)

				local trailAcc = 0
				local trailX, trailY = px, py

				for seg = 1, #lengths do
					local trailSegLen = lengths[seg]

					if trailDist <= trailAcc + trailSegLen then
						local trailT = (trailDist - trailAcc) / trailSegLen
						local tx1, ty1 = points[seg][1], points[seg][2]
						local tx2, ty2 = points[seg + 1][1], points[seg + 1][2]
						trailX = tx1 + (tx2 - tx1) * trailT
						trailY = ty1 + (ty2 - ty1) * trailT
						break
					end

					trailAcc = trailAcc + trailSegLen
				end

				local fade = 1 - (tail / tailDist)
				local alpha = tailMaxAlpha * fade * fade * headAlphaScale
				local radius = 4 + fade * 2
				lg.setColor(1, 1, 1, alpha)
				lg.circle("fill", trailX, trailY, radius)
				tail = tail + 8
			end

			-- Core
			lg.setColor(1, 1, 1, 0.9 * headAlphaScale)
			lg.circle("fill", px, py, 3)

			return
		end

		acc = acc + segLen
	end
end

local function pointInTriangle(px, py, ax, ay, bx, by, cx, cy)
	local function sign(px, py, ax, ay, bx, by)
		return (px - bx) * (ay - by) - (ax - bx) * (py - by)
	end

	local b1 = sign(px, py, ax, ay, bx, by) < 0
	local b2 = sign(px, py, bx, by, cx, cy) < 0
	local b3 = sign(px, py, cx, cy, ax, ay) < 0

	return (b1 == b2) and (b2 == b3)
end

local function resolveArrowColor(enabled, hover)
	if not enabled then
		return colorDisabled
	end

	if hover then
		return colorHover
	end

	return colorEnabled
end

local function drawTriangleWithShadow(points, color)
	-- Shadow
	lg.setColor(colorShadow)
	lg.polygon("fill", points[1] + 1, points[2] + 1, points[3] + 1, points[4] + 1, points[5] + 1, points[6] + 1)

	-- Main triangle
	lg.setColor(color)
	lg.polygon("fill", unpack(points))
end

local function getMapStats(mapId)
	local stats = Save.data.mapStats

	return stats and stats[mapId]
end

local function getCompletionString(mapId)
	local s = getMapStats(mapId)

	if not s then
		return nil
	end

	if s.completedDifficulty then
		local diff = L("difficulty." .. s.completedDifficulty)

		return L("campaign.completedBest", diff, s.bestWave or 0)
	end

	if s.bestWave and s.bestWave > 0 then
		return L("campaign.best", s.bestWave)
	end

	return nil
end

-- Load
function Screen.load()
	campaignButtons = {
		{
			id = "difficulty",
			label = difficultyButtonLabel(),
			w = btnW,
			h = btnH,
			onClick = function()
				cycleDifficulty(1)
			end
		},

		{
			id = "play",
			label = L("menu.play"),
			w = btnW,
			h = btnH,
			onClick = function()
				if isMapLocked(State.mapIndex) then
					Sound.play("uiError")
					return
				end

				Sound.play("uiConfirm")

				State.worldMapIndex = State.mapIndex
				State.mode = "game"
				Backdrop.stop()
				Difficulty.set(Save.data.settings.difficulty)
				resetGame()
				Sound.playMusic("gameplay")
			end
		},

		{
			id = "back",
			label = L("menu.back"),
			w = btnW,
			h = btnH,
			onClick = function()
				State.mode = "menu"
				Steam.setRichPresence(L("presence.menu"))
				Sound.play("uiBack")
			end
		}
	}
end

function Screen.update(dt)
	pulseTime = pulseTime + dt

	local sw, sh = lg.getDimensions()
	local cx = floor(sw * 0.5)

	Backdrop.update(dt)
	Medals.update(dt)

	local index = State.mapIndex
	local map = Maps[index]
	local entry = MapPreviewCache.get(map.id)

	if not entry then
		return
	end

	local preview = entry.canvas
	local pw, ph = preview:getWidth(), preview:getHeight()

	-- Layout
	local previewBlockH = ph
	local titleBlockH = PAD_PREVIEW + PAD_TITLE + PAD_META
	local buttonsBlockH = (#campaignButtons - 1) * gap + campaignButtons[1].h
	local contentH = previewBlockH + titleBlockH + buttonsBlockH

	local boxW = pw + paddingX * 2
	local boxH = contentH + paddingY * 2
	local boxY = floor(sh * 0.5 - boxH * 0.5)

	local previewY = boxY + paddingY
	local textY = previewY + ph + PAD_PREVIEW
	local buttonsStartY = textY + PAD_TITLE + PAD_META

	-- Buttons
	for i, btn in ipairs(campaignButtons) do
		btn.x = cx - btn.w * 0.5
		btn.y = buttonsStartY + (i - 1) * gap
		btn.enabled = (btn.id ~= "play") or not isMapLocked(State.mapIndex)
		if btn.id == "difficulty" then
			btn.label = difficultyButtonLabel()
		end

		Button.update(btn, love.mouse.getPosition(), dt)
	end
end

function Screen.draw()
	local sw, sh = lg.getDimensions()

	Backdrop.draw()

	local index = State.mapIndex
	local map = Maps[index]
	local mapCount = #Maps
	local entry = MapPreviewCache.get(map.id)

	if not entry then
		return
	end

	local preview = entry.canvas
	local pw, ph = preview:getWidth(), preview:getHeight()

	local cx = floor(sw * 0.5)

	-- Layout
	local previewBlockH = ph
	local titleBlockH = PAD_PREVIEW + PAD_TITLE + PAD_META
	local buttonsBlockH = (#campaignButtons - 1) * gap + campaignButtons[1].h

	local contentH = previewBlockH + titleBlockH + buttonsBlockH
	local boxW = pw + paddingX * 2
	local boxH = contentH + paddingY * 2

	local boxX = cx - boxW * 0.5
	local boxY = floor(sh * 0.5 - boxH * 0.5)

	-- Dim background
	lg.setColor(colorDim)
	lg.rectangle("fill", 0, 0, sw, sh)

	-- Panel
	lg.setColor(colorOutline)
	lg.rectangle("fill", boxX - outlineW, boxY - outlineW, boxW + outlineW * 2, boxH + outlineW * 2, outerRadius)

	lg.setColor(colorBackdrop)
	lg.rectangle("fill", boxX, boxY, boxW, boxH, innerRadius)

	-- Preview
	local previewX = cx - pw * 0.5
	local previewY = boxY + paddingY

	local locked = isMapLocked(index)
	local alpha = locked and 0.35 or 1.0

	lg.setColor(1, 1, 1, alpha)

	lg.draw(preview, previewX, previewY)

	drawPathCurrent(entry, previewX, previewY, pw, ph, pulseTime)

	-- Completion medals
	local stats = getMapStats(map.id)
	local count = stats and stats.completedDifficulty and Medals.getCount(stats.completedDifficulty) or 0

	local medalR = 9
	local medalGap = 10
	local insetX = 22
	local insetY = 20
	local platePadX = 10
	local platePadY = 8

	local clusterW, clusterH = Medals.getClusterSize(medalR, medalGap)

	local plateX = previewX + insetX - platePadX
	local plateY = previewY + insetY - platePadY
	local plateW = clusterW + platePadX * 2
	local plateH = clusterH + platePadY * 2

	lg.setColor(colorDim)
	lg.rectangle("fill", plateX, plateY, plateW, plateH, 8, 8)

	Medals.draw(previewX + insetX, previewY + insetY, count, medalR, medalGap)

	--[[ Completion stats
	local statText = getCompletionString(map.id)

	if statText then
		local pad = 8
		local offsetX = 12 -- move right
		local offsetY = 4 -- move up

		local font = Fonts.get("ui")

		Fonts.set("ui")

		local tw = font:getWidth(statText)
		local th = 16

		local bx = previewX + pad + offsetX
		local by = previewY + ph - th - pad * 2 - offsetY
		local bw = tw + pad * 2
		local bh = th + pad * 2

		-- Backdrop
		lg.setColor(colorDim)
		lg.rectangle("fill", bx - pad, by - pad, bw, bh, 8, 8)

		-- Text
		lg.setColor(colorText)
		lg.print(statText, bx, by)
	end]]

	Fonts.set("title")

	-- Frame
	lg.setColor(colorOutline)
	lg.setLineWidth(3)
	lg.rectangle("line", previewX, previewY, pw, ph)
	lg.setLineWidth(1)

	-- Locked overlay
	if locked then
		lg.setColor(0.01, 0.01, 0.01, 0.45)
		lg.rectangle("fill", previewX, previewY, pw, ph, 12, 12)

		lg.setColor(colorText)
		Text.printfShadow(L("campaign.locked"), previewX, previewY + ph * 0.5 - 16, pw, "center")
	end

	local bandY = previewY + ph + PAD_PREVIEW
	local textY = bandY + TITLE_OFFSET

	-- Arrows
	local leftEnabled = State.mapIndex > 1
	local rightEnabled = State.mapIndex < #Maps and not isMapLocked(State.mapIndex + 1)

	local arrowY = textY + 28
	local size = ARROW_SIZE

	-- Left
	do
		local ax = boxX + paddingX + ARROW_SIZE * 2
		local hover = false
		local points = {ax + size * 0.5, arrowY - size, ax - size * 0.5, arrowY, ax + size * 0.5, arrowY + size}

		if leftEnabled then
			hover = pointInTriangle(love.mouse.getPosition(), unpack(points))
		end

		local color = resolveArrowColor(leftEnabled, hover)
		drawTriangleWithShadow(points, color)
	end

	-- Right
	do
		local ax = boxX + boxW - paddingX - ARROW_SIZE * 2
		local hover = false
		local points = {ax - size * 0.5, arrowY - size, ax + size * 0.5, arrowY, ax - size * 0.5, arrowY + size}

		if rightEnabled then
			hover = pointInTriangle(love.mouse.getPosition(), unpack(points))
		end

		local color = resolveArrowColor(rightEnabled, hover)
		drawTriangleWithShadow(points, color)
	end

	-- Title
	lg.setColor(colorText)
	Text.printfShadow(L(map.nameKey), 0, textY, sw, "center")

	Fonts.set("ui")

	Text.printfShadow(L("campaign.mapOf", index, mapCount), 0, textY + PAD_TITLE, sw, "center")

	-- Buttons
	local buttonsStartY = textY + PAD_TITLE + PAD_META

	Fonts.set("menu")

	for i, btn in ipairs(campaignButtons) do
		Button.draw(btn)
	end
end

function Screen.keypressed(key)
	if key == "left" then
		if State.mapIndex > 1 then
			State.mapIndex = State.resolveMapIndex(State.mapIndex - 1)
			Sound.play("uiMove")
		else
			Sound.play("uiError")
		end
	elseif key == "right" then
		if State.mapIndex < #Maps and not isMapLocked(State.mapIndex + 1) then
			State.mapIndex = State.resolveMapIndex(State.mapIndex + 1)
			Sound.play("uiMove")
		else
			Sound.play("uiError")
		end
	elseif key == "up" or key == "down" then
		cycleDifficulty(1)
	elseif key == "escape" then
		State.mode = "menu"
		Steam.setRichPresence(L("presence.menu"))
		Sound.play("uiBack")
	end
end

function Screen.mousepressed(x, y, button)
	if button == 1 then
		local sw, sh = lg.getDimensions()
		local index = State.mapIndex
		local map = Maps[index]
		local entry = MapPreviewCache.get(map.id)

		if not entry then
			return
		end

		local preview = entry.canvas
		local pw, ph = preview:getWidth(), preview:getHeight()

		local cx = floor(sw * 0.5)

		-- Layout
		local previewBlockH = ph
		local titleBlockH = PAD_PREVIEW + PAD_TITLE + PAD_META
		local buttonsBlockH = (#campaignButtons - 1) * gap + campaignButtons[1].h
		local contentH = previewBlockH + titleBlockH + buttonsBlockH

		local boxW = pw + paddingX * 2
		local boxH = contentH + paddingY * 2
		local boxX = cx - boxW * 0.5
		local boxY = floor(sh * 0.5 - boxH * 0.5)

		local previewX = cx - pw * 0.5
		local previewY = boxY + paddingY

		local bandY = previewY + ph + PAD_PREVIEW
		local textY = bandY + TITLE_OFFSET
		local arrowY = textY + 28

		-- Left
		if index > 1 then
			local ax = boxX + paddingX + ARROW_SIZE * 2

			if pointInTriangle(x, y, ax + ARROW_SIZE * 0.5, arrowY - ARROW_SIZE, ax - ARROW_SIZE * 0.5, arrowY, ax + ARROW_SIZE * 0.5, arrowY + ARROW_SIZE) then
				State.mapIndex = State.resolveMapIndex(index - 1)
				Sound.play("uiMove")

				return true
			end
		end

		-- Right
		if index < #Maps and not isMapLocked(index + 1) then
			local ax = boxX + boxW - paddingX - ARROW_SIZE * 2

			if pointInTriangle(x, y, ax - ARROW_SIZE * 0.5, arrowY - ARROW_SIZE, ax + ARROW_SIZE * 0.5, arrowY, ax - ARROW_SIZE * 0.5, arrowY + ARROW_SIZE) then
				State.mapIndex = State.resolveMapIndex(index + 1)
				Sound.play("uiMove")

				return true
			end
		end
	end

	-- Buttons
	for _, btn in ipairs(campaignButtons) do
		if Button.mousepressed(btn, x, y, button) then
			return true
		end
	end
end

function Screen.mousereleased(x, y, button)
	for _, btn in ipairs(campaignButtons) do
		if Button.mousereleased(btn, x, y, button) then
			return true
		end
	end
end

local function canMoveLeft()
	return State.mapIndex > 1
end

function Screen.resize(w, h)
	MapPreviewCache.buildAll(520, 312)
	Backdrop.start()
end

return Screen
