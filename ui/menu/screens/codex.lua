local Constants = require("core.constants")
local Theme = require("core.theme")
local Fonts = require("core.fonts")
local State = require("core.state")
local Button = require("ui.button")
local Text = require("ui.text")
local Backdrop = require("scenes.backdrop")
local Sound = require("systems.sound")
local L = require("core.localization")
local TowerDefs = require("world.tower_defs")
local ModuleDefs = require("systems.module_defs")
local TowerBranchDefs = require("world.tower_branch_defs")
local EnemyDefs = require("world.enemy_defs")
local EnemyModifiers = require("world.enemy_modifiers")

local Screen = {}

local lg = love.graphics
local floor = math.floor
local max = math.max
local min = math.min
local format = string.format

local colorText = Theme.ui.text
local colorDim = Theme.ui.screenDim
local colorBackdrop = Theme.ui.backdrop
local colorPanel = Theme.ui.panel
local colorPanel2 = Theme.ui.panel2
local colorSelected = Theme.ui.selected
local colorDisabled = {0.66, 0.68, 0.72, 1}
local colorOutline = Theme.outline.color

local outlineW = Theme.outline.width
local baseRadius = 18
local outerRadius = baseRadius + outlineW * 0.5
local innerRadius = baseRadius - outlineW * 0.25

local tabW = 158
local tabH = 34
local backW = 150
local backH = 38
local listRowH = 40
local detailLineH = 21
local scrollStep = 1

local tabs = {
	{id = "towers", labelKey = "codex.tabTowers"},
	{id = "upgrades", labelKey = "codex.tabUpgrades"},
	{id = "enemies", labelKey = "codex.tabEnemies"},
	{id = "modifiers", labelKey = "codex.tabModifiers"},
}

local buttons = {}
local activeTab = "towers"
local selectedIndex = 1
local scrollIndex = 1
local entriesByTab = {}
local backMode = "menu"

local towerOrder = {"slow", "lancer", "poison", "cannon", "shock", "plasma"}
local enemyOrder = {"grunt", "runner", "tank", "regenerator", "shielder", "boss", "boss_summoner", "boss_displacement", "boss_suppression"}

