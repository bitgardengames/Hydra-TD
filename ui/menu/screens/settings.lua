local Sound = require("systems.sound")
local Fonts = require("core.fonts")
local Theme = require("core.theme")
local State = require("core.state")
local Util = require("core.util")
local SettingsModel = require("ui.menu.settings_model")
local SettingsControls = require("ui.menu.settings_controls")
local Save = require("core.save")
local Hotkeys = require("core.hotkeys")
local Text = require("ui.text")
local Button = require("ui.button")
local Backdrop = require("scenes.backdrop")
local Steam = require("core.steam")
local L = require("core.localization")
local KeybindCapture = require("ui.keybind_capture")
local ScrollView = require("ui.scroll_view")
local Tooltip = require("ui.tooltip")
local ConfirmationDialog = require("ui.confirmation_dialog")

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
local tabOuterRadius = 10
local tabInnerRadius = 8

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
local layoutDirty = true
local layoutMeasurementDirty = true
local cachedWindowW, cachedWindowH

local LABEL_W = 180
local SLIDER_W = 160
local SLIDER_VALUE_GAP = 16
local SLIDER_VALUE_W = 56
local SLIDER_H = 10
local ROW_H = 32
local THUMB_R = 7
local SLIDER_KEY_STEP = 0.05

local ROW_W = LABEL_W + SLIDER_W + SLIDER_VALUE_GAP + SLIDER_VALUE_W

local rowViews = {}
local buttons = {}

local draggingSlider = nil
local focusedRow = nil
local controlContext

local tabs = {}
local activeTabId
local tabViews = {}
local tabAnim = {}
local tabTime = 0
local keybindCapture = KeybindCapture.new()
local confirmation = ConfirmationDialog.new()

local function confirmRestoreKeybindDefaults()
	keybindCapture:close()
	confirmation:show({
		reducedMotion = Save.data.settings.cameraMotion == false,
		title = L("confirmation.restoreKeybindsTitle"),
		titleFont = "menu",
		description = L("confirmation.restoreKeybindsDescription"),
		confirmLabel = L("confirmation.restoreDefaults"),
		cancelLabel = L("confirmation.cancel"),
		onConfirm = function() keybindCapture:restoreDefaults() end,
	})
end

local function buildTabs()
	return SettingsModel.build(keybindCapture, {
		onRestoreKeybindDefaults = confirmRestoreKeybindDefaults,
	})
end

local function requestLayoutMeasurement()
	layoutDirty = true
	layoutMeasurementDirty = true
end

local function requestRowLayout()
	layoutDirty = true
end

local function isControlsTab(index)
	local tab = tabs[index]
	return tab and tab.id == "controls_keyboard"
end

local function getActiveTab()
	for i, tab in ipairs(tabs) do
		if tab.id == activeTabId then
			return tab, i
		end
	end
end

local function flushSettingsNow()
	Save.flush()
end

local function switchTab(tabView)
	if not tabView or tabView.tab.id == activeTabId then
		return
	end

	if draggingSlider then
		flushSettingsNow()
	end
	activeTabId = tabView.tab.id
	draggingSlider = nil
	keybindCapture:close()
	focusedRow = nil
	requestLayoutMeasurement()
	Sound.play("uiMove")
end

local function settingsChanged()
	Save.markDirty()
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

local function getActiveRows()
	local tab = getActiveTab()

	return tab and tab.rows or {}
end

local function rowTextY(yTop)
	local fh = lg.getFont():getHeight()

	return yTop + (ROW_H - fh) * 0.5 + 3
end

local function rowSliderY(yTop)
	return yTop + (ROW_H - SLIDER_H) * 0.5
end

local function drawRowHighlight(view, hovered)
	if hovered then
		local r = view.bounds

		lg.setColor(1, 1, 1, 0.06)
		lg.rectangle("fill", r.x, r.y, r.w, r.h, 6, 6)
	end
end

