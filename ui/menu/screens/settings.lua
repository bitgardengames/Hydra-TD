local Sound = require("systems.sound")
local Difficulty = require("systems.difficulty")
local Fonts = require("core.fonts")
local Theme = require("core.theme")
local State = require("core.state")
local Util = require("core.util")
local Save = require("core.save")
local Text = require("ui.text")
local Button = require("ui.button")
local Backdrop = require("scenes.backdrop")
local Cursor = require("core.cursor")
local Steam = require("core.steam")
local L = require("core.localization")

local lg = love.graphics
local floor = math.floor
local min = math.min
local max = math.max
local abs = math.abs

local Screen = {}

local colorText = Theme.ui.text

local LABEL_W = 180
local SLIDER_W = 160
local SLIDER_H = 10
local ROW_H = 32
local THUMB_R = 7

local ARROW_W = 24
local ROW_W = ARROW_W + LABEL_W + SLIDER_W + 40

local settingsCursor = 1
local rows = {}
local buttons = {}

local sliderRects = {}
local rowRects = {}
local draggingSlider = nil

-- Difficulty helpers
local DIFFICULTY_ORDER = {"easy", "normal", "hard"}

local function getDifficultyIndex(key)
	for i, v in ipairs(DIFFICULTY_ORDER) do
		if v == key then
			return i
		end
	end

	return 2
end

local function adjustRow(row, dir)
	if row.type == "slider" then
		row.set(Util.clamp(row.get() + dir * 0.10, 0, 1))
		Sound.play("uiMove")
	elseif row.type == "toggle" then
		row.set(not row.get())
		Sound.play("uiConfirm")
	elseif row.type == "discrete" then
		local cur = getDifficultyIndex(row.get())
		local next = cur + dir

		if next < 1 then next = #DIFFICULTY_ORDER end
		if next > #DIFFICULTY_ORDER then next = 1 end
		row.set(DIFFICULTY_ORDER[next])
		Sound.play("uiMove")
	end
end

-- Layout helpers
local function rowRectFor(index, x, yTop)
	rowRects[index] = {x = x - ARROW_W, y = yTop, w = ROW_W, h = ROW_H}

	return rowRects[index]
end

local function rowTextY(yTop)
	local fh = lg.getFont():getHeight()

	return yTop + (ROW_H - fh) * 0.5 + 3
end

local function rowSliderY(yTop)
	return yTop + (ROW_H - SLIDER_H) * 0.5
end

local function drawRowHighlight(index, selected, hovered)
	if selected or hovered then
		local r = rowRects[index]

		lg.setColor(1, 1, 1, selected and 0.10 or 0.06)
		lg.rectangle("fill", r.x, r.y, r.w, r.h, 6, 6)
	end
end

local function drawRowArrow(x, yTop, selected)
	if selected then
		lg.setColor(1, 1, 1, 1)
		Text.printShadow(">", x - 18, rowTextY(yTop))
	end
end

-- Row renderers
local function drawSliderRow(row, x, yTop, selected, hovered, index)
	Text.printShadow(row.label, x, rowTextY(yTop))

	local sliderX = x + LABEL_W
	local sliderY = rowSliderY(yTop)

	sliderRects[index] = {x = sliderX, y = sliderY, w = SLIDER_W, h = SLIDER_H}

	local t = max(0, min(1, row.get()))

	lg.setColor(0, 0, 0, 0.35)
	lg.rectangle("fill", sliderX, sliderY, SLIDER_W, SLIDER_H, 4, 4)

	if t > 0 then
		lg.setColor(row.color)
		lg.rectangle("fill", sliderX, sliderY, SLIDER_W * t, SLIDER_H, 4, 4)
	end

	local thumbX = sliderX + SLIDER_W * t
	local thumbY = sliderY + 5
	local grow = (hovered or draggingSlider == index) and 2 or 0

	lg.setColor(row.color[1], row.color[2], row.color[3], 0.25)
	lg.circle("fill", thumbX, thumbY, THUMB_R + grow + 3)

	lg.setColor(1, 1, 1, 1)
	lg.circle("fill", thumbX, thumbY, THUMB_R + grow)
end

local function drawToggleRow(row, x, yTop)
	local valueText = row.get() and L("settings.on") or L("settings.off")

	Text.printShadow(string.format("%s: %s", row.label, valueText), x, rowTextY(yTop))
end

