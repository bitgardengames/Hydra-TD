local AchievementDefs = require("systems.achievement_defs")
local Backdrop = require("scenes.backdrop")
local Button = require("ui.button")
local EnemyDefs = require("world.enemy_defs")
local EnemyTraits = require("world.enemy_traits")
local Fonts = require("core.fonts")
local L = require("core.localization")
local Save = require("core.save")
local Sound = require("systems.sound")
local State = require("core.state")
local Text = require("ui.text")
local Theme = require("core.theme")
local TowerDefs = require("world.tower_defs")
local TowerCodex = require("ui.tower_codex")
local Constants = require("core.constants")

local Screen = {}
local lg = love.graphics

local activeTab = "achievements"
local scroll = 0
local maxScroll = 0
local tabs = {}
local backButton = nil
local viewport = {x = 0, y = 0, w = 0, h = 0}
local rowHeight = 78
local intelRowHeight = 142
local towerRowHeight = TowerCodex.ENTRY_HEIGHT
local returnMode = "menu"

local function activeRowHeight()
	if activeTab == "intel" then return intelRowHeight end
	if activeTab == "towers" then return towerRowHeight end
	return rowHeight
end

local enemyOrder = {
	"grunt", "runner", "tank", "bulwark", "regenerator", "shieldbearer",
	"warcaller", "boss", "boss_summoner", "boss_displacement", "boss_suppression",
}

local function goBack()
	State.mode = returnMode
	returnMode = "menu"
	Sound.play("uiMove")
end

local function selectTab(id)
	if activeTab ~= id then
		activeTab = id
		scroll = 0
		Sound.play("uiMove")
	end
end

function Screen.load()
	tabs = {
		{id = "achievements", label = L("progress.achievements"), w = 180, h = 36, onClick = function() selectTab("achievements") end},
		{id = "intel", label = L("progress.enemyIntel"), w = 180, h = 36, onClick = function() selectTab("intel") end},
		{id = "towers", label = L("progress.towers"), w = 180, h = 36, onClick = function() selectTab("towers") end},
	}
	backButton = {label = L("menu.back"), w = 150, h = 36, onClick = goBack}
end

function Screen.openTower(kind, fromMode)
	activeTab, returnMode = "towers", fromMode or "menu"
	for i, towerKind in ipairs(Constants.TOWER_LIST) do
		if towerKind == kind then scroll = (i - 1) * towerRowHeight; break end
	end
	State.mode = "progress"
end

