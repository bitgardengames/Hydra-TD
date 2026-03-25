local Constants = require("core.constants")
local Sound = require("systems.sound")
local Difficulty = require("systems.difficulty")
local Fonts = require("core.fonts")
local Theme = require("core.theme")
local State = require("core.state")
local Save = require("core.save")
local MapMod = require("world.map")
local Maps = require("world.map_defs")
local MapPreviewCache = require("world.map_preview_cache")
local Text = require("ui.text")
local Button = require("ui.button")
local Medals = require("ui.medals")
local Backdrop = require("scenes.backdrop")
local Cursor = require("core.cursor")
local Steam = require("core.steam")
local L = require("core.localization")

local lg = love.graphics
local floor = math.floor
local format = string.format
local upper = string.upper

local Screen = {}

-- Colors
local colorText = Theme.ui.text
local colorPanel = Theme.ui.panel
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
local PAD_ACTION = 26
local TITLE_OFFSET = -22

local paddingX = 28
local paddingY = 28
local corner = 18

local btnW = 240
local btnH = 42
local gap = 62

-- Arrow navigation
local ARROW_SIZE = 20
local ARROW_OFFSET = 48
local ARROW_ALPHA = 0.85
local ARROW_HOVER = 1.0

-- State
local campaignButtons = {}

-- Helpers
local function isMapLocked(i)
	return not Save.isMapUnlocked(i, Maps[i].id)
end

local function drawPathCurrent(entry, previewX, previewY, pw, ph, pulseT)
	local path = entry.pathWorld
	if not path or #path < 2 then return end

	local mapW = Constants.GRID_W * Constants.TILE
	local mapH = Constants.GRID_H * Constants.TILE

	local function toScreen(entry, previewX, previewY, pw, ph, wx, wy)
		-- same logic as MapRender
		local winW, winH = love.graphics.getDimensions()

		local sx = pw / winW
		local sy = ph / winH

		local z = Camera.wscale

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

		return previewX + screenX,
			   previewY + screenY
	end

	-- Precompute segment lengths
	local lengths = {}
	local totalLen = 0

	for i = 1, #path - 1 do
		local x1, y1 = toScreen(entry, previewX, previewY, pw, ph, path[i][1], path[i][2])
		local x2, y2 = toScreen(entry, previewX, previewY, pw, ph, path[i+1][1], path[i+1][2])

		local dx = x2 - x1
		local dy = y2 - y1
		local len = math.sqrt(dx*dx + dy*dy)

		lengths[i] = len
		totalLen = totalLen + len
	end

	if totalLen <= 0 then return end

	-- Animate along path
	local speed = 120
	local dist = (pulseT * speed) % totalLen

	local acc = 0

	for i = 1, #lengths do
		local segLen = lengths[i]

		if dist <= acc + segLen then
			local t = (dist - acc) / segLen

			local x1, y1 = toScreen(entry, previewX, previewY, pw, ph, path[i][1], path[i][2])
			local x2, y2 = toScreen(entry, previewX, previewY, pw, ph, path[i+1][1], path[i+1][2])

			local px = x1 + (x2 - x1) * t
			local py = y1 + (y2 - y1) * t

			-- Glow
			lg.setColor(1, 1, 1, 0.2)
			lg.circle("fill", px, py, 7)

			-- Core
			lg.setColor(1, 1, 1, 0.9)
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
		local diff = s.completedDifficulty:gsub("^%l", upper)

		return format("Completed: %s • Best: %d", diff, s.bestWave or 0)
	end

	if s.bestWave and s.bestWave > 0 then
		return format("Best: %d", s.bestWave)
	end

	return nil
end

-- Load
function Screen.load()
	campaignButtons = {
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
	local sw, sh = lg.getDimensions()
	local cx = floor(sw * 0.5)

	Backdrop.update(dt)
	Medals.update(dt)

	--Screen.pulseT = (Screen.pulseT or 0) + dt

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

		Button.update(btn, Cursor.x, Cursor.y, dt)
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

	--drawPathCurrent(entry, previewX, previewY, pw, ph, Screen.pulseT or 0)

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
			hover = pointInTriangle(Cursor.x, Cursor.y, unpack(points))
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
			hover = pointInTriangle(Cursor.x, Cursor.y, unpack(points))
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

-- Gamepad halpers
local function canMoveRight()
	return State.mapIndex < #Maps and not isMapLocked(State.mapIndex + 1)
end

local function moveLeft()
	if canMoveLeft() then
		State.mapIndex = State.resolveMapIndex(State.mapIndex - 1)
		Sound.play("uiMove")
	else
		Sound.play("uiError")
	end
end

local function moveRight()
	if canMoveRight() then
		State.mapIndex = State.resolveMapIndex(State.mapIndex + 1)
		Sound.play("uiMove")
	else
		Sound.play("uiError")
	end
end

local function pressPlay()
	for _, btn in ipairs(campaignButtons) do
		if btn.id == "play" then
			if btn.enabled then
				btn.onClick()
			else
				Sound.play("uiError")
			end

			return
		end
	end
end

local function pressBack()
	for _, btn in ipairs(campaignButtons) do
		if btn.id == "back" then
			btn.onClick()

			return
		end
	end
end

function Screen.gamepadpressed(joystick, button)
	-- Hard disable cursor for this screen
	Cursor.disableVirtual()

	-- D-Pad navigation
	if button == "dpleft" then
		moveLeft()

		return true
	elseif button == "dpright" then
		moveRight()

		return true
	end

	-- Face buttons
	if button == "a" then
		pressPlay()

		return true
	end

	if button == "b" or button == "back" then
		pressBack()

		return true
	end
end

function Screen.resize(w, h)
	--MapPreviewCache.buildAll(520, 312)
end

return Screen