local Backdrop = require("scenes.backdrop")
local Button = require("ui.button")
local EnemyDefs = require("world.enemy_defs")
local EnemyRenderer = require("render.enemy_renderer")
local Fonts = require("core.fonts")
local L = require("core.localization")
local Maps = require("world.map_defs")
local Medals = require("ui.medals")
local Model = require("ui.career_model")
local TowerRenderer = require("render.tower_renderer")
local Save = require("core.save")
local ScrollView = require("ui.scroll_view")
local Sound = require("systems.sound")
local Text = require("ui.text")
local Theme = require("core.theme")
local TowerDefs = require("world.tower_defs")
local AchievementDefs = require("systems.achievement_defs")

local lg = love.graphics
local floor, max, min = math.floor, math.max, math.min

local Screen = {}
local TABS = {"career", "records", "codex"}
local ENEMY_ORDER = {
	"grunt", "runner", "tank", "regenerator", "warcaller", "summoner",
	"boss", "boss_summoner", "boss_suppression", "boss_ravager", "boss_phasewalker", "boss_gatecrasher",
}
local TOWER_ORDER = {"lancer", "slow", "cannon", "shock", "poison", "plasma"}
local MEDAL_RANK = {easy = 1, normal = 2, hard = 3}
local TAB_W, TAB_H, TAB_GAP = 150, 38, 10
local PAD, ROW_H, CODEX_ROW_H = 26, 58, 72
local scroll = ScrollView.new()
local selectedTab = 1
local selectedEnemy = 1
local tabs, backButton = {}, nil
local towerStats, towerKills, careerStats, records, enemies = {}, 0, {}, {}, {}
local portraits = {}
local layout = {}

local function pointInRect(px, py, rect)
	return rect and px >= rect.x and px <= rect.x + rect.w and py >= rect.y and py <= rect.y + rect.h
end

local function panel(x, y, w, h, color)
	lg.setColor(Theme.outline.color)
	lg.rectangle("fill", x - 3, y - 3, w + 6, h + 6, 12)
	lg.setColor(color or Theme.ui.panel)
	lg.rectangle("fill", x, y, w, h, 9)
end

