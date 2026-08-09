local Sound = require("systems.sound")
local Fonts = require("core.fonts")
local Theme = require("core.theme")
local State = require("core.state")
local Util = require("core.util")
local Save = require("core.save")
local Hotkeys = require("core.hotkeys")
local Text = require("ui.text")
local Button = require("ui.button")
local Backdrop = require("scenes.backdrop")
local Steam = require("core.steam")
local L = require("core.localization")
local KeybindCapture = require("ui.keybind_capture")
local ScrollView = require("ui.scroll_view")

local lg = love.graphics
local lm = love.mouse
local floor = math.floor
local min = math.min
local max = math.max
local sin = math.sin

local Screen = {}

local colorText = Theme.ui.text
local colorBackdrop = Theme.ui.backdrop
local colorDim = Theme.ui.screenDim or {0, 0, 0, 0.55}
local colorOutline = Theme.outline.color

local outlineW = Theme.outline.width
local baseRadius = 6 * 3
local outerRadius = baseRadius + outlineW * 0.5
local innerRadius = baseRadius - outlineW * 0.25

local paddingX = 24
local paddingY = 24

local btnW = 240
local btnH = 42
local gap = 62

local lineH = 48
local controlsLineH = 40
local headerHeight = 36
local headerSpacing = 30
local footerSpacing = 22
local tabGap = 10
local tabH = 36
local tabW = 132
local tabAnimSpeed = 12
local minRowsVisible = 6
local tabOuterRadius = 12
local tabInnerRadius = 10

local scrollbarW = 8
local scrollbarMargin = 10
local scrollbarMinThumbH = 24

local boxX, boxY, boxW, boxH = 0, 0, 0, 0
local titleY = 0
local rowsStartY = 0
local buttonsStartY = 0
local listX = 0
local activeLineH = lineH
local maxPanelHeight = 0
local rowsViewportY = 0
local rowsViewportH = 0
local rowsContentH = 0
local rowsScroll = ScrollView.new()

local LABEL_W = 180
local SLIDER_W = 160
local SLIDER_H = 10
local ROW_H = 32
local THUMB_R = 7

local ROW_W = LABEL_W + SLIDER_W + 40

local rows = {}
local buttons = {}

local sliderRects = {}
local rowRects = {}
local tabRects = {}
local draggingSlider = nil

local tabs = {}
local activeTab = 1
local tabAnim = {}
local tabTime = 0
local keybindCapture = KeybindCapture.new()
local settingsDirty = false
local settingsFlushTimer = nil
local settingsFlushDelay = 0.35

local keyboardControlsLayout = {
	{kind = "action", id = "escape", label = "settings.controlPause"},
	{kind = "action", id = "fastForward", label = "settings.controlSpeed"},
	{kind = "action", id = "skipPrep", label = "settings.controlStartWave"},
	{kind = "action", id = "upgrade", label = "settings.controlUpgrade"},
	{kind = "action", id = "sell", label = "settings.controlSell"},
	{kind = "shop", id = "slow", label = "settings.controlPlaceSlow"},
	{kind = "shop", id = "lancer", label = "settings.controlPlaceLancer"},
	{kind = "shop", id = "poison", label = "settings.controlPlacePoison"},
	{kind = "shop", id = "cannon", label = "settings.controlPlaceCannon"},
	{kind = "shop", id = "shock", label = "settings.controlPlaceShock"},
	{kind = "shop", id = "plasma", label = "settings.controlPlacePlasma"},
	{kind = "action", id = "toggleMeter", label = "settings.controlDamageMeter"},
}

local function restoreDefaultKeybinds()
	keybindCapture:restoreDefaults()
end

local function keybindText(row)
	return keybindCapture:text(row)
end

local function flushSettingsNow()
	if settingsDirty then
		Save.flush()
		settingsDirty = false
	end

	settingsFlushTimer = nil
end

local function settingsChanged(flushImmediately)
	settingsDirty = true
	settingsFlushTimer = settingsFlushDelay

	if flushImmediately then
		flushSettingsNow()
	end
end

local function sliderRow(id, label, color, get, set)
	return {id = id, label = label, type = "slider", color = color, get = get, set = set}
end

local function toggleRow(id, label, setting, set)
	return {
		id = id,
		label = label,
		type = "toggle",
		get = function() return Save.data.settings[setting] end,
		set = set or function(value) Save.data.settings[setting] = value end,
	}
