local Theme = require("core.theme")
local State = require("core.state")
local Text = require("ui.text")
local Towers = require("world.towers")
local L = require("core.localization")
local Sound = require("systems.sound")

local lg = love.graphics
local abs = math.abs
local exp = math.exp
local floor = math.floor
local format = string.format
local tostring = tostring
local tsort = table.sort

local colorText = Theme.ui.text
local colorBackdrop = Theme.ui.backdrop
local colorOutline = Theme.outline.color
local tabTheme = Theme.ui.damageMeterTab

local outlineW = Theme.outline.width
local baseRadius = 6 * 3
local outerRadius = baseRadius + outlineW * 0.5
local innerRadius = baseRadius - outlineW * 0.25

local outerSmallRadius = 6 + outlineW * 0.5
local innerSmallRadius = 6 - outlineW * 0.25

local panelW = 210
local barH = 22
local rowGap = 6
local lineH = barH + rowGap
local padX = 8
local panelPad = 12
local screenPad = 16
local headerH = 30
local headerGap = 10

local RESPONSE = -60 * math.log(0.8)

local meterCache = {
	list = {},
	index = {},
	isBoss = false
}

local nameCache = {}
local localizationRevision = L.getRevision()

local DamageMeter = {}
local pressedView = nil

local function getHeaderLayout()
	local panelX = lg.getWidth() - panelW - panelPad * 2 - screenPad
	return panelX + panelPad, screenPad + panelPad
end

local function viewAt(x, y)
	local stats = State.combatStats
	if not stats or not stats.showDamageMeter or not stats.damageByTower then return nil end

	local headerX, headerY = getHeaderLayout()
	if x < headerX or x > headerX + panelW or y < headerY or y > headerY + headerH then
		return nil
	end

	return x < headerX + panelW * 0.5 and 0 or 1
end


function DamageMeter.mousepressed(x, y, button)
	if button ~= 1 then return false end
	pressedView = viewAt(x, y)
	if pressedView ~= nil then
		Sound.play("uiMove")
		return true
	end
	return false
end

function DamageMeter.mousereleased(x, y, button)
	if button ~= 1 then return false end
	local releasedView = viewAt(x, y)
	local activated = pressedView ~= nil and releasedView == pressedView
	pressedView = nil
	if activated then
		State.combatStats.damageView = releasedView
		Sound.play("uiConfirm")
		return true
	end
	return false
end