-- Row renderers
local function drawSliderRow(row, view, hovered)
	local x, yTop = view.bounds.x, view.bounds.y
	Text.printShadow(row.label, x, rowTextY(yTop))

	local sliderX = view.sliderBounds.x
	local sliderY = view.sliderBounds.y

	local t = max(0, min(1, row.get()))

	lg.setColor(0, 0, 0, 0.35)
	lg.rectangle("fill", sliderX, sliderY, SLIDER_W, SLIDER_H, 4, 4)

	if t > 0 then
		lg.setColor(row.color)
		lg.rectangle("fill", sliderX, sliderY, SLIDER_W * t, SLIDER_H, 4, 4)
	end

	local thumbX = sliderX + SLIDER_W * t
	local thumbY = sliderY + 5
	local grow = (hovered or draggingSlider == row.id) and 2 or 0

	if focusedRow == row.id then
		lg.setColor(row.color[1], row.color[2], row.color[3], 0.8)
		lg.setLineWidth(2)
		lg.rectangle("line", sliderX - 5, sliderY - 7, SLIDER_W + 10, SLIDER_H + 14, 7, 7)
		lg.setLineWidth(1)
	end

	lg.setColor(row.color[1], row.color[2], row.color[3], 0.25)
	lg.circle("fill", thumbX, thumbY, THUMB_R + grow + 3)

	lg.setColor(1, 1, 1, 1)
	lg.circle("fill", thumbX, thumbY, THUMB_R + grow)

	if row.valueFormatter then
		lg.setColor(colorText)
		Text.printfShadow(row.valueFormatter(t), sliderX + SLIDER_W + SLIDER_VALUE_GAP,
			rowTextY(yTop), SLIDER_VALUE_W, "right")
	end
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
	Text.printfShadow(row.valueFormatter(row), x + LABEL_W, rowTextY(yTop), SLIDER_W + 20, "right")
end

local function drawActionRow(row, x, yTop)
	Text.printShadow(row.label, x, rowTextY(yTop))

	if row.valueLabel then
		local valueLabel = type(row.valueLabel) == "function" and row.valueLabel() or row.valueLabel
		Text.printfShadow(valueLabel, x + LABEL_W - 16, rowTextY(yTop), 130, "right")
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

local function drawRow(view, hovered)
	drawRowHighlight(view, hovered)
	lg.setColor(colorText)
	SettingsControls.dispatch(view.row, "draw", view, hovered, controlContext)
end

local function contains(rect, x, y)
	return rect and x >= rect.x and x <= rect.x + rect.w
		and y >= rect.y and y <= rect.y + rect.h
end