local function intelEntries()
	local result = {}
	local encountered = Save.data.meta.encounteredEnemies or {}

	for _, kind in ipairs(enemyOrder) do
		if encountered[kind] and EnemyDefs[kind] then
			result[#result + 1] = {kind = kind, def = EnemyDefs[kind]}
		end
	end

	return result
end

local function entryCount()
	if activeTab == "achievements" then
		return #AchievementDefs
	elseif activeTab == "towers" then
		return #Constants.TOWER_LIST
	end
	return #intelEntries()
end

function Screen.update(dt)
	Backdrop.update(dt)
	local sw, sh = lg.getDimensions()
	local panelW = math.min(900, sw - 80)
	viewport.x, viewport.y = (sw - panelW) * 0.5 + 24, 150
	viewport.w, viewport.h = panelW - 48, math.max(120, sh - 235)

	for i, tab in ipairs(tabs) do
		tab.x = sw * 0.5 - 280 + (i - 1) * 190
		tab.y = 91
		Button.update(tab, love.mouse.getX(), love.mouse.getY(), dt)
	end
	backButton.x, backButton.y = sw * 0.5 - backButton.w * 0.5, sh - 55
	Button.update(backButton, love.mouse.getX(), love.mouse.getY(), dt)

	maxScroll = math.max(0, entryCount() * activeRowHeight() - viewport.h)
	scroll = math.max(0, math.min(maxScroll, scroll))
end

local function panel(x, y, w, h, color)
	lg.setColor(Theme.outline.color)
	lg.rectangle("fill", x - 3, y - 3, w + 6, h + 6, 9)
	lg.setColor(color or Theme.ui.panel)
	lg.rectangle("fill", x, y, w, h, 7)
end

local function drawAchievement(def, x, y, w)
	local meta = Save.data.meta
	local unlocked = meta.unlockedAchievements[def.id] == true
	panel(x, y, w, rowHeight - 10, unlocked and Theme.ui.panel or Theme.ui.panel2)
	Fonts.set("ui")
	lg.setColor(unlocked and Theme.ui.good or Theme.ui.text)
	Text.printShadow(L(def.nameKey), x + 16, y + 10)
	lg.setColor(unlocked and Theme.ui.good or Theme.ui.warn)
	Text.printfShadow(L(unlocked and "progress.unlocked" or "progress.locked"), x + w - 145, y + 10, 128, "right")
	Fonts.set("tooltip")
	lg.setColor(Theme.ui.text)
	Text.printShadow(L(def.descKey), x + 16, y + 37)

	if def.stat and def.target then
		local value = math.min(tonumber(meta[def.stat]) or 0, def.target)
		Text.printfShadow(L("progress.progressValue", value, def.target), x + w - 160, y + 37, 143, "right")
	end
end

local function mechanicLines(def)
	local traits = EnemyTraits.forEnemy(def)
	if #traits == 0 then return L("progress.basicIntel") end
	local lines = {}
	for _, trait in ipairs(traits) do
		lines[#lines + 1] = L("progress.mechanic", trait.tag, trait.mechanic)
		lines[#lines + 1] = L("progress.tell", trait.tell)
		lines[#lines + 1] = L("progress.defeats", trait.counter, table.concat(trait.answers, "; "))
	end
	return table.concat(lines, "\n")
end

local function drawIntel(entry, x, y, w)
	panel(x, y, w, intelRowHeight - 10, Theme.ui.panel)
	Fonts.set("ui")
	lg.setColor(Theme.ui.text)
	Text.printShadow(L(entry.def.nameKey), x + 16, y + 10)
	local history = (Save.data.meta.enemyHistory or {})[entry.kind] or {}
	local stat = history.fastestKill
		and L("progress.historyFull", history.kills or 0, history.leaks or 0, history.fastestKill)
		or L("progress.history", history.kills or 0, history.leaks or 0)
	Text.printfShadow(stat, x + w - 330, y + 10, 314, "right")
	Fonts.set("tooltip")
	lg.setColor(Theme.ui.text[1] * 0.82, Theme.ui.text[2] * 0.82, Theme.ui.text[3] * 0.82)
	Text.printfShadow(mechanicLines(entry.def), x + 16, y + 36, w - 32, "left")
end

local function drawTower(kind, x, y, w)
	panel(x, y, w, towerRowHeight - 10, Theme.ui.panel)
	TowerCodex.drawEntry(kind, TowerDefs[kind], x + 16, y + 12, w - 32)
end

function Screen.draw()
	local sw, sh = lg.getDimensions()
	Backdrop.draw()
	panel(viewport.x - 24, 65, viewport.w + 48, sh - 130, Theme.ui.backdrop)
	Fonts.set("title")
	lg.setColor(Theme.ui.text)
	Text.printfShadow(L("progress.title"), 0, 22, sw, "center")
	Fonts.set("ui")
	for _, tab in ipairs(tabs) do
		Button.draw(tab)
		if tab.id == activeTab then
			lg.setColor(Theme.ui.selected)
			lg.rectangle("fill", tab.x + 8, tab.y + tab.h + 1, tab.w - 16, 3, 2)
		end
	end

	lg.setScissor(viewport.x, viewport.y, viewport.w, viewport.h)
	if activeTab == "achievements" then
		for i, def in ipairs(AchievementDefs) do drawAchievement(def, viewport.x + 3, viewport.y + (i - 1) * rowHeight - scroll + 3, viewport.w - 10) end
	elseif activeTab == "intel" then
		local entries = intelEntries()
		if #entries == 0 then
			Fonts.set("ui")
			lg.setColor(Theme.ui.text)
			Text.printfShadow(L("progress.noIntel"), viewport.x + 40, viewport.y + 35, viewport.w - 80, "center")
		end
		for i, entry in ipairs(entries) do drawIntel(entry, viewport.x + 3, viewport.y + (i - 1) * intelRowHeight - scroll + 3, viewport.w - 10) end
	else
		for i, kind in ipairs(Constants.TOWER_LIST) do drawTower(kind, viewport.x + 3, viewport.y + (i - 1) * towerRowHeight - scroll + 3, viewport.w - 10) end
	end
	lg.setScissor()
	Fonts.set("tooltip")
	lg.setColor(Theme.ui.text)
	Text.printfShadow(L("progress.scrollHint"), 0, sh - 82, sw, "center")
	Fonts.set("ui")
	Button.draw(backButton)
end

function Screen.wheelmoved(_, y)
	scroll = scroll - y * activeRowHeight() * 0.7
end

function Screen.keypressed(key)
	if key == "escape" then goBack()
	elseif key == "up" then scroll = scroll - activeRowHeight()
	elseif key == "down" then scroll = scroll + activeRowHeight()
	elseif key == "left" or key == "right" then
		local order, index = {"achievements", "intel", "towers"}, 1
		for i, id in ipairs(order) do if id == activeTab then index = i end end
		index = ((index - 1 + (key == "right" and 1 or -1)) % #order) + 1
		selectTab(order[index])
	end
end

function Screen.mousepressed(x, y, button)
	for _, tab in ipairs(tabs) do if Button.mousepressed(tab, x, y, button) then return true end end
	return Button.mousepressed(backButton, x, y, button)
end

function Screen.mousereleased(x, y, button)
	for _, tab in ipairs(tabs) do if Button.mousereleased(tab, x, y, button) then return true end end
	return Button.mousereleased(backButton, x, y, button)
end

return Screen
