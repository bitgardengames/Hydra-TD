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
local Cursor = require("core.cursor")
local Steam = require("core.steam")
local L = require("core.localization")

local lg = love.graphics
local floor = math.floor
local min = math.min
local max = math.max
local abs = math.abs
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
local corner = 18

local btnW = 240
local btnH = 42
local gap = 62

local lineH = 48
local headerHeight = 36
local headerSpacing = 30
local footerSpacing = 22
local tabGap = 10
local tabH = 36
local tabMinW = 108
local tabOffsetY = 3
local tabAnimSpeed = 12
local minRowsVisible = 6
local tabOuterRadius = 12
local tabInnerRadius = 10

local boxX, boxY, boxW, boxH = 0, 0, 0, 0
local titleY = 0
local rowsStartY = 0
local buttonsStartY = 0
local listX = 0

local LABEL_W = 180
local SLIDER_W = 160
local SLIDER_H = 10
local ROW_H = 32
local THUMB_R = 7

local ROW_W = LABEL_W + SLIDER_W + 40

local settingsCursor = 1
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
local capturingRowId = nil
local conflictMessage = nil
local pendingBindingChange = nil
local capturingHint = nil
local settingsDirty = false
local settingsFlushTimer = nil
local settingsFlushDelay = 0.2

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
	{kind = "action", id = "screenshot", label = "settings.controlScreenshot"},
}

local gamepadControlsLayout = {
	{kind = "action", id = "fastForward", label = "settings.controlSpeed"},
	{kind = "action", id = "skipPrep", label = "settings.controlStartWave"},
	{kind = "action", id = "upgrade", label = "settings.controlUpgrade"},
	{kind = "action", id = "sell", label = "settings.controlSell"},
	{kind = "shop", id = "dpleft", label = "settings.controlPlaceSlow"},
	{kind = "shop", id = "dpup", label = "settings.controlPlaceLancer"},
	{kind = "shop", id = "dpdown", label = "settings.controlPlacePoison"},
	{kind = "shop", id = "dpright", label = "settings.controlPlaceCannon"},
	{kind = "shop", id = "rightstick", label = "settings.controlPlaceShock"},
	{kind = "action", id = "toggleMeter", label = "settings.controlDamageMeter"},
}

local function closeCapture()
	capturingRowId = nil
	conflictMessage = nil
	pendingBindingChange = nil
	capturingHint = nil
end

local function startCapture(row)
	capturingRowId = row.id
	conflictMessage = nil
	pendingBindingChange = nil
	capturingHint = L("settings.controlListeningHint")
	Sound.play("uiMove")
end

local function getBinding(row)
	local keybinds = Save.data.settings.keybinds[row.bindingDevice]

	if row.bindingKind == "shop" then
		return keybinds.shop[row.bindingId]
	end

	return keybinds.actions[row.bindingId]
end

local function getBindingSection(bindingDevice, bindingKind)
	local keybinds = Save.data.settings.keybinds[bindingDevice]

	if bindingKind == "shop" then
		return keybinds.shop
	end

	return keybinds.actions
end

local function formatBindingValue(row, key)
	if not key or key == "" or key == "none" then
		return L("settings.controlUnbound")
	end

	if row.bindingDevice == "gamepad" then
		return Hotkeys.padAliases[key] or key:upper()
	end

	return key:upper()
end

local function commitBindingChange(change)
	local section = getBindingSection(change.row.bindingDevice, change.row.bindingKind)

	if change.conflictRow then
		local conflictSection = getBindingSection(change.conflictRow.bindingDevice, change.conflictRow.bindingKind)
		conflictSection[change.conflictRow.bindingId] = change.previous
	end

	section[change.row.bindingId] = change.key
	Hotkeys.refreshFromSave()
	Save.flush()
end

local function setBinding(row, key)
	local section = getBindingSection(row.bindingDevice, row.bindingKind)
	local previous = section[row.bindingId]
	local conflictRow = nil

	if key and key ~= "none" then
		for _, other in ipairs(rows) do
			if other.type == "keybind" and other.id ~= row.id and other.bindingDevice == row.bindingDevice and getBinding(other) == key then
				conflictRow = other
				break
			end
		end
	end

	if conflictRow then
		pendingBindingChange = {
			row = row,
			key = key,
			previous = previous,
			conflictRow = conflictRow,
			conflictPrevious = getBinding(conflictRow),
		}
		conflictMessage = L(
			"settings.controlConflictSwapPreview",
			row.label,
			formatBindingValue(row, previous),
			formatBindingValue(row, key),
			conflictRow.label,
			formatBindingValue(conflictRow, pendingBindingChange.conflictPrevious),
			formatBindingValue(conflictRow, previous)
		)
		capturingHint = L("settings.controlConflictConfirmHint")
		Sound.play("uiMove")
		return
	end

	conflictMessage = nil
	pendingBindingChange = nil
	capturingHint = L("settings.controlListeningHint")
	commitBindingChange({row = row, key = key, previous = previous})