local function formatNum(n)
	return tostring(floor(n + 0.5)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

local function sorter(a, b)
	if a.dmg == b.dmg then
		return a.kind < b.kind
	end
	return a.dmg > b.dmg
end

local function getTowerName(kind)
	local name = nameCache[kind]
	if name == nil then
		local def = Towers.TowerDefs[kind]
		name = def and L(def.nameKey) or ""
		nameCache[kind] = name
	end
	return name
end

local function buildEntryText(entry, pctBucket)
	entry.text = format("%s %s (%d%%)", entry.name, formatNum(entry.dmg), pctBucket)
	entry.lastTextDmg = entry.dmg
	entry.lastTextPctBucket = pctBucket
end

function DamageMeter.localizationChanged()
	for kind in pairs(nameCache) do
		nameCache[kind] = nil
	end

	for _, entry in ipairs(meterCache.list) do
		entry.name = getTowerName(entry.kind)
		entry.lastTextDmg = nil
		entry.lastTextPctBucket = nil
	end

	localizationRevision = L.getRevision()
end

function DamageMeter.update(dt)
	if not State.combatStats or not State.combatStats.showDamageMeter then
		return
	end

	local stats = State.combatStats
	if localizationRevision ~= L.getRevision() then
		DamageMeter.localizationChanged()
	end
	local isBossView = (stats.damageView == 1)

	local dmgTable = isBossView and stats.bossDamageByTower or stats.damageByTower
	local total = isBossView and stats.bossTotalDamage or stats.totalDamage

	if not dmgTable then
		return
	end

	local list = meterCache.list
	local index = meterCache.index

	-- rebuild only when switching views
	if meterCache.isBoss ~= isBossView then
		meterCache.isBoss = isBossView

		for i = #list, 1, -1 do
			list[i] = nil
		end

		for k in pairs(index) do
			index[k] = nil
		end
	end

	-- New entries also need to be sorted. Previously, sorting only happened after
	-- an existing entry changed, so the initial meter reflected pairs() order.
	local needsSort = false

	-- ensure entries exist (cheap)
	for kind, dmg in pairs(dmgTable) do
		if dmg > 0 and not index[kind] then
			local entry = {
				kind = kind,
				dmg = dmg,
				displayPct = 0,
				name = getTowerName(kind)
			}

			list[#list + 1] = entry
			index[kind] = entry
			needsSort = true
		end
	end


	-- update damage values and detect whether ordering can change
	for _, entry in ipairs(list) do
		local newDmg = dmgTable[entry.kind] or 0

		if newDmg ~= entry.dmg then
			entry.dmg = newDmg
			needsSort = true
		end
	end

	if needsSort then
		tsort(list, sorter)
	end

	local factor = 1 - exp(-RESPONSE * dt)
	for _, entry in ipairs(list) do
		local pct = (total > 0) and (entry.dmg / total) or 0
		entry.displayPct = entry.displayPct + (pct - entry.displayPct) * factor
		if abs(pct - entry.displayPct) < 0.001 then entry.displayPct = pct end
		local pctBucket = floor(pct * 100 + 0.5)
		if entry.lastTextDmg ~= entry.dmg or entry.lastTextPctBucket ~= pctBucket then
			buildEntryText(entry, pctBucket)
		end
	end
end

function DamageMeter.draw()
	if not State.combatStats or not State.combatStats.showDamageMeter then return end
	local stats = State.combatStats
	local isBossView = stats.damageView == 1
	local total = isBossView and stats.bossTotalDamage or stats.totalDamage
	local list = meterCache.list
	if #list == 0 and not isBossView then return end

	-- layout
	local sw = lg.getWidth()

	local panelX = sw - panelW - panelPad * 2 - screenPad
	local panelY = screenPad

	local barsH = #list > 0 and ((#list * barH) + ((#list - 1) * rowGap)) or barH
	local panelH = panelPad * 2 + headerH + headerGap + barsH

	local maxBarW = panelW
	local panelWFull = panelW + panelPad * 2

	lg.setColor(colorOutline)
	lg.rectangle("fill", panelX - outlineW, panelY - outlineW, panelWFull + outlineW * 2, panelH + outlineW * 2, outerRadius)

	lg.setColor(colorBackdrop)
	lg.rectangle("fill", panelX, panelY, panelWFull, panelH, innerRadius)

	local headerX = panelX + panelPad
	local headerY = panelY + panelPad

	lg.setColor(colorOutline)
	lg.rectangle("fill", headerX - outlineW, headerY - outlineW, panelW + outlineW * 2, headerH + outlineW * 2, outerSmallRadius)

	local textH = lg.getFont():getHeight()
	local headerTextY = headerY + floor((headerH - textH) * 0.5 + 0.5)
	local tabCount = 2
	local tabW = panelW / tabCount
	local mx, my = love.mouse.getPosition()
	for view = 0, tabCount - 1 do
		local tabX = headerX + view * tabW
		local hovered = mx >= tabX and mx <= tabX + tabW and my >= headerY and my <= headerY + headerH
		local selected = stats.damageView == view
		lg.setColor(selected and tabTheme.selected or (hovered and tabTheme.hovered or tabTheme.idle))
		lg.rectangle("fill", tabX, headerY, tabW, headerH, innerSmallRadius)
		lg.setColor(selected and tabTheme.selectedText or colorText)
		Text.printfShadow(view == 0 and L("damage.normal") or L("damage.boss"), tabX, headerTextY, tabW, "center")
	end

	local x = panelX + panelPad
	local y = headerY + headerH + headerGap

	for _, entry in ipairs(list) do
		local def = Towers.TowerDefs[entry.kind]

		if def then
			local text = entry.text or ""

			lg.setColor(def.color[1], def.color[2], def.color[3], 0.25)
			lg.rectangle("fill", x, y, maxBarW, barH, innerSmallRadius)

			lg.setColor(def.color[1], def.color[2], def.color[3], 0.6)
			lg.rectangle("fill", x, y, maxBarW * entry.displayPct, barH, innerSmallRadius)

			lg.setColor(1, 1, 1, 0.95)
			Text.printShadow(text, x + padX, y + (barH - textH) * 0.5)

			y = y + lineH
		end
	end

	if isBossView and total <= 0 then
		lg.setColor(1, 1, 1, 0.6)
		Text.printShadow(L("damage.noneBoss"), x, y + 4)
	end
end

function DamageMeter.reset()
	local list = meterCache.list
	local index = meterCache.index

	for i = #list, 1, -1 do
		list[i] = nil
	end

	for k in pairs(index) do
		index[k] = nil
	end

	meterCache.isBoss = false
	pressedView = nil
end

return DamageMeter