local function drawDiscreteRow(row, x, yTop)
	local key = row.get()

	Text.printShadow(string.format("%s: %s", row.label, L("difficulty." .. key)), x, rowTextY(yTop))
end

local function drawRow(row, selected, hovered, x, yTop, index)
	rowRectFor(index, x, yTop)
	drawRowHighlight(index, selected, hovered)
	drawRowArrow(x, yTop, selected)

	if row.type == "slider" then
		drawSliderRow(row, x, yTop, selected, hovered, index)
	elseif row.type == "toggle" then
		drawToggleRow(row, x, yTop)
	elseif row.type == "discrete" then
		drawDiscreteRow(row, x, yTop)
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
			id = "difficulty",
			label = L("settings.difficulty"),
			type = "discrete",
			get = function()
				return Save.data.settings.difficulty or Difficulty.default
			end,
			set = function(key)
				Save.data.settings.difficulty = key
				Difficulty.set(key)
				Save.flush()
			end,
		},
		{
			id = "fullscreen",
			label = L("settings.fullscreen"),
			type = "toggle",
			get = function() return Save.data.settings.fullscreen end,
			set = function(v)
				if v then
					local sw, sh = love.graphics.getDimensions()
					local msaa = require("core.scale").suggestMSAA(sw, sh) or 8

					love.window.setMode(0, 0, { fullscreen = true, fullscreentype = "desktop", vsync = 1, msaa = msaa})
				else
					local msaa = require("core.scale").suggestMSAA(1280, 800) or 2

					love.window.setMode(1280, 800, { fullscreen = false, resizable = true, vsync = 1, msaa = msaa})
				end

				Save.data.settings.fullscreen = v

				local sw, sh = love.graphics.getDimensions()

				love.resize(sw, sh)

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
				Steam.setRichPresence(L("presence.menu"))
				Sound.play("uiBack")
			end
		}
	}
end

function Screen.update(dt)
	-- do NOT clear rowRects/sliderRects here. Update uses the rects built during the previous draw for hover/drag.
	local sw, sh = lg.getDimensions()
	local cx = floor(sw * 0.5)
	local startY = floor(sh * 0.55)

	Backdrop.update(dt)

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
				row.set(Util.clamp(row.get() + ax * dt * 0.7, 0, 1))
			end
		end
	end
end

function Screen.draw()
	rowRects = {}
	sliderRects = {}

	local sw, sh = lg.getDimensions()
	local centerX = floor(sw * 0.5)
	local startY = floor(sh * 0.40)
	local lineH = 48

	local listX = centerX - 160

	Backdrop.draw()

	Fonts.set("title")

	lg.setColor(colorText)
	Text.printfShadow(L("settings.title"), 0, startY - 120, sw, "center")

	Fonts.set("menu")

	for i, row in ipairs(rows) do
		local yTop = startY + (i - 1) * lineH
		local r = {x = listX - ARROW_W, y = yTop, w = ROW_W, h = ROW_H}
		local hovered = Cursor.x >= r.x and Cursor.x <= r.x + r.w and Cursor.y >= r.y and Cursor.y <= r.y + r.h

		drawRow(row, settingsCursor == i, hovered, listX, yTop, i)
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
	elseif key == "left" then
		local row = rows[settingsCursor]

		if row then
			adjustRow(row, -1)
		end
	elseif key == "right" then
		local row = rows[settingsCursor]

		if row then
			adjustRow(row, 1)
		end
	elseif key == "return" or key == "escape" then
		State.mode = "menu"
		Steam.setRichPresence(L("presence.menu"))
		Sound.play("uiBack")
	end
end

function Screen.gamepadpressed(_, button)
	local row = rows[settingsCursor]

	if not row then
		return
	end

	if button == "dpup" then
		settingsCursor = max(1, settingsCursor - 1)
		Sound.play("uiMove")
	elseif button == "dpdown" then
		settingsCursor = min(#rows, settingsCursor + 1)
		Sound.play("uiMove")
	elseif button == "dpleft" then
		adjustRow(row, -1)
	elseif button == "dpright" then
		adjustRow(row, 1)
	elseif button == "b" then
		State.mode = "menu"
		Steam.setRichPresence(L("presence.menu"))
		Sound.play("uiBack")
	end
end

function Screen.mousepressed(x, y, button)
	if button == 1 then
		for i, rect in pairs(sliderRects) do
			if x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h then
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
	if draggingSlider then
		Sound.play("uiMove")
	end

	draggingSlider = nil
end

return Screen