end

local function restoreDefaultKeybinds()
	Save.data.settings.keybinds = Hotkeys.getDefaultBindings()
	Hotkeys.refreshFromSave()
	Save.flush()
	conflictMessage = L("settings.controlsDefaultsRestored")
	pendingBindingChange = nil
	Sound.play("uiConfirm")
end

local function keybindText(row)
	if capturingRowId == row.id then
		return L("settings.controlListening")
	end

	local key = getBinding(row)
	return formatBindingValue(row, key)
end

local function adjustRow(row, dir)
	if row.type == "slider" then
		row.set(Util.clamp(row.get() + dir * 0.10, 0, 1))
		settingsDirty = true
		settingsFlushTimer = settingsFlushDelay
		Sound.play("uiMove")
	elseif row.type == "toggle" then
		row.set(not row.get())
		Sound.play("uiConfirm")
	elseif row.type == "action" and row.onClick then
		row.onClick()
	elseif row.type == "keybind" then
		startCapture(row)
	end
end

local function flushSettingsNow()
	if settingsDirty then
		Save.flush()
		settingsDirty = false
	end

	settingsFlushTimer = nil
end

local function exitToMenu()
	flushSettingsNow()
	closeCapture()
	State.mode = "menu"
	Steam.setRichPresence(L("presence.menu"))
	Sound.play("uiBack")
end

