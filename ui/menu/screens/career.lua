local AchievementDefs = require("systems.achievement_defs")
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

local lg = love.graphics
local floor, max, min = math.floor, math.max, math.min

local Screen = {}
local TABS = {"career", "records", "codex"}
local ENEMY_ORDER = {
	"grunt", "runner", "tank", "regenerator", "warcaller", "summoner",
	"boss", "boss_summoner", "boss_suppression", "boss_ravager", "boss_phasewalker", "boss_gatecrasher",
}
local MEDAL_RANK = {easy = 1, normal = 2, hard = 3}
local TAB_W, TAB_H, TAB_GAP = 150, 38, 10
local PAD, ROW_H, CODEX_ROW_H = 26, 58, 72
local scroll = ScrollView.new()
local selectedTab = 1
local selectedEnemy = 1
local tabs, backButton = {}, nil
local career, records, enemies = {}, {}, {}
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
	career = Model.career(Save.data, Maps, AchievementDefs)
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

local function drawMapIcon(cx, cy, accent)
	lg.setColor(accent)
	lg.circle("fill", cx, cy - 5, 10)
	lg.polygon("fill", cx - 8, cy, cx + 8, cy, cx, cy + 15)
	lg.setColor(Theme.ui.panel2)
	lg.circle("fill", cx, cy - 5, 4)
end

local function drawSkullIcon(cx, cy, accent, crowned)
	lg.setColor(accent)
	lg.circle("fill", cx, cy - 2, 15)
	lg.rectangle("fill", cx - 10, cy + 6, 20, 9, 3)
	lg.setColor(Theme.ui.panel2)
	lg.circle("fill", cx - 6, cy - 3, 3)
	lg.circle("fill", cx + 6, cy - 3, 3)
	lg.rectangle("fill", cx - 2, cy + 7, 4, 8)
	if crowned then
		lg.setColor(Theme.medal.gold)
		lg.polygon("fill", cx - 15, cy - 13, cx - 11, cy - 24, cx - 3, cy - 16,
			cx + 5, cy - 25, cx + 15, cy - 13)
	end
end

local function drawTowerIcon(cx, cy)
	lg.push("all")
	lg.translate(cx, cy + 5)
	lg.scale(0.65)
	TowerRenderer.drawTowerVisual("cannon", 0, 0, -math.pi * 0.5, 0, 1)
	lg.pop()
end

local function drawGlyphIcon(cx, cy, accent, glyph)
	Fonts.set("menu")
	lg.setColor(accent)
	Text.printfShadow(glyph, cx - 24, cy - 17, 48, "center")
end

local function drawMedalIcon(cx, cy)
	for tier = 1, 3 do
		Medals.drawTier(cx + (tier - 2) * 19, cy, tier, 9, 1)
	end
end

local function statCard(x, y, w, h, label, value, accent, icon)
	panel(x, y, w, h, Theme.ui.panel2)
	lg.setColor(accent[1], accent[2], accent[3], 0.72)
	lg.rectangle("fill", x, y, 4, h, 2)
	local iconX, iconY = x + 42, y + h * 0.5
	lg.setColor(accent[1], accent[2], accent[3], 0.1)
	lg.circle("fill", iconX, iconY, min(29, h * 0.32))
	icon(iconX, iconY, accent)
	local textX, textW = x + 78, w - 90
	Fonts.set("tooltip")
	lg.setColor(Theme.ui.text[1], Theme.ui.text[2], Theme.ui.text[3], 0.7)
	Text.printfShadow(label, textX, y + h * 0.5 - 29, textW, "left")
	Fonts.set("menu")
	lg.setColor(accent or Theme.ui.text)
	Text.printfShadow(value, textX, y + h * 0.5 - 2, textW, "left")
end

local function drawCareer()
	local c = layout.content
	local gap = 16
	local columns = c.w >= 800 and 3 or 2
	local rows = math.ceil(9 / columns)
	local cardW = (c.w - gap * (columns - 1)) / columns
	local cardH = min(130, (c.h - gap * (rows - 1)) / rows)
	local cards = {
		{L("career.mapsCleared"), string.format("%d / %d", career.mapsCleared, career.totalMaps), Theme.ui.good, drawMapIcon},
		{L("career.medalsEarned"), string.format("%d / %d", career.medals, career.totalMedals), Theme.medal.gold, drawMedalIcon},
		{L("career.enemiesDefeated"), Model.formatNumber(career.enemiesKilled), Theme.tower.cannon, function(x, y, color) drawSkullIcon(x, y, color, false) end},
		{L("career.bossesDefeated"), Model.formatNumber(career.bossesKilled), Theme.effects.colors.boss, function(x, y, color) drawSkullIcon(x, y, color, true) end},
		{L("career.towersPlaced"), Model.formatNumber(career.towerPlacements), Theme.tower.lancer, drawTowerIcon},
		{L("career.towerKills"), Model.formatNumber(career.towerKills), Theme.tower.cannon, drawTowerIcon},
		{L("career.towerUpgrades"), Model.formatNumber(career.towerUpgrades), Theme.ui.selected, function(x, y, color) drawGlyphIcon(x, y, color, "▲") end},
		{L("career.damageDealt"), Model.formatNumber(career.towerDamage), Theme.ui.bad, function(x, y, color) drawGlyphIcon(x, y, color, "✦") end},
		{L("career.achievements"), string.format("%d / %d", career.achievements, career.totalAchievements), Theme.tower.shock, function(x, y, color) drawGlyphIcon(x, y, color, "★") end},
	}
	for index, card in ipairs(cards) do
		local col = (index - 1) % columns
		local row = floor((index - 1) / columns)
		statCard(c.x + col * (cardW + gap), c.y + row * (cardH + gap), cardW, cardH, card[1], card[2], card[3], card[4])
	end
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