-- Interaction geometry is layout state, not a side effect of rendering. Build
-- it once so update, drawing, and input all operate on the same frame's rows.
local function layoutRows()
	rowViews = {}
	for i, row in ipairs(getActiveRows()) do
		local yTop = rowsStartY + (i - 1) * activeLineH - rowsScroll.offset
		local view = {
			row = row,
			index = i,
			bounds = {x = listX, y = yTop, w = ROW_W, h = ROW_H},
			visible = yTop + ROW_H >= rowsViewportY and yTop <= rowsViewportY + rowsViewportH,
		}
		if row.type == "slider" then
			view.sliderBounds = {x = listX + LABEL_W, y = rowSliderY(yTop), w = SLIDER_W, h = SLIDER_H}
		end
		rowViews[#rowViews + 1] = view
	end
	layoutDirty = false
end


function Screen.load()
	Hotkeys.refreshFromSave()
	keybindCapture:close()
	confirmation = ConfirmationDialog.new()
	rowsScroll:reset()
	focusedRow = nil
	activeTabId = nil
	tabTime = 0

	tabs = buildTabs()
	activeTabId = tabs[1] and tabs[1].id

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
		tabAnim[i] = (tabs[i].id == activeTabId) and 1 or 0
	end

	cachedWindowW, cachedWindowH = nil, nil
	requestLayoutMeasurement()
end

local function updatePanelLayout(sw, sh)
	local cx = floor(sw * 0.5)
	Fonts.set("menu")
	local rows = getActiveRows()
	local _, activeTab = getActiveTab()
	local widestLabel = 0
	for _, row in ipairs(rows) do
		widestLabel = max(widestLabel, lg.getFont():getWidth(row.label or ""))
	end
	LABEL_W = min(280, max(180, widestLabel + 24))
	ROW_W = LABEL_W + SLIDER_W + SLIDER_VALUE_GAP + SLIDER_VALUE_W

	if not isControlsTab(activeTab) then
		keybindCapture:close()
	end

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
	layoutRows()

	-- Buttons (layout in update, like pause)
	buttonsStartY = boxY + boxH - paddingY - btnBlockH
	for i, btn in ipairs(buttons) do
		btn.x = cx - btn.w * 0.5
		btn.y = buttonsStartY + (i - 1) * gap
	end
	local tabsTotalW = (#tabs * tabW) + (max(0, #tabs - 1) * tabGap)
	local tabsStartX = cx - tabsTotalW * 0.5
	local tabsY = boxY + boxH + 4

	tabViews = {}
	for i, tab in ipairs(tabs) do
		tabViews[i] = {tab = tab, index = i, bounds = {
			x = tabsStartX + (i - 1) * (tabW + tabGap), y = tabsY, w = tabW, h = tabH,
		}}
	end

	layoutMeasurementDirty = false
end

local function updateTabAnimations(dt)
	local mouseX, mouseY = lm.getPosition()
	for i, view in ipairs(tabViews) do
		local hovered = contains(view.bounds, mouseX, mouseY)
		local target = (view.tab.id == activeTabId) and 1 or (hovered and 0.65 or 0)
		local a = tabAnim[i] or 0
		tabAnim[i] = a + (target - a) * min(1, dt * tabAnimSpeed)
	end
end

local function updateButtons(dt)
	Button.updateList(buttons, dt)
end

local function updateDraggedSlider()
	if draggingSlider then
		for _, view in ipairs(rowViews) do
			if view.row.id == draggingSlider then
				SettingsControls.dispatch(view.row, "setFromPointer", view, lm.getX(), controlContext)
				break
			end
		end
	end
end

function Screen.update(dt)
	if State.mode ~= "settings_gameplay" then
		Backdrop.update(dt)
	end
	tabTime = tabTime + dt

	local sw, sh = lg.getDimensions()
	if sw ~= cachedWindowW or sh ~= cachedWindowH then
		cachedWindowW, cachedWindowH = sw, sh
		requestLayoutMeasurement()
	end
	if layoutMeasurementDirty then
		updatePanelLayout(sw, sh)
	elseif layoutDirty then
		layoutRows()
	end
	if confirmation:isOpen() then
		confirmation:update(dt)
	else
		updateTabAnimations(dt)
		updateButtons(dt)
		updateDraggedSlider()
	end
end

function Screen.enter()
	-- Opening can follow a locale or settings change while this shared screen was
	-- inactive, so remeasure labels and row counts rather than only repositioning.
	requestLayoutMeasurement()
end

function Screen.resize(w, h)
	-- Keep the callback cheap; update owns layout recomputation and also verifies
	-- these cached values against the graphics dimensions.
	cachedWindowW, cachedWindowH = w, h
	requestLayoutMeasurement()
end

function Screen.localizationChanged()
	-- Localized row collections are rebuilt by their owner before this hook.
	-- Widths and counts may both have changed, requiring a complete pass.
	tabs = buildTabs()
	if not getActiveTab() then
		activeTabId = tabs[1] and tabs[1].id
	end
	requestLayoutMeasurement()
end

function Screen.draw()
	local sw, sh = lg.getDimensions()
	local mouseX, mouseY = lm.getPosition()
	Tooltip.hide()

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
	for _, view in ipairs(rowViews) do
		if view.visible then
			drawRow(view, contains(view.bounds, mouseX, mouseY) or focusedRow == view.row.id)
		end
	end
	lg.setScissor()

	local describedRow
	for _, view in ipairs(rowViews) do
		if view.visible and contains(view.bounds, mouseX, mouseY) then
			describedRow = view.row
			break
		end
	end
	if describedRow and describedRow.description then
		Tooltip.show({
			title = describedRow.label,
			rows = {{kind = "text", text = describedRow.description}},
		})
	end

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
		for _, view in ipairs(rowViews) do
			if view.row.id == keybindCapture.rowId then
				local focusedRect = view.visible and view.bounds
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
	for i, view in ipairs(tabViews) do
		local rect = view.bounds
		local tab = view.tab
		local hovered = contains(rect, mouseX, mouseY)
		local active = tab.id == activeTabId
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

	local _, activeTab = getActiveTab()
	if isControlsTab(activeTab) and keybindCapture.conflictMessage then
		lg.setColor(colorText)
		Text.printfShadow(keybindCapture.conflictMessage, listX, buttonsStartY - 24, ROW_W, "left")
	end

	confirmation:draw()
end

function Screen.keypressed(key)
	if confirmation:isOpen() then
		return confirmation:keypressed(key)
	end
	local rows = getActiveRows()
	if keybindCapture:keypressed(key, rows) then
		return
	end

	if key == "up" or key == "down" then
		if #rowViews > 0 then
			local direction = key == "up" and -1 or 1
			local focusedIndex
			for i, view in ipairs(rowViews) do
				if view.row.id == focusedRow then focusedIndex = i; break end
			end
			focusedIndex = Util.clamp((focusedIndex or (direction > 0 and 0 or #rowViews + 1)) + direction, 1, #rowViews)
			local focusedView = rowViews[focusedIndex]
			focusedRow = focusedView.row.id
			local rowTop = (focusedView.index - 1) * activeLineH
			local rowBottom = rowTop + ROW_H
			if rowTop < rowsScroll.offset then
				local previousOffset = rowsScroll.offset
				rowsScroll:move(rowTop - rowsScroll.offset)
				if rowsScroll.offset ~= previousOffset then
					requestRowLayout()
				end
			elseif rowBottom > rowsScroll.offset + rowsViewportH then
				local previousOffset = rowsScroll.offset
				rowsScroll:move(rowBottom - rowsScroll.offset - rowsViewportH)
				if rowsScroll.offset ~= previousOffset then
					requestRowLayout()
				end
			end
			Sound.play("uiMove")
		end
		return
	end

	if (key == "left" or key == "right") and focusedRow then
		for _, view in ipairs(rowViews) do
			if view.row.id == focusedRow then
				SettingsControls.dispatch(view.row, "adjust", key == "left" and -1 or 1, controlContext)
				break
			end
		end
		return
	end

	if (key == "return" or key == "space") and focusedRow then
		for _, view in ipairs(rowViews) do
			if view.row.id == focusedRow then
				SettingsControls.dispatch(view.row, "activate", view, controlContext)
				break
			end
		end
		return
	end

	if key == "escape" then
		exitToMenu()
	end
end

function Screen.leave()
	draggingSlider = nil
	flushSettingsNow()
	keybindCapture:close()
	confirmation = ConfirmationDialog.new()
end

function Screen.gamepadpressed(_, button)
	local mappedKey = ({
		dpup = "up",
		dpdown = "down",
		dpleft = "left",
		dpright = "right",
		a = "return",
		b = "escape",
	})[button]
	if mappedKey then
		Screen.keypressed(mappedKey)
		return true
	end
end

local function findViewAt(views, x, y)
	for _, view in ipairs(views) do
		if view.visible ~= false and contains(view.bounds, x, y) then
			return view
		end
	end
end

controlContext = {
	drawSlider = drawSliderRow,
	drawToggle = drawToggleRow,
	drawKeybind = drawKeybindRow,
	drawAction = drawActionRow,
	drawInfo = drawInfoRow,
	sliderKeyStep = SLIDER_KEY_STEP,
	capture = keybindCapture,
	changed = settingsChanged,
	flush = flushSettingsNow,
	beginDrag = function(view) draggingSlider = view.row.id end,
}

function Screen.mousepressed(x, y, button)
	if confirmation:isOpen() then
		return confirmation:mousepressed(x, y, button)
	end
	if button == 1 then
		local tabView = findViewAt(tabViews, x, y)
		if tabView then
			switchTab(tabView)
			return true
		end

		local rowView = findViewAt(rowViews, x, y)
		if rowView then
			if contains(rowView.sliderBounds, x, y) then
				SettingsControls.dispatch(rowView.row, "setFromPointer", rowView, x, controlContext)
			else
				SettingsControls.dispatch(rowView.row, "activate", rowView, controlContext)
			end
			return true
		end
	end

	-- Buttons (unchanged)
	return Button.mousepressedList(buttons, x, y, button)
end

function Screen.mousereleased(x, y, button)
	if confirmation:isOpen() then
		return confirmation:mousereleased(x, y, button)
	end
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

	local previousOffset = rowsScroll.offset
	rowsScroll:move(-y * activeLineH)
	if rowsScroll.offset ~= previousOffset then
		requestRowLayout()
	end
end

return Screen