local function switchTab(nextTab)
	local clamped = Util.clamp(nextTab, 1, #tabs)

	if clamped ~= activeTab then
		activeTab = clamped
		settingsCursor = 1
		draggingSlider = nil
		closeCapture()
		Sound.play("uiMove")
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

local function drawRowHighlight(index, selected, hovered)
	if selected or hovered then
		local r = rowRects[index]

		lg.setColor(1, 1, 1, selected and 0.10 or 0.06)
		lg.rectangle("fill", r.x, r.y, r.w, r.h, 6, 6)
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

local function drawInfoRow(row, x, yTop)
	Text.printShadow(row.label, x, rowTextY(yTop))
end

local function drawKeybindRow(row, x, yTop)
	Text.printShadow(row.label, x, rowTextY(yTop))
	Text.printfShadow(keybindText(row), x + LABEL_W, rowTextY(yTop), SLIDER_W + 20, "right")
end

local function drawActionRow(row, x, yTop)
	Text.printShadow(row.label, x, rowTextY(yTop))
end

local function drawRow(row, selected, hovered, x, yTop, index)
	rowRectFor(index, x, yTop)
	drawRowHighlight(index, selected, hovered)

	lg.setColor(colorText)

	if row.type == "slider" then
		drawSliderRow(row, x, yTop, selected, hovered, index)
	elseif row.type == "toggle" then
		drawToggleRow(row, x, yTop)
	elseif row.type == "keybind" then
		drawKeybindRow(row, x, yTop)
	elseif row.type == "action" then
		drawActionRow(row, x, yTop)
	elseif row.type == "info" then
		drawInfoRow(row, x, yTop)
	end
end

function Screen.load()
	Hotkeys.refreshFromSave()
	settingsCursor = 1
	activeTab = 1
	tabTime = 0
	settingsDirty = false
	settingsFlushTimer = nil

	tabs = {
		{
			id = "audio",
			label = L("settings.tabAudio"),
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
					end,
				},
			},
		},
		{
			id = "video",
			label = L("settings.tabVideo"),
			rows = {
				{
					id = "fullscreen",
					label = L("settings.fullscreen"),
					type = "toggle",
					get = function() return Save.data.settings.fullscreen end,
					set = function(v)
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

						Save.flush()
					end,
				},
			},
		},
		{
			id = "controlsKeyboard",
			label = L("settings.tabControlsKeyboard"),
			rows = {},
		},
		{
			id = "controlsGamepad",
			label = L("settings.tabControlsGamepad"),
			rows = {},
		},
	}

	local keyboardRows = tabs[3].rows
	for _, def in ipairs(keyboardControlsLayout) do
		keyboardRows[#keyboardRows + 1] = {
			id = string.format("bind_keyboard_%s_%s", def.kind, def.id),
			label = L(def.label),
			type = "keybind",
			bindingDevice = "keyboard",
			bindingKind = def.kind,
			bindingId = def.id,
		}
	end
	keyboardRows[#keyboardRows + 1] = {
		id = "restore_defaults_keyboard",
		label = L("settings.controlsRestoreDefaults"),
		type = "action",
		onClick = restoreDefaultKeybinds,
	}

	local gamepadRows = tabs[4].rows
	for _, def in ipairs(gamepadControlsLayout) do
		gamepadRows[#gamepadRows + 1] = {
			id = string.format("bind_gamepad_%s_%s", def.kind, def.id),
			label = L(def.label),
			type = "keybind",
			bindingDevice = "gamepad",
			bindingKind = def.kind,
			bindingId = def.id,
		}
	end
	gamepadRows[#gamepadRows + 1] = {
		id = "restore_defaults_gamepad",
		label = L("settings.controlsRestoreDefaults"),
		type = "action",
		onClick = restoreDefaultKeybinds,
	}

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

	Backdrop.update(dt)

	rows = getActiveRows()
	if activeTab ~= 3 and activeTab ~= 4 then
		closeCapture()
	end
	settingsCursor = Util.clamp(settingsCursor, 1, max(1, #rows))
	tabTime = tabTime + dt

	-- Panel sizing (keep room for future settings rows)
	local rowsBlockH = max((minRowsVisible - 1) * lineH + ROW_H, (#rows - 1) * lineH + ROW_H)
	local btnBlockH = buttons[1] and buttons[1].h or 0

	local contentH = headerHeight + headerSpacing + rowsBlockH + footerSpacing + btnBlockH

	boxW = ROW_W + paddingX * 2
	boxH = contentH + paddingY * 2
	boxX = cx - boxW * 0.5
	boxY = floor(sh * 0.5 - boxH * 0.5)

	titleY = boxY + paddingY
	rowsStartY = titleY + headerHeight + headerSpacing

	-- Center the row block inside the panel width
	local rowRectX = cx - (ROW_W * 0.5)
	listX = rowRectX

	-- Buttons (layout in update, like pause)
	buttonsStartY = rowsStartY + rowsBlockH + footerSpacing
	local tabsStartY = boxY + boxH + tabOffsetY

	local tabW = max(tabMinW, floor((ROW_W - tabGap * (#tabs - 1)) / #tabs))
	local tabsTotalW = #tabs * tabW + (#tabs - 1) * tabGap
	local tabsX = floor(cx - tabsTotalW * 0.5)

	tabRects = {}
	for i, tab in ipairs(tabs) do
		tabRects[i] = {
			x = tabsX + (i - 1) * (tabW + tabGap),
			y = tabsStartY,
			w = tabW,
			h = tabH,
		}
	end

	for i, rect in ipairs(tabRects) do
		local hovered = Cursor.x >= rect.x and Cursor.x <= rect.x + rect.w and Cursor.y >= rect.y and Cursor.y <= rect.y + rect.h
		local target = (i == activeTab) and 1 or (hovered and 0.65 or 0)
		local a = tabAnim[i] or 0
		tabAnim[i] = a + (target - a) * min(1, dt * tabAnimSpeed)
	end

	for i, btn in ipairs(buttons) do
		btn.x = cx - btn.w * 0.5
		btn.y = buttonsStartY + (i - 1) * gap

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
			settingsDirty = true
		end
	end

	-- Gamepad analog control
	if Cursor.usingVirtual then
		local row = rows[settingsCursor]

		if row and row.type == "slider" then
			local ax = Cursor.axisX or 0

			if abs(ax) > 0.25 then
				row.set(Util.clamp(row.get() + ax * dt * 0.7, 0, 1))
				settingsDirty = true
				settingsFlushTimer = settingsFlushDelay
			end
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

	Backdrop.draw()

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

	for i, row in ipairs(rows) do
		local yTop = rowsStartY + (i - 1) * lineH
		local r = {x = listX, y = yTop, w = ROW_W, h = ROW_H}
		local hovered = Cursor.x >= r.x and Cursor.x <= r.x + r.w and Cursor.y >= r.y and Cursor.y <= r.y + r.h

		drawRow(row, settingsCursor == i, hovered, listX, yTop, i)
	end

	if capturingRowId and rows[settingsCursor] and rows[settingsCursor].id == capturingRowId then
		local focusedRect = rowRects[settingsCursor]
		if focusedRect then
			lg.setColor(colorText)
			Text.printfShadow(capturingHint or L("settings.controlListeningHint"), focusedRect.x, focusedRect.y + focusedRect.h + 6, focusedRect.w, "left")
		end
	end

	-- Tabs
	Fonts.set("menu")
	for i, tab in ipairs(tabs) do
		local rect = tabRects[i]
		local hovered = rect and Cursor.x >= rect.x and Cursor.x <= rect.x + rect.w and Cursor.y >= rect.y and Cursor.y <= rect.y + rect.h
		local active = i == activeTab
		local anim = tabAnim[i] or 0
		local wobble = active and (sin(tabTime * 4 + i * 0.6) * 0.5 + 0.5) or 0
		local highlightAlpha = 0.05 + anim * 0.08 + wobble * 0.02
		local yOffset = active and -1 or (hovered and -0.5 or 0)
		local drawY = rect.y + yOffset

		lg.setColor(colorOutline)
		lg.rectangle("fill", rect.x - outlineW, drawY - outlineW, rect.w + outlineW * 2, rect.h + outlineW * 2, tabOuterRadius, tabOuterRadius)

		lg.setColor(colorBackdrop)
		lg.rectangle("fill", rect.x, drawY, rect.w, rect.h, tabInnerRadius, tabInnerRadius)

		if highlightAlpha > 0 then
			lg.setColor(1, 1, 1, highlightAlpha)
			lg.rectangle("fill", rect.x, drawY, rect.w, rect.h, tabInnerRadius, tabInnerRadius)
		end

		local textY = drawY + (rect.h - lg.getFont():getHeight()) * 0.5

		lg.setColor(colorText)
		Text.printfShadow(tab.label, rect.x, textY, rect.w, "center")
	end

	-- Button
	for _, btn in ipairs(buttons) do
		Button.draw(btn)
	end

	if (activeTab == 3 or activeTab == 4) and conflictMessage then
		lg.setColor(colorText)
		Text.printfShadow(conflictMessage, listX, buttonsStartY - 24, ROW_W, "left")
	end
end

function Screen.keypressed(key)
	if capturingRowId then
		local row = rows[settingsCursor]
		if not row or row.id ~= capturingRowId then
			for _, candidate in ipairs(rows) do
				if candidate.id == capturingRowId then
					row = candidate
					break
				end
			end
		end

		if key == "escape" then
			closeCapture()
			Sound.play("uiBack")
			return
		end

		if pendingBindingChange then
			if key == "return" then
				commitBindingChange(pendingBindingChange)
				closeCapture()
				Sound.play("uiConfirm")
			end
			return
		end

		if row then
			if key == "backspace" then
				setBinding(row, "none")
				closeCapture()
				Sound.play("uiConfirm")
				return
			end

			if row.bindingDevice ~= "keyboard" then
				return
			end

			setBinding(row, key)
			if not pendingBindingChange then
				closeCapture()
				Sound.play("uiConfirm")
			end
		end

		return
	end

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
	elseif key == "return" then
		local row = rows[settingsCursor]
		if row then
			adjustRow(row, 1)
		end
	elseif key == "escape" then
		exitToMenu()
	end
end

function Screen.gamepadpressed(_, button)
	if capturingRowId then
		local row = rows[settingsCursor]

		if not row or row.id ~= capturingRowId then
			for _, candidate in ipairs(rows) do
				if candidate.id == capturingRowId then
					row = candidate
					break
				end
			end
		end

		if button == "b" then
			closeCapture()
			Sound.play("uiBack")
			return
		end

		if pendingBindingChange then
			if button == "a" then
				commitBindingChange(pendingBindingChange)
				closeCapture()
				Sound.play("uiConfirm")
			end
			return
		end

		if row then
			if button == "back" then
				setBinding(row, "none")
				closeCapture()
				Sound.play("uiConfirm")
				return
			end

			if row.bindingDevice ~= "gamepad" then
				return
			end

			setBinding(row, button)
			if not pendingBindingChange then
				closeCapture()
				Sound.play("uiConfirm")
			end
		end

		return
	end

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
		exitToMenu()
	end
end

function Screen.mousepressed(x, y, button)
	if button == 1 then
		for i, rect in ipairs(tabRects) do
			if x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h then
				switchTab(i)
				return true
			end
		end

		-- Rows
		for i, rect in pairs(rowRects) do
			if x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h then
				settingsCursor = i

				local row = rows[i]
				local slider = sliderRects[i]

				-- Slider
				if row.type == "slider" and slider then
					if x >= slider.x and x <= slider.x + slider.w then
						local t = Util.clamp((x - slider.x) / slider.w, 0, 1)
						row.set(t)
						settingsDirty = true
						draggingSlider = i
						return true
					end
				end

				-- Toggle
				if row.type == "toggle" then
					row.set(not row.get())
					Sound.play("uiConfirm")
					return true
				end

				if row.type == "keybind" then
					startCapture(row)
					return true
				end

				if row.type == "action" and row.onClick then
					row.onClick()
					return true
				end

				if row.type == "info" then
					Sound.play("uiMove")
					return true
				end

				return true
			end
		end
	end

	-- Buttons (unchanged)
	for _, btn in ipairs(buttons) do
		if Button.mousepressed(btn, x, y, button) then
			return true
		end
	end
end

function Screen.mousereleased(x, y, button)
	if draggingSlider then
		Sound.play("uiMove")
		flushSettingsNow()
	end

	draggingSlider = nil

	for _, btn in ipairs(buttons) do
		if Button.mousereleased(btn, x, y, button) then
			return true
		end
	end
end

return Screen
