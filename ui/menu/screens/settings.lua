local Sound = require("systems.sound")
local Fonts = require("core.fonts")
local Theme = require("core.theme")
local State = require("core.state")
local Util = require("core.util")
local Save = require("core.save")
local Text = require("ui.text")
local Button = require("ui.button")
local Cursor = require("core.cursor")
local L = require("core.localization")

local lg = love.graphics
local floor = math.floor
local min = math.min
local max = math.max
local abs = math.abs

local Screen = {}

local colorText = Theme.ui.text
local colorMenu = Theme.menu

local LABEL_W   = 180
local SLIDER_W  = 160
local ROW_H     = 32
local ROW_PAD_Y = 6
local THUMB_R   = 6

local settingsCursor = 1
local rows = {}
local buttons = {}

local sliderRects = {}
local rowRects = {}
local draggingSlider = nil

local function drawUIMeter(label, color, value, x, y, selected, hovered, rowIndex)
	local t = max(0, min(1, value))

	-- Register full row hitbox
	rowRects[rowIndex] = {x = x - 24, y = y - ROW_PAD_Y, w = LABEL_W + SLIDER_W + 40, h = ROW_H}

	-- Highlight
	if selected or hovered then
		lg.setColor(1, 1, 1, selected and 0.10 or 0.06)
		lg.rectangle("fill", rowRects[rowIndex].x, rowRects[rowIndex].y, rowRects[rowIndex].w, rowRects[rowIndex].h, 6, 6)
	end

	if selected then
		lg.setColor(1, 1, 1, 1)
		Text.printShadow(">", x - 18, y)
	end

	-- Label
	Text.printShadow(label, x, y)

	local sliderX = x + LABEL_W
	local sliderY = y + ROW_PAD_Y

	-- Slider hitbox
	sliderRects[rowIndex] = {x = sliderX, y = sliderY, w = SLIDER_W, h = 8}

	-- Track
	lg.setColor(0, 0, 0, 0.35)
	lg.rectangle("fill", sliderX, sliderY, SLIDER_W, 8, 4, 4)

	-- Fill
	if value > 0 then
		lg.setColor(color)
		lg.rectangle("fill", sliderX, sliderY, SLIDER_W * t, 8, 4, 4)
	end

	-- Thumb
	local thumbX = sliderX + SLIDER_W * t
	local thumbY = sliderY + 4
	local thumbGrow = (hovered or draggingSlider == rowIndex) and 2 or 0

	-- Glow
	lg.setColor(color[1], color[2], color[3], 0.25)
	lg.circle("fill", thumbX, thumbY, THUMB_R + thumbGrow + 3)

	-- Core
	lg.setColor(1, 1, 1, 1)
	lg.circle("fill", thumbX, thumbY, THUMB_R + thumbGrow)

	lg.setColor(1, 1, 1, 1)
end

local function drawRow(row, selected, hovered, x, y, index)
	if row.type == "slider" then
		drawUIMeter(row.label, row.color, row.get(), x, y, selected, hovered, index)

	elseif row.type == "toggle" then
		rowRects[index] = {x = x - 24, y = y - ROW_PAD_Y, w = LABEL_W + SLIDER_W + 40, h = ROW_H}

		if selected or hovered then
			lg.setColor(1, 1, 1, selected and 0.10 or 0.06)
			lg.rectangle("fill", rowRects[index].x, rowRects[index].y, rowRects[index].w, rowRects[index].h, 6, 6)
		end

		if selected then
			lg.setColor(1, 1, 1, 1)
			Text.printShadow(">", x - 18, y)
		end

		Text.printShadow(string.format("%s: %s", row.label, row.get() and L("on") or L("off")), x, y)
	end
end

