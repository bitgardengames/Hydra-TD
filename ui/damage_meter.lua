local Theme = require("core.theme")
local State = require("core.state")
local Text = require("ui.text")
local Towers = require("world.towers")
local L = require("core.localization")

local lg = love.graphics
local abs = math.abs
local floor = math.floor
local format = string.format
local tostring = tostring
local tsort = table.sort

local colorText = Theme.ui.text
local colorPanel = Theme.ui.panel2
local colorBackdrop = Theme.ui.backdrop
local colorOutline = Theme.outline.color

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

local speed = 0.2

local meterCache = {
	list = {},
	index = {},
	isBoss = false,
	headerText = nil
}

local nameCache = {}

local DamageMeter = {}

local function formatNum(n)
	return tostring(floor(n + 0.5)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

local function sorter(a, b)
	return a.dmg > b.dmg
end

function DamageMeter.draw()
	if not State.combatStats or not State.combatStats.showDamageMeter then
		return
	end

	local stats = State.combatStats
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
		meterCache.headerText = nil

		for i = #list, 1, -1 do
			list[i] = nil
		end

		for k in pairs(index) do
			index[k] = nil
		end
	end

	-- ensure entries exist (cheap)
	for kind, dmg in pairs(dmgTable) do
		if dmg > 0 and not index[kind] then
			local entry = {kind = kind, dmg = dmg, displayPct = 0}

			list[#list + 1] = entry
			index[kind] = entry
		end
	end

	if #list == 0 then
		return
	end

	-- update damage values
	for _, entry in ipairs(list) do
		entry.dmg = dmgTable[entry.kind] or 0
	end

	tsort(list, sorter)

	-- layout
	local sw = lg.getWidth()

	local panelX = sw - panelW - panelPad * 2 - screenPad
	local panelY = screenPad

	local barsH = (#list * barH) + ((#list - 1) * rowGap)
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

	lg.setColor(colorPanel)
	lg.rectangle("fill", headerX, headerY, panelW, headerH, innerSmallRadius)

	lg.setColor(colorText)

	if not meterCache.headerText then
		meterCache.headerText = isBossView and L("damage.boss") or L("damage.normal")
	end

	local textH = lg.getFont():getHeight()
	local headerTextY = headerY + floor((headerH - textH) * 0.5 + 0.5)

	Text.printShadow(meterCache.headerText, headerX + padX, headerTextY)

	local x = panelX + panelPad
	local y = headerY + headerH + headerGap

	for _, entry in ipairs(list) do
		local def = Towers.TowerDefs[entry.kind]

		if def then
			local name = nameCache[entry.kind]

			if not name then
				name = L(def.nameKey)
				nameCache[entry.kind] = name
			end

			local pct = (total > 0) and (entry.dmg / total) or 0

			entry.displayPct = entry.displayPct + (pct - entry.displayPct) * speed

			if abs(pct - entry.displayPct) < 0.001 then
				entry.displayPct = pct
			end

			local text = format("%s %s (%.0f%%)", name, formatNum(entry.dmg), pct * 100)

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
	meterCache.headerText = nil
end

return DamageMeter