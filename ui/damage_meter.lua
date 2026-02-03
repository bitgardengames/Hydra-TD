local Theme = require("core.theme")
local State = require("core.state")
local Text = require("ui.text")
local Towers = require("world.towers")
local L = require("core.localization")

local lg = love.graphics
local floor = math.floor
local format = string.format
local tostring = tostring
local tinsert = table.insert
local tsort = table.sort

local colorText = Theme.ui.text
local colorPanel = Theme.ui.panel

local meterCache = {
	list = {},
	dirty = true,
	total = 0,
	isBoss = false,
	headerText = nil,
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
    if not State.stats or not State.stats.showDamageMeter then
        return
    end

    local stats = State.stats
    local isBossView = (stats.damageView == 1)

    local dmgTable = isBossView and stats.bossDamageByTower or stats.damageByTower
    local total = isBossView and stats.bossTotalDamage  or stats.totalDamage

    if not dmgTable then
        return
    end

	-- Sort list
	if meterCache.dirty or meterCache.total ~= total or meterCache.isBoss ~= isBossView then
		meterCache.total = total
		meterCache.isBoss = isBossView
		meterCache.dirty = false
		meterCache.headerText = nil

		-- Rebuild list
		local list = meterCache.list

		for i = #list, 1, -1 do
			list[i] = nil
		end

		for kind, dmg in pairs(dmgTable) do
			if dmg > 0 then
				list[#list + 1] = {kind = kind, dmg = dmg, text = nil}
			end
		end

		tsort(list, sorter)
	end

	local list = meterCache.list

	if #list == 0 then
		return
	end

	-- Layout
    local panelW = 200
    local barH = 18
    local lineH = 21
    local padX = 8
	local panelPad = 8
	local screenPad = 12

	local sw, _ = lg.getDimensions()

	local panelX = sw - panelW - panelPad * 2 - screenPad
	local panelY = screenPad

	local x = panelX + panelPad
	local y = panelY + panelPad

    local panelH = 32 + (#list * lineH)

    -- Bar width is constrained by panel width
    local maxBarW = panelW

	-- Panel background
    lg.setColor(colorPanel)
	lg.rectangle("fill", panelX, panelY, panelW + panelPad * 2, panelH, 8, 8)

    -- Header
	lg.setColor(colorText)

	if not meterCache.headerText then
		meterCache.headerText = isBossView and L("damage.boss") or L("damage.normal")
	end

	Text.printShadow(meterCache.headerText, x + 2, y - 2)

    y = y + 20

    -- Bars
    local font = lg.getFont()
    local textH = font:getHeight()

    for _, entry in ipairs(list) do
        local def = Towers.TowerDefs[entry.kind]

        if def then
			local name = nameCache[entry.kind]

			if not name then
				name = L(def.nameKey)
				nameCache[entry.kind] = name
			end

            local pct = (total > 0) and (entry.dmg / total) or 0

			if not entry.text then
				entry.text = format("%s %s (%.0f%%)", name, formatNum(entry.dmg), pct * 100)
			end

            -- Bar background (full width inside panel)
            lg.setColor(def.color[1], def.color[2], def.color[3], 0.25)
            lg.rectangle("fill", x, y, maxBarW, barH, 6, 6)

            -- Filled portion
            lg.setColor(def.color[1], def.color[2], def.color[3], 0.6)
            lg.rectangle("fill", x, y, maxBarW * pct, barH, 6, 6)

            -- Text centered inside bar
            lg.setColor(1, 1, 1, 0.95)
            Text.printShadow(entry.text, x + padX, y + (barH - textH) * 0.5)

            y = y + lineH
        end
    end

    -- Empty boss damage
    if isBossView and total <= 0 then
        lg.setColor(1, 1, 1, 0.6)
        Text.printShadow(L("damage.noneBoss"), x, y + 4)
    end
end

return DamageMeter