function Screen.load()
	settingsCursor = 1

	rows = {
		{
			id = "music",
			label = L("settings.music"),
			type = "slider",
			color = Theme.tower.shock,
			get = function() return Save.data.settings.musicVolume end,
			set = function(v)
				Save.data.settings.musicVolume = v
				Sound.setMusicVolume(v)
				Save.flush()
			end,
		},
		{
			id = "sfx",
			label = L("settings.sfx"),
			type = "slider",
			color = Theme.tower.cannon,
			get = function() return Save.data.settings.sfxVolume end,
			set = function(v)
				Save.data.settings.sfxVolume = v
				Sound.setSFXVolume(v)
				Save.flush()
			end,
		},
		{
			id = "fullscreen",
			label = L("settings.fullscreen"),
			type = "toggle",
			get = function() return love.window.getFullscreen() end,
			set = function(v)
				if v then
					love.window.setMode(0, 0, { fullscreen = true, fullscreentype = "desktop", vsync = 1 })
				else
					love.window.setMode(1280, 800, { fullscreen = false, resizable = true, vsync = 1 })
				end

				Save.data.settings.fullscreen = v
				require("core.camera").resize()
				Save.flush()
			end,
		},
	}

	buttons = {
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

function Screen.update(dt)
	rowRects = {}

	local sw, sh = lg.getDimensions()
	local cx = floor(sw * 0.5)
	local startY = floor(sh * 0.55)

	for i, btn in ipairs(buttons) do
		btn.x = cx - btn.w * 0.5
		btn.y = startY + (#rows * 44) + 24 + (i - 1) * 52

		Button.update(btn, Cursor.x, Cursor.y, dt)
	end

	-- Hover selects row
	for i, rect in pairs(rowRects) do
		if Cursor.x >= rect.x and Cursor.x <= rect.x + rect.w and Cursor.y >= rect.y and Cursor.y <= rect.y + rect.h then
			settingsCursor = i
		end
	end

	-- Drag slider
	if draggingSlider then
		local rect = sliderRects[draggingSlider]

		if rect then
			local t = Util.clamp((Cursor.x - rect.x) / rect.w, 0, 1)

			rows[draggingSlider].set(t)
		end
	end

	-- Gamepad analog control
	if Cursor.usingVirtual then
		local row = rows[settingsCursor]

		if row and row.type == "slider" then
			local ax = Cursor.axisX or 0

			if abs(ax) > 0.25 then
				local v = Util.clamp(row.get() + ax * dt * 0.7, 0, 1)
				row.set(v)
			end
		end
	end
end

function Screen.draw()
	local sw, sh = lg.getDimensions()
	local centerX = floor(sw * 0.5)
	local startY = floor(sh * 0.25)
	local lineH = 48
	local gap = 14

	sliderRects = {}

	lg.setColor(colorMenu)
	lg.rectangle("fill", 0, 0, sw, sh)

	lg.setColor(colorText)
	Fonts.set("title")
	Text.printfShadow(L("settings.title"), 0, startY - 120, sw, "center")

	Fonts.set("menu")

	for i, row in ipairs(rows) do
		local hovered = rowRects[i] and Cursor.x >= rowRects[i].x and Cursor.x <= rowRects[i].x + rowRects[i].w and Cursor.y >= rowRects[i].y and Cursor.y <= rowRects[i].y + rowRects[i].h

		drawRow(row, settingsCursor == i, hovered, centerX - 160, startY + (i - 1) * lineH + gap, i)
	end

	for _, btn in ipairs(buttons) do
		Button.draw(btn)
	end
end

function Screen.keypressed(key)
	if key == "up" then
		settingsCursor = max(1, settingsCursor - 1)
		Sound.play("uiMove")
	elseif key == "down" then
		settingsCursor = min(#rows, settingsCursor + 1)
		Sound.play("uiMove")
	elseif key == "left" or key == "right" then
		local row = rows[settingsCursor]

		if not row then
			return
		end

		if row.type == "slider" then
			local dir = (key == "right") and 1 or -1
			local step = 0.10
			local v = Util.clamp(row.get() + dir * step, 0, 1)

			row.set(v)
			Sound.play("uiMove")
		elseif row.type == "toggle" then
			row.set(not row.get())
			Sound.play("uiConfirm")
		end

	elseif key == "return" or key == "escape" then
		State.mode = "menu"
		Sound.play("uiBack")
	end
end

function Screen.mousepressed(x, y, button)
	if button == 1 then
		for i, rect in pairs(sliderRects) do
			if x >= rect.x and x <= rect.x + rect.w
			and y >= rect.y and y <= rect.y + rect.h then
				settingsCursor = i
				draggingSlider = i
				return true
			end
		end
	end

	for _, btn in ipairs(buttons) do
		if Button.mousepressed(btn, x, y, button) then
			return true
		end
	end
end

function Screen.mousereleased()
	draggingSlider = nil
end

return Screen