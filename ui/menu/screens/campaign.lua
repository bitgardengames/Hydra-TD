local Constants = require("core.constants")
local Sound = require("systems.sound")
local Fonts = require("core.fonts")
local Theme = require("core.theme")
local State = require("core.state")
local Save = require("core.save")
local Maps = require("world.map_defs")
local Text = require("ui.text")
local Cursor = require("core.cursor")
local Button = require("ui.button")
local L = require("core.localization")

local lg = love.graphics
local floor = math.floor

local Screen = {}

-- Colors
local colorText = Theme.ui.text
local colorPath = Theme.terrain.path
local colorGrass = Theme.terrain.grass
local colorPanel = Theme.ui.panel
local colorMenu = Theme.menu
local colorShadow = Theme.ui.shadow
local colorHover = {0.94, 0.94, 0.94}
local colorEnabled = {0.88, 0.88, 0.88}
local colorDisabled = {0.65, 0.65, 0.65}

-- Layout
local PAD_PREVIEW = 28
local PAD_TITLE = 54
local PAD_META = 18
local PAD_ACTION = 26

local PREVIEW_ZOOM = 1.3

-- Arrow navigation
local ARROW_SIZE = 26
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
	lg.polygon(
		"fill",
		points[1] + 1, points[2] + 1,
		points[3] + 1, points[4] + 1,
		points[5] + 1, points[6] + 1
	)

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
			w = 220,
			h = 42,
			onClick = function()
				if isMapLocked(State.mapIndex) then
					Sound.play("uiError")
					return
				end

				Sound.play("uiConfirm")
				State.mode = "game"
				resetGame()
			end
		},
		{
			id = "back",
			label = L("menu.back"),
			w = 220,
			h = 42,
			onClick = function()
				State.mode = "menu"
				Sound.play("uiBack")
			end
		}
	}
end

-- =====================================================
-- Update
-- =====================================================
function Screen.update(dt)
	local sw, sh = lg.getDimensions()
	local cx = floor(sw * 0.5)
	local startY = floor(sh * 0.38 + 260)
	local gap = 52

	for i, btn in ipairs(campaignButtons) do
		btn.x = cx - btn.w * 0.5
		btn.y = startY + (i - 1) * gap
		btn.enabled = (btn.id ~= "play") or not isMapLocked(State.mapIndex)

		Button.update(btn, Cursor.x, Cursor.y, dt)
	end
end

-- =====================================================
-- Draw
-- =====================================================
function Screen.draw()
	local sw, sh = lg.getDimensions()

	lg.setColor(colorMenu)
	lg.rectangle("fill", 0, 0, sw, sh)

	local index    = State.mapIndex
	local map      = Maps[index]
	local mapCount = #Maps

	local preview = mapPreviews[index]
	local pw, ph  = preview:getWidth(), preview:getHeight()

	local centerX = floor(sw * 0.5)
	local blockH  = ph + PAD_PREVIEW + PAD_TITLE + PAD_META + PAD_ACTION
	local pyTop   = floor(sh * 0.38 - blockH * 0.5)
	local centerY = pyTop + ph * 0.5

	-- Preview
	local locked = isMapLocked(index)
	local alpha  = locked and 0.35 or 1.0

	lg.setColor(1, 1, 1, alpha)
	lg.draw(preview, centerX - pw * 0.5, centerY - ph * 0.5)

	-- Frame
	lg.setColor(colorPanel)
	lg.rectangle(
		"line",
		centerX - pw * 0.5,
		centerY - ph * 0.5,
		pw, ph,
		6, 6
	)

	-- Locked overlay
	if locked then
		lg.setColor(0, 0, 0, 0.45)
		lg.rectangle(
			"fill",
			centerX - pw * 0.5,
			centerY - ph * 0.5,
			pw, ph,
			12, 12
		)

		lg.setColor(colorText)
		Fonts.set("title")
		Text.printfShadow(
			L("campaign.locked"),
			centerX - pw * 0.5,
			centerY - 14,
			pw,
			"center"
		)
	end

	-- Navigation arrows
	local leftEnabled  = State.mapIndex > 1
	local rightEnabled = State.mapIndex < #Maps and not isMapLocked(State.mapIndex + 1)

	local arrowY = centerY
	local size = ARROW_SIZE

	-- Left arrow
	do
		local cx = centerX - pw * 0.5 - ARROW_OFFSET
		local enabled = leftEnabled

		local points = {cx + size * 0.5, arrowY - size, cx - size * 0.5, arrowY, cx + size * 0.5, arrowY + size}

		local hover = false

		if enabled and Cursor.x then
			hover = pointInTriangle(Cursor.x, Cursor.y, points[1], points[2], points[3], points[4], points[5], points[6])
		end

		local color = resolveArrowColor(enabled, hover)

		drawTriangleWithShadow(points, color)
	end

	-- Right arrow
	do
		local cx = centerX + pw * 0.5 + ARROW_OFFSET
		local enabled = rightEnabled

		local points = {cx - size * 0.5, arrowY - size, cx + size * 0.5, arrowY, cx - size * 0.5, arrowY + size}

		local hover = false

		if enabled and Cursor.x then
			hover = pointInTriangle( Cursor.x, Cursor.y, points[1], points[2], points[3], points[4], points[5], points[6])
		end

		local color = resolveArrowColor(enabled, hover)

		drawTriangleWithShadow(points, color)
	end

	-- Text
	local textY = pyTop + ph + PAD_PREVIEW

	lg.setColor(colorText)
	Fonts.set("title")
	Text.printfShadow(L(map.nameKey), 0, textY, sw, "center")

	Fonts.set("ui")
	Text.printfShadow(
		L("campaign.mapOf", index, mapCount),
		0,
		textY + PAD_TITLE,
		sw,
		"center"
	)

	-- Buttons
	Fonts.set("menu")
	for _, btn in ipairs(campaignButtons) do
		Button.draw(btn)
	end
end

-- =====================================================
-- Input
-- =====================================================
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
		Sound.play("uiBack")
	end
end

function Screen.mousepressed(x, y, button)
	if button == 1 then
		local sw, sh = lg.getDimensions()
		local index = State.mapIndex
		local preview = mapPreviews[index]
		local pw, ph = preview:getWidth(), preview:getHeight()

		local centerX = floor(sw * 0.5)
		local blockH  = ph + PAD_PREVIEW + PAD_TITLE + PAD_META + PAD_ACTION
		local pyTop   = floor(sh * 0.38 - blockH * 0.5)
		local centerY = pyTop + ph * 0.5
		local size    = ARROW_SIZE

		-- Left arrow click
		if index > 1 then
			local cx = centerX - pw * 0.5 - ARROW_OFFSET
			if pointInTriangle(
				x, y,
				cx + size * 0.5, centerY - size,
				cx - size * 0.5, centerY,
				cx + size * 0.5, centerY + size
			) then
				State.mapIndex = index - 1
				Sound.play("uiMove")
				return true
			end
		end

		-- Right arrow click
		if index < #Maps and not isMapLocked(index + 1) then
			local cx = centerX + pw * 0.5 + ARROW_OFFSET
			if pointInTriangle(
				x, y,
				cx - size * 0.5, centerY - size,
				cx + size * 0.5, centerY,
				cx - size * 0.5, centerY + size
			) then
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