end

local function exitToMenu()
	flushSettingsNow()
	keybindCapture:close()

	if State.mode == "settings_gameplay" then
		State.mode = "pause"
	else
		State.mode = "menu"
		Steam.setRichPresence(L("presence.menu"))
	end

	Sound.play("uiBack")
end

local rebuildControlsRows

local function switchTab(nextTab)
	local clamped = Util.clamp(nextTab, 1, #tabs)

	if clamped ~= activeTab then
		activeTab = clamped
		local tabId = tabs[activeTab] and tabs[activeTab].id
		if tabId == "controls_keyboard" then
			rebuildControlsRows()
		end
		draggingSlider = nil
		keybindCapture:close()
		Sound.play("uiMove")
	end
end

local function isControlsTab(index)
	local tab = tabs[index]
	return tab and tab.id == "controls_keyboard"
end

rebuildControlsRows = function()
	local controlsRows = {}
	local sourceLayout = keyboardControlsLayout

	for _, def in ipairs(sourceLayout) do
		controlsRows[#controlsRows + 1] = {
			id = string.format("bind_%s_%s", def.kind, def.id),
			label = L(def.label),
			type = "keybind",
			bindingKind = def.kind,
			bindingId = def.id,
		}
	end

	controlsRows[#controlsRows + 1] = {
		id = "restore_defaults_controls",
		label = L("settings.controlsRestoreDefaults"),
		type = "action",
		onClick = restoreDefaultKeybinds,
	}

	for _, tab in ipairs(tabs) do
		if tab.id == "controls_keyboard" then
			tab.rows = controlsRows
		end
	end
end

local function getActiveRows()
	local tab = tabs[activeTab]

	return tab and tab.rows or {}
end

-- Layout helpers
local function rowRectFor(index, x, yTop)
	rowRects[index] = {x = x, y = yTop, w = ROW_W, h = ROW_H}

	return rowRects[index]
end

local function rowTextY(yTop)
	local fh = lg.getFont():getHeight()

	return yTop + (ROW_H - fh) * 0.5 + 3
end

local function rowSliderY(yTop)
	return yTop + (ROW_H - SLIDER_H) * 0.5
end

local function drawRowHighlight(index, hovered)
	if hovered then
		local r = rowRects[index]

		lg.setColor(1, 1, 1, 0.06)
		lg.rectangle("fill", r.x, r.y, r.w, r.h, 6, 6)
	end
end

-- Row renderers
local function drawSliderRow(row, x, yTop, hovered, index)
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

local function drawInfoRow(row, x, yTop)
	Text.printShadow(row.label, x, rowTextY(yTop))
end

local function drawKeybindRow(row, x, yTop)
	Text.printShadow(row.label, x, rowTextY(yTop))
	Text.printfShadow(keybindText(row), x + LABEL_W, rowTextY(yTop), SLIDER_W + 20, "right")
end

local function drawActionRow(row, x, yTop)
	Text.printShadow(row.label, x, rowTextY(yTop))

	if row.valueLabel then
		Text.printfShadow(row.valueLabel, x + LABEL_W - 16, rowTextY(yTop), 130, "right")
	end

	if row.renderAsButton then
		local buttonW = 132
		local buttonH = ROW_H - 8
		local buttonX = x + ROW_W - buttonW - 8
		local buttonY = yTop + (ROW_H - buttonH) * 0.5

		lg.setColor(colorOutline)
		lg.rectangle("fill", buttonX - 1, buttonY - 1, buttonW + 2, buttonH + 2, 8, 8)
		lg.setColor(0.20, 0.22, 0.30, 1)
		lg.rectangle("fill", buttonX, buttonY, buttonW, buttonH, 7, 7)
		lg.setColor(1, 1, 1, 0.08)
		lg.rectangle("fill", buttonX, buttonY, buttonW, buttonH * 0.45, 7, 7)

		lg.setColor(colorText)
		Text.printfShadow(row.buttonLabel or row.label, buttonX, buttonY + (buttonH - lg.getFont():getHeight()) * 0.5, buttonW, "center")
	end
end

local rowRenderers = {
	slider = drawSliderRow,
	toggle = drawToggleRow,
	keybind = drawKeybindRow,
	action = drawActionRow,
	info = drawInfoRow,
}

local function drawRow(row, hovered, x, yTop, index)
	rowRectFor(index, x, yTop)
	drawRowHighlight(index, hovered)

	lg.setColor(colorText)

	local render = rowRenderers[row.type]
	if render then
		render(row, x, yTop, hovered, index)
	end
end


function Screen.load()
	Hotkeys.refreshFromSave()
	keybindCapture:close()
	rowsScroll:reset()
	activeTab = 1
	tabTime = 0
	settingsDirty = false
	settingsFlushTimer = nil

	tabs = {
		{
			id = "audio",
			label = L("settings.tabAudio"),
			rows = {
				sliderRow("music", L("settings.music"), Theme.tower.shock,
					function() return Save.data.settings.musicVolume end,
					function(v)
						Save.data.settings.musicVolume = v
						Sound.setMusicVolume(v)
					end),
				sliderRow("sfx", L("settings.sfx"), Theme.tower.cannon,
					function() return Save.data.settings.sfxVolume end,
					function(v)
						Save.data.settings.sfxVolume = v
						Sound.setSFXVolume(v)
					end),
			},
		},
		{
			id = "video",
			label = L("settings.tabVideo"),
			rows = {
				toggleRow("screen_shake", L("settings.screenShake"), "screenShake"),
				toggleRow("damage_numbers", L("settings.damageNumbers"), "showDamageNumbers"),
				toggleRow("reduced_flash", L("settings.reducedFlash"), "reducedFlash"),
				toggleRow("fullscreen", L("settings.fullscreen"), "fullscreen",
					function(v)
						if v then
							local sw, sh = love.graphics.getDimensions()
							local msaa = require("core.scale").suggestMSAA(sw, sh) or 8

							love.window.updateMode(0, 0, {fullscreen = true, fullscreentype = "desktop", vsync = 1, msaa = msaa})
						else
							local msaa = require("core.scale").suggestMSAA(1280, 800) or 2
							love.window.updateMode(1280, 800, {fullscreen = false, resizable = true, vsync = 1, msaa = msaa})
						end

						Save.data.settings.fullscreen = v

						local sw, sh = love.graphics.getDimensions()
						love.resize(sw, sh)
					end),
			},
		},
		{
			id = "controls_keyboard",
			label = L("settings.tabControlsKeybinds"),
			rows = {},
		},
	}

	rebuildControlsRows()

	buttons = {
		{
			id = "back",
			label = L("menu.back"),
			w = btnW,
			h = btnH,
			onClick = function()
				exitToMenu()
			end
		}
	}

	tabAnim = {}
	for i = 1, #tabs do
		tabAnim[i] = (i == activeTab) and 1 or 0
	end
end

function Screen.update(dt)
	-- do NOT clear rowRects/sliderRects here. Update uses rects built during the previous draw for hover/drag.
	local sw, sh = lg.getDimensions()
	local cx = floor(sw * 0.5)

	if State.mode ~= "settings_gameplay" then
		Backdrop.update(dt)
	end

	rows = getActiveRows()
	if not isControlsTab(activeTab) then
		keybindCapture:close()
	end
	tabTime = tabTime + dt

	-- Panel sizing (fixed to screen, rows scroll when overflowing)
	activeLineH = isControlsTab(activeTab) and controlsLineH or lineH
	rowsContentH = max(0, (#rows - 1) * activeLineH + ROW_H)
	local minRowsBlockH = max((minRowsVisible - 1) * activeLineH + ROW_H, ROW_H)
	local btnBlockH = buttons[1] and buttons[1].h or 0

	local staticContentH = headerHeight + headerSpacing + footerSpacing + btnBlockH
	local desiredContentH = staticContentH + max(minRowsBlockH, rowsContentH)
	maxPanelHeight = floor(sh - paddingY * 2)
	local maxContentH = max(ROW_H, maxPanelHeight - paddingY * 2)
	local contentH = min(desiredContentH, maxContentH)
	local rowsBlockH = max(ROW_H, contentH - staticContentH)

	boxW = ROW_W + paddingX * 2
	boxH = contentH + paddingY * 2
	boxX = cx - boxW * 0.5
	boxY = floor((sh - boxH) * 0.5)

	titleY = boxY + paddingY
	rowsStartY = titleY + headerHeight + headerSpacing
	rowsViewportY = rowsStartY
	rowsViewportH = rowsBlockH
	rowsScroll:update(rowsContentH, rowsViewportH)

	-- Center the row block inside the panel width
	local rowRectX = cx - (ROW_W * 0.5)
	listX = rowRectX

	-- Buttons (layout in update, like pause)
	buttonsStartY = boxY + boxH - paddingY - btnBlockH
	local tabsTotalW = (#tabs * tabW) + (max(0, #tabs - 1) * tabGap)
	local tabsStartX = cx - tabsTotalW * 0.5
	local tabsY = boxY + boxH + 4

	tabRects = {}
	for i, tab in ipairs(tabs) do
		tabRects[i] = {
			x = tabsStartX + (i - 1) * (tabW + tabGap),
			y = tabsY,
			w = tabW,
			h = tabH,
		}
	end

	for i, rect in ipairs(tabRects) do
		local hovered = lm.getX() >= rect.x and lm.getX() <= rect.x + rect.w and lm.getY() >= rect.y and lm.getY() <= rect.y + rect.h
		local target = (i == activeTab) and 1 or (hovered and 0.65 or 0)
		local a = tabAnim[i] or 0
		tabAnim[i] = a + (target - a) * min(1, dt * tabAnimSpeed)
	end

	for i, btn in ipairs(buttons) do
		btn.x = cx - btn.w * 0.5
		btn.y = buttonsStartY + (i - 1) * gap
	end
	Button.updateList(buttons, dt)

	-- Drag slider
	if draggingSlider then
		local rect = sliderRects[draggingSlider]

		if rect then
			local t = Util.clamp((lm.getX() - rect.x) / rect.w, 0, 1)

			rows[draggingSlider].set(t)
			settingsChanged()
		end
	end

	if settingsFlushTimer then
		settingsFlushTimer = settingsFlushTimer - dt

		if settingsFlushTimer <= 0 then
			flushSettingsNow()
		end
	end
end

function Screen.draw()
	rowRects = {}
	sliderRects = {}

	local sw, sh = lg.getDimensions()

	if State.mode ~= "settings_gameplay" then
		Backdrop.draw()
	end

	-- Dim background
	lg.setColor(colorDim)
	lg.rectangle("fill", 0, 0, sw, sh)

	-- Panel
	lg.setColor(colorOutline)
	lg.rectangle("fill", boxX - outlineW, boxY - outlineW, boxW + outlineW * 2, boxH + outlineW * 2, outerRadius)

	lg.setColor(colorBackdrop)
	lg.rectangle( "fill", boxX, boxY, boxW, boxH, innerRadius)

	-- Title
	Fonts.set("title")

	lg.setColor(colorText)
	Text.printfShadow(L("settings.title"), 0, titleY, sw, "center")

	-- Rows
	Fonts.set("menu")

	lg.setScissor(listX, rowsViewportY, ROW_W, rowsViewportH)
	for i, row in ipairs(rows) do
		local yTop = rowsStartY + (i - 1) * activeLineH - rowsScroll.offset
		if yTop + ROW_H >= rowsViewportY and yTop <= rowsViewportY + rowsViewportH then
			local r = {x = listX, y = yTop, w = ROW_W, h = ROW_H}
			local hovered = lm.getX() >= r.x and lm.getX() <= r.x + r.w and lm.getY() >= r.y and lm.getY() <= r.y + r.h
			drawRow(row, hovered, listX, yTop, i)
		end
	end
	lg.setScissor()

	if rowsScroll:canScroll() then
		local trackX = boxX + boxW + scrollbarMargin
		local trackY = rowsViewportY
		local trackH = rowsViewportH
		local thumbY, thumbH = rowsScroll:getThumb(trackY, trackH, scrollbarMinThumbH)
		lg.setColor(0, 0, 0, 0.28)
		lg.rectangle("fill", trackX, trackY, scrollbarW, trackH, 4, 4)
		lg.setColor(1, 1, 1, 0.35)
		lg.rectangle("fill", trackX, thumbY, scrollbarW, thumbH, 4, 4)
	end

	if keybindCapture.rowId then
		for i, row in ipairs(rows) do
			if row.id == keybindCapture.rowId then
				local focusedRect = rowRects[i]
				if focusedRect then
					lg.setColor(colorText)
					Text.printfShadow(keybindCapture.hint or L("settings.controlListeningHint"), focusedRect.x, focusedRect.y + focusedRect.h + 6, focusedRect.w, "left")
				end
				break
			end
		end
	end

	-- Tabs
	Fonts.set("menu")
	for i, rect in ipairs(tabRects) do
		local tab = tabs[i]
		local hovered = lm.getX() >= rect.x and lm.getX() <= rect.x + rect.w and lm.getY() >= rect.y and lm.getY() <= rect.y + rect.h
		local active = i == activeTab
		local anim = tabAnim[i] or 0
		local wobble = active and (sin(tabTime * 4 + i * 0.6) * 0.5 + 0.5) or 0
		local highlightAlpha = 0.05 + anim * 0.08 + wobble * 0.02
		local yOffset = active and -1 or (hovered and -0.5 or 0)
		local drawY = rect.y + yOffset
		local drawX = rect.x

		lg.setColor(colorOutline)
		lg.rectangle("fill", drawX - outlineW, drawY - outlineW, rect.w + outlineW * 2, rect.h + outlineW * 2, tabOuterRadius, tabOuterRadius)

		lg.setColor(colorBackdrop)
		lg.rectangle("fill", drawX, drawY, rect.w, rect.h, tabInnerRadius, tabInnerRadius)

		if highlightAlpha > 0 then
			lg.setColor(1, 1, 1, highlightAlpha)
			lg.rectangle("fill", drawX, drawY, rect.w, rect.h, tabInnerRadius, tabInnerRadius)
		end

		local textY = drawY + (rect.h - lg.getFont():getHeight()) * 0.5

		lg.setColor(colorText)
		Text.printfShadow(tab.label, drawX, textY, rect.w, "center")
	end

	-- Button
	Button.drawList(buttons)

	if isControlsTab(activeTab) and keybindCapture.conflictMessage then
		lg.setColor(colorText)
		Text.printfShadow(keybindCapture.conflictMessage, listX, buttonsStartY - 24, ROW_W, "left")
	end
end

function Screen.keypressed(key)
	if keybindCapture:keypressed(key, rows) then
		return
	end

	if key == "escape" then
		exitToMenu()
	end
end

local function contains(rect, x, y)
	return rect and x >= rect.x and x <= rect.x + rect.w
		and y >= rect.y and y <= rect.y + rect.h
end

local function findRectAt(rects, x, y)
	-- Row rectangles are intentionally sparse when the list is scrolled because
	-- only visible rows are drawn and hit-testable.
	for i, rect in pairs(rects) do
		if contains(rect, x, y) then
			return i
		end
	end
end

local function setSliderFromMouse(index, x)
	local slider = sliderRects[index]
	if not slider or x < slider.x or x > slider.x + slider.w then
		return
	end

	rows[index].set(Util.clamp((x - slider.x) / slider.w, 0, 1))
	settingsChanged()
	draggingSlider = index
	return true
end

local rowPressHandlers = {
	slider = function(row, index, x)
		return setSliderFromMouse(index, x)
	end,
	toggle = function(row)
		row.set(not row.get())
		settingsChanged(row.id == "fullscreen")
		Sound.play("uiConfirm")
		return true
	end,
	keybind = function(row)
		keybindCapture:start(row)
		return true
	end,
	action = function(row)
		if row.onClick then
			row.onClick()
		end
		return true
	end,
	info = function()
		Sound.play("uiMove")
		return true
	end,
}

function Screen.mousepressed(x, y, button)
	if button == 1 then
		local tabIndex = findRectAt(tabRects, x, y)
		if tabIndex then
			switchTab(tabIndex)
			return true
		end

		local rowIndex = findRectAt(rowRects, x, y)
		if rowIndex then
			local row = rows[rowIndex]
			local handlePress = row and rowPressHandlers[row.type]
			if handlePress then
				handlePress(row, rowIndex, x)
			end
			return true
		end
	end

	-- Buttons (unchanged)
	return Button.mousepressedList(buttons, x, y, button)
end

function Screen.mousereleased(x, y, button)
	if draggingSlider then
		Sound.play("uiMove")
		flushSettingsNow()
	end

	draggingSlider = nil

	return Button.mousereleasedList(buttons, x, y, button)
end


function Screen.wheelmoved(_, y)
	if not rowsScroll:canScroll() or y == 0 then
		return
	end

	rowsScroll:move(-y * activeLineH)
end

return Screen
