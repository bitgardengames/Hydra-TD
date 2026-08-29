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

local rows = {}
local buttons = {}

local sliderRects = {}
local rowRects = {}
local tabRects = {}
local draggingSlider = nil
local focusedRow = nil
local controlContext

local tabs = {}
local activeTab = 1
local tabAnim = {}
local tabTime = 0
local keybindCapture = KeybindCapture.new()

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

local function flushSettingsNow()
	Save.flush()
end

local function switchTab(nextTab)
	local clamped = Util.clamp(nextTab, 1, #tabs)

	if clamped == activeTab then return end

	if draggingSlider then
		flushSettingsNow()
	end
	activeTab = clamped
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
	local tab = tabs[activeTab]

	return tab and tab.rows or {}
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

	if focusedRow == index then
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

local function drawRow(row, hovered, x, yTop, index)
	drawRowHighlight(index, hovered)
	lg.setColor(colorText)
	SettingsControls.dispatch(row, "draw", x, yTop, hovered, index, controlContext)
end

local function contains(rect, x, y)
	return rect and x >= rect.x and x <= rect.x + rect.w
		and y >= rect.y and y <= rect.y + rect.h
end

-- Interaction geometry is layout state, not a side effect of rendering. Build
-- it once so update, drawing, and input all operate on the same frame's rows.
local function layoutRows()
	for i, row in ipairs(rows) do
		local yTop = rowsStartY + (i - 1) * activeLineH - rowsScroll.offset
		if yTop + ROW_H >= rowsViewportY and yTop <= rowsViewportY + rowsViewportH then
			local rowRect = rowRects[i] or {}
			rowRect.x, rowRect.y, rowRect.w, rowRect.h = listX, yTop, ROW_W, ROW_H
			rowRects[i] = rowRect
			if row.type == "slider" then
				local sliderRect = sliderRects[i] or {}
				sliderRect.x, sliderRect.y = listX + LABEL_W, rowSliderY(yTop)
				sliderRect.w, sliderRect.h = SLIDER_W, SLIDER_H
				sliderRects[i] = sliderRect
			else
				sliderRects[i] = nil
			end
		else
			rowRects[i] = nil
			sliderRects[i] = nil
		end
	end
	for i in pairs(rowRects) do
		if i > #rows then rowRects[i] = nil end
	end
	for i in pairs(sliderRects) do
		if i > #rows then sliderRects[i] = nil end
	end
	layoutDirty = false
end


function Screen.load()
	Hotkeys.refreshFromSave()
	keybindCapture:close()
	rowsScroll:reset()
	focusedRow = nil
	activeTab = 1
	tabTime = 0

	tabs = SettingsModel.build(keybindCapture)

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

	cachedWindowW, cachedWindowH = nil, nil
	requestLayoutMeasurement()
end

local function updatePanelLayout(sw, sh)
	local cx = floor(sw * 0.5)
	Fonts.set("menu")
	rows = getActiveRows()
	local widestLabel = 0
	for _, row in ipairs(rows) do widestLabel = max(widestLabel, lg.getFont():getWidth(row.label or "")) end
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

	for i, tab in ipairs(tabs) do
		local rect = tabRects[i] or {}
		rect.x, rect.y = tabsStartX + (i - 1) * (tabW + tabGap), tabsY
		rect.w, rect.h = tabW, tabH
		tabRects[i] = rect
	end
	for i = #tabs + 1, #tabRects do tabRects[i] = nil end

	layoutMeasurementDirty = false
end

local function updateTabAnimations(dt)
	local mouseX, mouseY = lm.getPosition()
	for i, rect in ipairs(tabRects) do
		local hovered = contains(rect, mouseX, mouseY)
		local target = (i == activeTab) and 1 or (hovered and 0.65 or 0)
		local a = tabAnim[i] or 0
		tabAnim[i] = a + (target - a) * min(1, dt * tabAnimSpeed)
	end
end

local function updateButtons(dt)
	Button.updateList(buttons, dt)
end

local function updateDraggedSlider()
	if draggingSlider then
		local rect = sliderRects[draggingSlider]

		if rect then
			SettingsControls.dispatch(rows[draggingSlider], "setFromPointer",
				draggingSlider, lm.getX(), controlContext)
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
	updateTabAnimations(dt)
	updateButtons(dt)
	updateDraggedSlider()
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
	tabs = SettingsModel.build(keybindCapture)
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
	for i, row in ipairs(rows) do
		local rect = rowRects[i]
		if rect then
			drawRow(row, contains(rect, mouseX, mouseY) or focusedRow == i, rect.x, rect.y, i)
		end
	end
	lg.setScissor()

	local describedRow
	for i, rect in pairs(rowRects) do
		if contains(rect, mouseX, mouseY) then
			describedRow = rows[i]
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
		local hovered = contains(rect, mouseX, mouseY)
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

	if key == "up" or key == "down" then
		if #rows > 0 then
			local direction = key == "up" and -1 or 1
			focusedRow = Util.clamp((focusedRow or (direction > 0 and 0 or #rows + 1)) + direction, 1, #rows)
			local rowTop = (focusedRow - 1) * activeLineH
			local rowBottom = rowTop + ROW_H
			if rowTop < rowsScroll.offset then
				local previousOffset = rowsScroll.offset
				rowsScroll:move(rowTop - rowsScroll.offset)
				if rowsScroll.offset ~= previousOffset then requestRowLayout() end
			elseif rowBottom > rowsScroll.offset + rowsViewportH then
				local previousOffset = rowsScroll.offset
				rowsScroll:move(rowBottom - rowsScroll.offset - rowsViewportH)
				if rowsScroll.offset ~= previousOffset then requestRowLayout() end
			end
			Sound.play("uiMove")
		end
		return
	end

	if (key == "left" or key == "right") and focusedRow then
		SettingsControls.dispatch(rows[focusedRow], "adjust", key == "left" and -1 or 1, controlContext)
		return
	end

	if (key == "return" or key == "space") and focusedRow then
		SettingsControls.dispatch(rows[focusedRow], "activate", focusedRow, controlContext)
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

local function findRectAt(rects, x, y)
	-- Row rectangles are intentionally sparse when the list is scrolled because
	-- only visible rows are drawn and hit-testable.
	for i, rect in pairs(rects) do
		if contains(rect, x, y) then
			return i
		end
	end
end

controlContext = {
	drawSlider = drawSliderRow,
	drawToggle = drawToggleRow,
	drawKeybind = drawKeybindRow,
	drawAction = drawActionRow,
	drawInfo = drawInfoRow,
	sliderRects = sliderRects,
	sliderKeyStep = SLIDER_KEY_STEP,
	capture = keybindCapture,
	changed = settingsChanged,
	flush = flushSettingsNow,
	beginDrag = function(index) draggingSlider = index end,
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
			if contains(sliderRects[rowIndex], x, y) then
				SettingsControls.dispatch(row, "setFromPointer", rowIndex, x, controlContext)
			else
				SettingsControls.dispatch(row, "activate", rowIndex, controlContext)
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

	local previousOffset = rowsScroll.offset
	rowsScroll:move(-y * activeLineH)
	if rowsScroll.offset ~= previousOffset then requestRowLayout() end
end

return Screen