local function refreshData()
	towerStats, towerKills = Model.towers(Save.data, TowerDefs, TOWER_ORDER)
	careerStats = Model.career(Save.data, Maps, AchievementDefs)
	records = Model.records(Save.data, Maps)
	enemies = Model.enemies(Save.data, EnemyDefs, ENEMY_ORDER)
	for _, enemy in ipairs(enemies) do
		portraits[enemy.kind] = portraits[enemy.kind] or EnemyRenderer.newEnemyPortrait(enemy.kind)
	end
	selectedEnemy = min(max(1, selectedEnemy), max(1, #enemies))
end

local function goBack()
	Sound.play("uiBack")
	require("ui.menu.menu").set("menu")
end

local function switchTab(index)
	index = ((index - 1) % #TABS) + 1
	if index ~= selectedTab then
		selectedTab = index
		scroll:reset()
		Sound.play("uiMove")
	end
end

local function updateLayout()
	local sw, sh = lg.getDimensions()
	local panelW = min(1100, sw - 56)
	local panelH = min(720, sh - 56)
	layout.panel = {x = floor((sw - panelW) * 0.5), y = floor((sh - panelH) * 0.5), w = panelW, h = panelH}
	layout.titleY = layout.panel.y + 21
	local tabsW = #TABS * TAB_W + (#TABS - 1) * TAB_GAP
	local tabsX = floor((sw - tabsW) * 0.5)
	for i, tab in ipairs(tabs) do
		tab.x, tab.y, tab.w, tab.h = tabsX + (i - 1) * (TAB_W + TAB_GAP), layout.panel.y + 76, TAB_W, TAB_H
	end
	layout.content = {
		x = layout.panel.x + PAD,
		y = layout.panel.y + 132,
		w = layout.panel.w - PAD * 2,
		h = layout.panel.h - 132 - 72,
	}
	if backButton then
		backButton.x, backButton.y, backButton.w, backButton.h = layout.panel.x + PAD, layout.panel.y + layout.panel.h - 49, 130, 36
	end
end

function Screen.load()
	tabs = {}
	for index, id in ipairs(TABS) do
		tabs[index] = {id = id, label = L("career.tabs." .. id), onClick = function() switchTab(index) end}
	end
	backButton = {id = "back", label = L("menu.back"), onClick = goBack}
	refreshData()
	updateLayout()
end

function Screen.enter()
	refreshData()
	scroll:reset()
	Backdrop.start()
end

function Screen.update(dt)
	Backdrop.update(dt)
	updateLayout()
	local mx, my = love.mouse.getPosition()
	Button.updateList(tabs, dt, mx, my)
	Button.update(backButton, mx, my, dt)
	local contentRows = selectedTab == 2 and #records * ROW_H or selectedTab == 3 and #enemies * CODEX_ROW_H or 0
	scroll:update(contentRows, layout.content.h)
end

local function drawHeader()
	local p = layout.panel
	Fonts.set("title")
	lg.setColor(Theme.ui.text)
	Text.printfShadow(L("career.title"), p.x, layout.titleY, p.w, "center")
	Fonts.set("ui")
	for index, tab in ipairs(tabs) do
		tab.textColor = index == selectedTab and Theme.ui.selected or Theme.ui.text
		Button.draw(tab)
	end
end

local function drawTowerIcon(kind, cx, cy, scale)
	lg.push("all")
	lg.translate(cx, cy)
	lg.scale(scale or 1)
	TowerRenderer.drawTowerVisual(kind, 0, 0, -math.pi * 0.5, 0, 1)
	lg.pop()
end

local function towerRow(tower, x, y, w, h)
	local accent = Theme.tower[tower.kind] or Theme.ui.selected
	panel(x, y, w, h, Theme.ui.panel2)
	drawTowerIcon(tower.kind, x + 38, y + h * 0.5, 1)

	Fonts.set("menu")
	lg.setColor(Theme.ui.text)
	Text.printShadow(L(tower.nameKey), x + 76, y + 10)
	Fonts.set("version")
	lg.setColor(Theme.ui.text[1], Theme.ui.text[2], Theme.ui.text[3], 0.48)
	Text.printShadow(L("career.lifetimeKills"), x + 76, y + 38)
	Fonts.set("menu")
	lg.setColor(accent)
	Text.printfShadow(Model.formatNumber(tower.kills), x + w - 150, y + 10, 132, "right")

	local barX, barY, barW, barH = x + 76, y + h - 16, w - 94, 8
	lg.setColor(0, 0, 0, 0.34)
	lg.rectangle("fill", barX, barY, barW, barH, 4)
	if tower.killRatio > 0 then
		lg.setColor(accent[1], accent[2], accent[3], 0.95)
		lg.rectangle("fill", barX, barY, max(4, barW * tower.killRatio), barH, 4)
	end
end

local function statPanel(title, stats, x, y, w, h)
	panel(x, y, w, h, Theme.ui.panel2)
	Fonts.set("menu")
	lg.setColor(Theme.ui.text)
	Text.printShadow(title, x + 18, y + 10)
	local top = y + 49
	local rowH = (h - 57) / #stats
	for index, stat in ipairs(stats) do
		local rowY = top + (index - 1) * rowH
		if index > 1 then
			lg.setColor(Theme.ui.text[1], Theme.ui.text[2], Theme.ui.text[3], 0.14)
			lg.rectangle("fill", x + 18, rowY, w - 36, 1)
		end
		Fonts.set("ui")
		lg.setColor(Theme.ui.text)
		Text.printShadow(stat[1], x + 20, rowY + 7)
		Text.printfShadow(stat[2], x + w - 170, rowY + 7, 150, "right")
	end
end

local function drawCareer()
	local c = layout.content
	local gap, headingH = 18, 42
	local leftW = floor(c.w * 0.57)
	local rightX, rightW = c.x + leftW + gap, c.w - leftW - gap
	local rowGap = 8
	local rowH = (c.h - headingH - rowGap * (#towerStats - 1)) / #towerStats
	Fonts.set("ui")
	lg.setColor(Theme.ui.text)
	Text.printShadow(L("career.towerLegacy"), c.x, c.y + 2)
	Fonts.set("tooltip")
	lg.setColor(Theme.ui.text[1], Theme.ui.text[2], Theme.ui.text[3], 0.62)
	Text.printfShadow(L("career.totalLifetimeKills", Model.formatNumber(towerKills)), c.x, c.y + 5, leftW, "right")
	for index, tower in ipairs(towerStats) do
		towerRow(tower, c.x, c.y + headingH + (index - 1) * (rowH + rowGap), leftW, rowH)
	end

	local sectionGap = 16
	local campaignH = floor((c.h - sectionGap) * 0.44)
	statPanel(L("career.campaignProgress"), {
		{L("career.mapsCleared"), Model.formatNumber(careerStats.mapsCleared) .. " / " .. Model.formatNumber(careerStats.totalMaps)},
		{L("career.medalsEarned"), Model.formatNumber(careerStats.medals) .. " / " .. Model.formatNumber(careerStats.totalMedals)},
		{L("career.enemiesDefeated"), Model.formatNumber(careerStats.enemiesKilled)},
		{L("career.bossesDefeated"), Model.formatNumber(careerStats.bossesKilled)},
	}, rightX, c.y, rightW, campaignH)
	statPanel(L("career.lifetimeStats"), {
		{L("career.towersPlaced"), Model.formatNumber(careerStats.towerPlacements)},
		{L("career.towerKills"), Model.formatNumber(careerStats.towerKills)},
		{L("career.towerUpgrades"), Model.formatNumber(careerStats.towerUpgrades)},
		{L("career.damageDealt"), Model.formatNumber(careerStats.towerDamage)},
		{L("career.achievements"), Model.formatNumber(careerStats.achievements) .. " / " .. Model.formatNumber(careerStats.totalAchievements)},
	}, rightX, c.y + campaignH + sectionGap, rightW, c.h - campaignH - sectionGap)
end

local function drawRecords()
	local c = layout.content
	local nameW = max(170, c.w * 0.28)
	local colW = (c.w - nameW) / 4
	Fonts.set("tooltip")
	lg.setColor(Theme.ui.text[1], Theme.ui.text[2], Theme.ui.text[3], 0.66)
	local headers = {L("career.recordMedals"), L("career.recordScore"), L("career.recordTime"), L("career.recordLeaks")}
	Text.printShadow(L("career.recordMap"), c.x + 12, c.y + 4)
	for i, header in ipairs(headers) do Text.printfShadow(header, c.x + nameW + (i - 1) * colW, c.y + 4, colW, "center") end
	lg.setScissor(c.x, c.y + 30, c.w, c.h - 30)
	for index, row in ipairs(records) do
		local y = c.y + 30 + (index - 1) * ROW_H - scroll.offset
		if y + ROW_H >= c.y + 30 and y <= c.y + c.h then
			lg.setColor(index % 2 == 0 and Theme.ui.panel2 or Theme.ui.panel)
			lg.rectangle("fill", c.x, y, c.w, ROW_H - 4, 7)
			Fonts.set("ui"); lg.setColor(Theme.ui.text)
			Text.printShadow(L(row.nameKey), c.x + 12, y + 17)
			local values = {
				row.bestScore and Model.formatNumber(row.bestScore) or "—",
				row.fastestClear and Model.formatDuration(row.fastestClear) or "—",
				row.fewestLeaks ~= nil and Model.formatNumber(row.fewestLeaks) or "—",
			}
			local medalCount = MEDAL_RANK[row.completedDifficulty] or 0
			if medalCount > 0 then
				local clusterW = Medals.getClusterSize(9, 8)
				Medals.draw(c.x + nameW + (colW - clusterW) * 0.5, y + 16, medalCount, 9, 8, love.timer.getTime())
			else
				lg.setColor(Theme.ui.text)
				Text.printfShadow("—", c.x + nameW, y + 17, colW, "center")
			end
			for i, value in ipairs(values) do
				lg.setColor(Theme.ui.text)
				Text.printfShadow(value, c.x + nameW + i * colW, y + 17, colW, "center")
			end
		end
	end
	lg.setScissor()
end

local function drawScrollbar(contentRows, rowHeight)
	local c = layout.content
	scroll:update(contentRows * rowHeight, c.h)
	if not scroll:canScroll() then return end
	local thumbY, thumbH = scroll:getThumb(c.y, c.h, 30)
	local x = c.x + c.w - 5
	lg.setColor(0, 0, 0, 0.3)
	lg.rectangle("fill", x, c.y, 5, c.h, 3)
	lg.setColor(Theme.ui.text[1], Theme.ui.text[2], Theme.ui.text[3], 0.42)
	lg.rectangle("fill", x, thumbY, 5, thumbH, 3)
end

local function drawUnknownPortrait(x, y)
	Fonts.set("title"); lg.setColor(Theme.ui.text[1], Theme.ui.text[2], Theme.ui.text[3], 0.28)
	Text.printfShadow("?", x - 26, y - 25, 52, "center")
end

local function drawCodex()
	local c = layout.content
	local listW = min(420, c.w * 0.43)
	local listRect = {x = c.x, y = c.y, w = listW, h = c.h}
	lg.setScissor(listRect.x, listRect.y, listRect.w, listRect.h)
	for index, enemy in ipairs(enemies) do
		local y = listRect.y + (index - 1) * CODEX_ROW_H - scroll.offset
		if y + CODEX_ROW_H >= listRect.y and y <= listRect.y + listRect.h then
			local selected = index == selectedEnemy
			lg.setColor(selected and Theme.ui.buttonSelected or index % 2 == 0 and Theme.ui.panel2 or Theme.ui.panel)
			lg.rectangle("fill", listRect.x, y, listRect.w - 10, CODEX_ROW_H - 5, 8)
			if enemy.discovered then
				EnemyRenderer.drawEnemyPortrait(portraits[enemy.kind], listRect.x + 38, y + 34, love.timer.getTime())
			else
				drawUnknownPortrait(listRect.x + 38, y + 34)
			end
			Fonts.set("ui"); lg.setColor(Theme.ui.text)
			Text.printShadow(enemy.discovered and L(enemy.def.nameKey) or L("career.unknownEnemy"), listRect.x + 76, y + 14)
			Fonts.set("version"); lg.setColor(Theme.ui.text[1], Theme.ui.text[2], Theme.ui.text[3], 0.62)
			Text.printShadow(enemy.discovered and L("career.enemyKills", Model.formatNumber(enemy.kills)) or L("career.notEncountered"), listRect.x + 76, y + 41)
		end
	end
	lg.setScissor()

	local enemy = enemies[selectedEnemy]
	local dx, dw = c.x + listW + 22, c.w - listW - 22
	panel(dx, c.y, dw, c.h, Theme.ui.panel2)
	if not enemy or not enemy.discovered then
		drawUnknownPortrait(dx + dw * 0.5, c.y + 105)
		Fonts.set("menu"); lg.setColor(Theme.ui.text)
		Text.printfShadow(L("career.unknownEnemy"), dx + 20, c.y + 155, dw - 40, "center")
		Fonts.set("ui"); lg.setColor(Theme.ui.text[1], Theme.ui.text[2], Theme.ui.text[3], 0.65)
		Text.printfShadow(L("career.discoverHint"), dx + 28, c.y + 205, dw - 56, "center")
		return
	end
	EnemyRenderer.drawEnemyPortrait(portraits[enemy.kind], dx + dw * 0.5, c.y + 88, love.timer.getTime())
	Fonts.set("menu"); lg.setColor(Theme.ui.text)
	Text.printfShadow(L(enemy.def.nameKey), dx + 20, c.y + 132, dw - 40, "center")
	Fonts.set("ui"); lg.setColor(Theme.ui.text[1], Theme.ui.text[2], Theme.ui.text[3], 0.8)
	Text.printfShadow(L(enemy.def.descriptionKey), dx + 34, c.y + 180, dw - 68, "center")
	local statsY = c.y + c.h - 122
	lg.setColor(Theme.ui.text[1], Theme.ui.text[2], Theme.ui.text[3], 0.12)
	lg.rectangle("fill", dx + 28, statsY - 20, dw - 56, 2)
	local stats = {
		{L("career.kills"), Model.formatNumber(enemy.kills)},
		{L("career.leaks"), Model.formatNumber(enemy.leaks)},
		{L("career.fastestKill"), enemy.fastestKill and L("career.seconds", enemy.fastestKill) or "—"},
	}
	for i, stat in ipairs(stats) do
		local sx = dx + (i - 1) * dw / 3
		Fonts.set("tooltip"); lg.setColor(Theme.ui.text[1], Theme.ui.text[2], Theme.ui.text[3], 0.62)
		Text.printfShadow(stat[1], sx, statsY, dw / 3, "center")
		Fonts.set("ui"); lg.setColor(Theme.ui.text)
		Text.printfShadow(stat[2], sx, statsY + 29, dw / 3, "center")
	end
end

function Screen.draw()
	Backdrop.draw()
	local p = layout.panel
	panel(p.x, p.y, p.w, p.h, Theme.ui.backdrop)
	drawHeader()
	if selectedTab == 1 then
		drawCareer()
	elseif selectedTab == 2 then
		drawRecords()
		drawScrollbar(#records, ROW_H)
	else
		drawCodex()
		drawScrollbar(#enemies, CODEX_ROW_H)
	end
	Fonts.set("ui"); Button.draw(backButton)
end

function Screen.mousepressed(x, y, button)
	if Button.mousepressedList(tabs, x, y, button) or Button.mousepressed(backButton, x, y, button) then return true end
	if button == 1 and selectedTab == 3 then
		local c = layout.content
		local listW = min(420, c.w * 0.43)
		if pointInRect(x, y, {x = c.x, y = c.y, w = listW, h = c.h}) then
			local index = floor((y - c.y + scroll.offset) / CODEX_ROW_H) + 1
			if enemies[index] then selectedEnemy = index; Sound.play("uiMove"); return true end
		end
	end
end

function Screen.mousereleased(x, y, button)
	return Button.mousereleasedList(tabs, x, y, button) or Button.mousereleased(backButton, x, y, button)
end

function Screen.wheelmoved(_, y)
	if selectedTab ~= 1 then scroll:move(-y * 46); return true end
end

function Screen.keypressed(key)
	if key == "escape" then goBack(); return true
	elseif key == "left" then switchTab(selectedTab - 1); return true
	elseif key == "right" then switchTab(selectedTab + 1); return true
	elseif key == "up" and selectedTab == 3 then
		selectedEnemy = max(1, selectedEnemy - 1)
		scroll.offset = min(scroll.offset, (selectedEnemy - 1) * CODEX_ROW_H)
		return true
	elseif key == "down" and selectedTab == 3 then
		selectedEnemy = min(#enemies, selectedEnemy + 1)
		local rowBottom = selectedEnemy * CODEX_ROW_H
		scroll.offset = max(scroll.offset, rowBottom - layout.content.h)
		return true
	elseif key == "pageup" then scroll:move(-layout.content.h * 0.8); return true
	elseif key == "pagedown" then scroll:move(layout.content.h * 0.8); return true end
end

function Screen.resize() updateLayout() end

return Screen
