local Constants = require("core.constants")
local Sound = require("systems.sound")
local Fonts = require("core.fonts")
local Theme = require("core.theme")
local State = require("core.state")
local Save = require("core.save")
local Maps = require("world.map_defs")
local Text = require("ui.text")
local Button = require("ui.button")
local Backdrop = require("scenes.backdrop")
local Cursor = require("core.cursor")
local Steam = require("core.steam")
local L = require("core.localization")

local lg = love.graphics
local floor = math.floor

local Screen = {}

-- Colors
local colorText = Theme.ui.text
local colorPath = Theme.terrain.path
local colorGrass = Theme.terrain.grass
local colorPanel = Theme.ui.panel
local colorShadow = Theme.ui.shadow
local colorDim = Theme.ui.screenDim
local colorBackdrop = Theme.ui.backdrop
local colorHover = {0.94, 0.94, 0.94}
local colorEnabled = {0.88, 0.88, 0.88}
local colorDisabled = {0.65, 0.65, 0.65}

-- Layout
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
local gap = 58

local PREVIEW_ZOOM = 1.3

-- Arrow navigation
local ARROW_SIZE = 20
local ARROW_OFFSET = 48
local ARROW_ALPHA = 0.85
local ARROW_HOVER = 1.0

-- State
local mapPreviews = {}
local campaignButtons = {}

-- Helpers
local function isMapLocked(i)
	return not Save.isMapUnlocked(i, Maps[i].id)
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

-- Map preview generation
local function buildMapPreview(mapDef)
	local w, h = 520, 312
	local canvas = lg.newCanvas(w, h)

	lg.setCanvas(canvas)
	lg.clear(0, 0, 0, 0)

	local tileW = w / Constants.GRID_W * PREVIEW_ZOOM
	local tileH = h / Constants.GRID_H * PREVIEW_ZOOM

	local mapW = Constants.GRID_W * tileW
	local mapH = Constants.GRID_H * tileH

	local offsetX = (w - mapW) * 0.5
	local offsetY = (h - mapH) * 0.5

	lg.setColor(colorGrass)
	lg.rectangle("fill", offsetX, offsetY, mapW, mapH)

	lg.setColor(colorPath)
	lg.setLineWidth(4 * PREVIEW_ZOOM)

	for i = 1, #mapDef.path - 1 do
		local ax, ay = mapDef.path[i][1], mapDef.path[i][2]
		local bx, by = mapDef.path[i + 1][1], mapDef.path[i + 1][2]

		lg.line(offsetX + (ax - 0.5) * tileW, offsetY + (ay - 0.5) * tileH, offsetX + (bx - 0.5) * tileW, offsetY + (by - 0.5) * tileH)
	end

	lg.setLineWidth(1)
	lg.setCanvas()

	return canvas
end

local function clearMapPreviews()
	for i, canvas in ipairs(mapPreviews) do
		if canvas and canvas.release then
			canvas:release()
		end

		mapPreviews[i] = nil
	end
end

local function rebuildMapPreviews()
	clearMapPreviews()

	for i, map in ipairs(Maps) do
		mapPreviews[i] = buildMapPreview(map)
	end
end

-- Load
function Screen.load()
	-- Build previews once
	rebuildMapPreviews()

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

	local index = State.mapIndex
	local preview = mapPreviews[index]
	local pw, ph = preview:getWidth(), preview:getHeight()

	-- Layout
	local previewBlockH = ph
	local titleBlockH = PAD_PREVIEW + PAD_TITLE + PAD_META
	local buttonsBlockH = (#campaignButtons - 1) * 52 + campaignButtons[1].h
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
		btn.y = buttonsStartY + (i - 1) * 52
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

	local preview = mapPreviews[index]
	local pw, ph = preview:getWidth(), preview:getHeight()

	local cx = floor(sw * 0.5)

	-- Layout
	local previewBlockH = ph
	local titleBlockH = PAD_PREVIEW + PAD_TITLE + PAD_META
	local buttonsBlockH = (#campaignButtons - 1) * 52 + campaignButtons[1].h

	local contentH = previewBlockH + titleBlockH + buttonsBlockH
	local boxW = pw + paddingX * 2
	local boxH = contentH + paddingY * 2

	local boxX = cx - boxW * 0.5
	local boxY = floor(sh * 0.5 - boxH * 0.5)

	-- Dim background
	lg.setColor(colorDim)
	lg.rectangle("fill", 0, 0, sw, sh)

	-- Panel
	lg.setColor(colorBackdrop)
	lg.rectangle("fill", boxX, boxY, boxW, boxH, corner, corner)

	-- Preview
	local previewX = cx - pw * 0.5
	local previewY = boxY + paddingY

	local locked = isMapLocked(index)
	local alpha = locked and 0.35 or 1.0

	lg.setColor(1, 1, 1, alpha)
	lg.draw(preview, previewX, previewY)

	-- Frame
	lg.setColor(colorBackdrop)
	lg.setLineWidth(2)
	lg.rectangle("line", previewX, previewY, pw, ph)
	lg.setLineWidth(1)

	-- Locked overlay
	if locked then
		lg.setColor(0.01, 0.01, 0.01, 0.45)
		lg.rectangle("fill", previewX, previewY, pw, ph, 12, 12)

		Fonts.set("title")

		lg.setColor(colorText)
		Text.printfShadow(L("campaign.locked"), previewX, previewY + ph * 0.5 - 16, pw, "center")
	end

	local bandY = previewY + ph + PAD_PREVIEW
	local textY = bandY + TITLE_OFFSET

	-- Arrows
	local leftEnabled  = State.mapIndex > 1
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
	Fonts.set("title")

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
			State.mapIndex = State.mapIndex - 1
			Sound.play("uiMove")
		else
			Sound.play("uiError")
		end
	elseif key == "right" then
		if State.mapIndex < #Maps and not isMapLocked(State.mapIndex + 1) then
			State.mapIndex = State.mapIndex + 1
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
		local preview = mapPreviews[index]
		local pw, ph = preview:getWidth(), preview:getHeight()

		local cx = floor(sw * 0.5)

		-- Layout
		local previewBlockH = ph
		local titleBlockH = PAD_PREVIEW + PAD_TITLE + PAD_META
		local buttonsBlockH = (#campaignButtons - 1) * 52 + campaignButtons[1].h
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
				State.mapIndex = index - 1
				Sound.play("uiMove")

				return true
			end
		end

		-- Right
		if index < #Maps and not isMapLocked(index + 1) then
			local ax = boxX + boxW - paddingX - ARROW_SIZE * 2

			if pointInTriangle(x, y, ax - ARROW_SIZE * 0.5, arrowY - ARROW_SIZE, ax + ARROW_SIZE * 0.5, arrowY, ax - ARROW_SIZE * 0.5, arrowY + ARROW_SIZE) then
				State.mapIndex = index + 1
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

local function canMoveLeft()
	return State.mapIndex > 1
end

-- Gamepad halpers
local function canMoveRight()
	return State.mapIndex < #Maps and not isMapLocked(State.mapIndex + 1)
end

local function moveLeft()
	if canMoveLeft() then
		State.mapIndex = State.mapIndex - 1
		Sound.play("uiMove")
	else
		Sound.play("uiError")
	end
end

local function moveRight()
	if canMoveRight() then
		State.mapIndex = State.mapIndex + 1
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
	rebuildMapPreviews()
end

return Screen