local function getSortedIds(defs, preferredOrder)
	local ids = {}
	local used = {}

	for _, id in ipairs(preferredOrder or {}) do
		if defs[id] then
			ids[#ids + 1] = id
			used[id] = true
		end
	end

	local remaining = {}
	for id in pairs(defs) do
		if not used[id] then
			remaining[#remaining + 1] = id
		end
	end

	table.sort(remaining)
	for _, id in ipairs(remaining) do
		ids[#ids + 1] = id
	end

	return ids
end

local function statLine(labelKey, value)
	return format("%s: %s", L(labelKey), value)
end

local function formatNumber(value)
	if type(value) ~= "number" then
		return tostring(value or "-")
	end

	if value % 1 == 0 then
		return tostring(value)
	end

	return format("%.1f", value)
end

local function formatRange(px)
	if not px then
		return "-"
	end

	return format("%.1f", px / Constants.TILE)
end

local function addBehaviorLines(lines, behaviors)
	if not behaviors or #behaviors == 0 then
		return
	end

	local ids = {}
	for i = 1, #behaviors do
		ids[#ids + 1] = behaviors[i].id
	end

	lines[#lines + 1] = statLine("codex.behaviors", table.concat(ids, ", "))
end

local function buildTowers()
	local entries = {}

	for _, id in ipairs(getSortedIds(TowerDefs, towerOrder)) do
		local def = TowerDefs[id]
		local lines = {
			L(def.descKey),
			statLine("codex.cost", "$" .. formatNumber(def.cost)),
			statLine("codex.damage", formatNumber(def.damage)),
			statLine("codex.fireRate", format("%.2f/s", def.fireRate or 0)),
			statLine("codex.range", formatRange(def.range)),
		}

		addBehaviorLines(lines, def.behaviors)

		entries[#entries + 1] = {
			id = id,
			title = L(def.nameKey),
			subtitle = L("codex.towerSubtitle"),
			color = def.color,
			lines = lines,
		}
	end

	return entries
end

local function buildUpgrades()
	local entries = {}

	for _, towerId in ipairs(getSortedIds(TowerDefs, towerOrder)) do
		local towerDef = TowerDefs[towerId]

		for level = 2, 5 do
			local choices = TowerBranchDefs.getChoices(towerId, level) or {}

			for _, moduleId in ipairs(choices) do
				local def = ModuleDefs[moduleId]
				if def then
					local lines = {
						L(def.descKey),
						statLine("codex.tower", L(towerDef.nameKey)),
						statLine("codex.tier", level),
						statLine("codex.categoryLabel", L("codex.category." .. (def.category or "special"))),
					}

					addBehaviorLines(lines, def.behaviors)

					entries[#entries + 1] = {
						id = moduleId,
						title = L(def.nameKey),
						subtitle = L("codex.upgradeSubtitle", L(towerDef.nameKey), level),
						color = towerDef.color,
						lines = lines,
					}
				end
			end
		end
	end

	return entries
end

local function buildEnemies()
	local entries = {}

	for _, id in ipairs(getSortedIds(EnemyDefs, enemyOrder)) do
		local def = EnemyDefs[id]
		local lines = {
			statLine("codex.hp", formatNumber(def.hp)),
			statLine("codex.speed", formatNumber(def.speed)),
			statLine("codex.reward", "$" .. formatNumber(def.reward)),
			statLine("codex.score", formatNumber(def.score)),
			statLine("codex.radius", formatNumber(def.radius)),
		}

		if def.regen then
			lines[#lines + 1] = L("codex.regeneratingEnemy")
		end

		if def.shield then
			lines[#lines + 1] = L("codex.shieldedEnemy")
		end

		if def.boss then
			lines[#lines + 1] = L("codex.bossEnemy")
		end

		if def.mechanicPackage then
			lines[#lines + 1] = statLine("codex.mechanic", L("codex.mechanicPackage." .. def.mechanicPackage))
		end

		entries[#entries + 1] = {
			id = id,
			title = L(def.nameKey),
			subtitle = L(def.boss and "codex.enemyBossSubtitle" or "codex.enemySubtitle"),
			lines = lines,
		}
	end

	return entries
end

local function buildModifiers()
	local entries = {}

	for _, id in ipairs(getSortedIds(EnemyModifiers)) do
		local def = EnemyModifiers[id]
		local lines = {
			L(def.descKey),
			statLine("codex.categoryLabel", L("codex.modifierType." .. (def.type or "general"))),
		}

		if def.tags and #def.tags > 0 then
			local tags = {}
			for i = 1, #def.tags do
				tags[#tags + 1] = L("codex.modifierTag." .. def.tags[i])
			end
			lines[#lines + 1] = statLine("codex.tags", table.concat(tags, ", "))
		end

		entries[#entries + 1] = {
			id = id,
			title = L(def.nameKey),
			subtitle = L("codex.futureEnemyModifier"),
			lines = lines,
		}
	end

	return entries
end

local function rebuildEntries()
	entriesByTab = {
		towers = buildTowers(),
		upgrades = buildUpgrades(),
		enemies = buildEnemies(),
		modifiers = buildModifiers(),
	}
end

local function clampSelection()
	local entries = entriesByTab[activeTab] or {}
	selectedIndex = min(max(selectedIndex, 1), max(#entries, 1))
	scrollIndex = min(max(scrollIndex, 1), max(#entries, 1))
end

local function setTab(id)
	if activeTab ~= id then
		activeTab = id
		selectedIndex = 1
		scrollIndex = 1
		Sound.play("uiMove")
	end
end

local function scrollSelection(delta)
	local entries = entriesByTab[activeTab] or {}
	if #entries == 0 then
		return
	end

	selectedIndex = min(max(selectedIndex + delta, 1), #entries)

	local visibleRows = Screen.visibleRows or 1
	if selectedIndex < scrollIndex then
		scrollIndex = selectedIndex
	elseif selectedIndex >= scrollIndex + visibleRows then
		scrollIndex = selectedIndex - visibleRows + 1
	end
end

local function drawPanel(x, y, w, h)
	lg.setColor(colorOutline)
	lg.rectangle("fill", x - outlineW, y - outlineW, w + outlineW * 2, h + outlineW * 2, outerRadius)
	lg.setColor(colorBackdrop)
	lg.rectangle("fill", x, y, w, h, innerRadius)
end

local function drawWrapped(text, x, y, w, lineH, color)
	lg.setColor(color or colorText)
	local _, lines = lg.getFont():getWrap(text, w)
	Text.printfShadow(text, x, y, w, "left")

	return y + max(1, #lines) * lineH
end

function Screen.load()
	rebuildEntries()

	buttons = {}
	for _, tab in ipairs(tabs) do
		local tabId = tab.id
		local tabLabelKey = tab.labelKey

		buttons[#buttons + 1] = {
			id = tabId,
			label = L(tabLabelKey),
			w = tabW,
			h = tabH,
			onClick = function()
				setTab(tabId)
			end,
		}
	end

	buttons[#buttons + 1] = {
		id = "back",
		label = L("menu.back"),
		w = backW,
		h = backH,
		onClick = function()
			State.mode = State.codexBackMode or backMode
			Sound.play("uiBack")
		end,
	}
end

function Screen.enter(fromMode)
	backMode = (fromMode == "campaign") and "campaign" or "menu"
	rebuildEntries()
	clampSelection()
	Backdrop.start()
end

function Screen.update(dt)
	Backdrop.update(dt)

	local sw, sh = lg.getDimensions()
	local panelW = min(980, sw - 80)
	local panelX = floor((sw - panelW) * 0.5)
	local panelY = 64
	local contentY = panelY + 108
	local listW = 300
	local detailW = panelW - listW - 68
	local contentH = sh - contentY - 92

	Screen.layout = {
		panelX = panelX,
		panelY = panelY,
		panelW = panelW,
		panelH = sh - panelY * 2,
		contentY = contentY,
		listX = panelX + 28,
		listY = contentY,
		listW = listW,
		listH = contentH,
		detailX = panelX + listW + 52,
		detailY = contentY,
		detailW = detailW,
		detailH = contentH,
	}

	Screen.visibleRows = max(1, floor(contentH / listRowH))
	clampSelection()

	local mx, my = love.mouse.getPosition()
	local tabStartX = panelX + 28
	for i = 1, #tabs do
		local btn = buttons[i]
		btn.label = L(tabs[i].labelKey)
		btn.x = tabStartX + (i - 1) * (tabW + 10)
		btn.y = panelY + 58
		Button.update(btn, mx, my, dt)
	end

	local back = buttons[#buttons]
	back.label = L("menu.back")
	back.x = panelX + panelW - back.w - 28
	back.y = panelY + Screen.layout.panelH - back.h - 24
	Button.update(back, mx, my, dt)
end

function Screen.draw()
	local sw, sh = lg.getDimensions()
	local layout = Screen.layout
	if not layout then
		return
	end

	Backdrop.draw()

	lg.setColor(colorDim)
	lg.rectangle("fill", 0, 0, sw, sh)
	drawPanel(layout.panelX, layout.panelY, layout.panelW, layout.panelH)

	Fonts.set("title")
	lg.setColor(colorText)
	Text.printfShadow(L("codex.title"), layout.panelX, layout.panelY + 18, layout.panelW, "center")

	Fonts.set("menu")
	for i = 1, #tabs do
		local btn = buttons[i]
		Button.draw(btn)
		if tabs[i].id == activeTab then
			lg.setColor(colorSelected)
			lg.rectangle("fill", btn.x + 18, btn.y + btn.h + 4, btn.w - 36, 4, 2, 2)
		end
	end

	Fonts.set("ui")
	lg.setColor(colorPanel2)
	lg.rectangle("fill", layout.listX, layout.listY, layout.listW, layout.listH, 10, 10)
	lg.setColor(colorPanel)
	lg.rectangle("fill", layout.detailX, layout.detailY, layout.detailW, layout.detailH, 10, 10)

	local entries = entriesByTab[activeTab] or {}
	local visibleRows = Screen.visibleRows or 1
	local maxRow = min(#entries, scrollIndex + visibleRows - 1)

	for i = scrollIndex, maxRow do
		local entry = entries[i]
		local row = i - scrollIndex
		local x = layout.listX + 8
		local y = layout.listY + row * listRowH + 6
		local w = layout.listW - 16
		local selected = i == selectedIndex

		if selected then
			lg.setColor(colorSelected[1], colorSelected[2], colorSelected[3], 0.22)
			lg.rectangle("fill", x, y - 2, w, listRowH - 4, 8, 8)
		end

		if entry.color then
			lg.setColor(entry.color)
			lg.circle("fill", x + 14, y + 14, 7)
		end

		lg.setColor(selected and colorText or colorDisabled)
		Text.printShadow(entry.title, x + 30, y + 4)
	end

	local entry = entries[selectedIndex]
	if entry then
		local x = layout.detailX + 22
		local y = layout.detailY + 20
		local w = layout.detailW - 44

		Fonts.set("menu")
		lg.setColor(entry.color or colorText)
		Text.printShadow(entry.title, x, y)

		Fonts.set("ui")
		y = y + 36
		lg.setColor(colorDisabled)
		Text.printShadow(entry.subtitle, x, y)
		y = y + 36

		for i = 1, #entry.lines do
			y = drawWrapped(entry.lines[i], x, y, w, detailLineH, i == 1 and colorText or colorDisabled) + 10
			if y > layout.detailY + layout.detailH - 24 then
				break
			end
		end
	else
		lg.setColor(colorDisabled)
		Text.printfShadow(L("codex.empty"), layout.detailX, layout.detailY + 24, layout.detailW, "center")
	end

	lg.setColor(colorDisabled)
	Text.printfShadow(L("codex.hint"), layout.panelX, layout.panelY + layout.panelH - 34, layout.panelW, "center")

	Fonts.set("menu")
	Button.draw(buttons[#buttons])
end

function Screen.keypressed(key)
	if key == "escape" then
		State.mode = State.codexBackMode or backMode
		Sound.play("uiBack")
	elseif key == "up" then
		scrollSelection(-scrollStep)
		Sound.play("uiMove")
	elseif key == "down" then
		scrollSelection(scrollStep)
		Sound.play("uiMove")
	elseif key == "pageup" then
		scrollSelection(-(Screen.visibleRows or 1))
		Sound.play("uiMove")
	elseif key == "pagedown" then
		scrollSelection(Screen.visibleRows or 1)
		Sound.play("uiMove")
	elseif key == "left" or key == "right" then
		local tabIndex = 1
		for i, tab in ipairs(tabs) do
			if tab.id == activeTab then
				tabIndex = i
				break
			end
		end

		tabIndex = tabIndex + (key == "right" and 1 or -1)
		if tabIndex < 1 then
			tabIndex = #tabs
		elseif tabIndex > #tabs then
			tabIndex = 1
		end
		setTab(tabs[tabIndex].id)
	end
end

function Screen.mousepressed(x, y, button)
	for _, btn in ipairs(buttons) do
		if Button.mousepressed(btn, x, y, button) then
			return true
		end
	end

	local layout = Screen.layout
	if button == 1 and layout then
		if x >= layout.listX and x <= layout.listX + layout.listW and y >= layout.listY and y <= layout.listY + layout.listH then
			local row = floor((y - layout.listY) / listRowH)
			local index = scrollIndex + row
			local entries = entriesByTab[activeTab] or {}

			if entries[index] then
				selectedIndex = index
				Sound.play("uiMove")
				return true
			end
		end
	end
end

function Screen.mousereleased(x, y, button)
	for _, btn in ipairs(buttons) do
		if Button.mousereleased(btn, x, y, button) then
			return true
		end
	end
end

return Screen
