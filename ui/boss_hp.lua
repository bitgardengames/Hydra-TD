local Theme = require("core.theme")
local State = require("core.state")
local Text = require("ui.text")
local Enemies = require("world.enemies")

local lg = love.graphics
local floor = math.floor
local ceil = math.ceil
local max = math.max
local format = string.format

local colorText = Theme.ui.text
local colorHealth = Theme.ui.bossHealth
local colorOutline = Theme.outline.color
local colorBase = Theme.ui.button

local colorHealthR, colorHealthG, colorHealthB = colorHealth[1] * 0.4, colorHealth[2] * 0.4, colorHealth[3] * 0.4

local y = 24
local barW = 354
local barH = 26

local outlineW = Theme.outline.width
local outerRadius = 6 + outlineW * 0.5
local innerRadius = 6 - outlineW * 0.25

local idleLift = 6

local hpCache = {
	hpValue = nil,
	maxText = nil,
	text = nil,
	textW = 0,
}

local BossHP = {}

local function formatNum(n)
    return tostring(floor(n + 0.5)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

function BossHP.draw()
	local boss = State.activeBoss

	if type(boss) == "string" then
		local enemies = Enemies.enemies

		for i = 1, #enemies do
			local enemy = enemies[i]

			if enemy.boss == true and enemy.kind == boss and enemy.hp and enemy.hp > 0 then
				boss = enemy
				break
			end
		end
	end

	local hp = boss and boss.hp or nil
	local maxHp = boss and boss.maxHp or nil

	if type(hp) ~= "number" or type(maxHp) ~= "number" or maxHp <= 0 or hp <= 0 then
		hpCache.hpValue = nil
		hpCache.maxText = nil
		hpCache.text = nil

		return
	end

	if hpCache.maxText == nil then
		hpCache.maxText = formatNum(maxHp)
	end

	local sw, _ = lg.getDimensions()
	local x = floor((sw - barW) * 0.5)
	local lift = idleLift

	local r, g, b, a = colorBase[1], colorBase[2], colorBase[3], colorBase[4] or 1

	-- Base
	lg.setColor(colorOutline)
	lg.rectangle("fill", x - outlineW, y - outlineW, barW + outlineW * 2, barH + outlineW * 2, outerRadius)

	lg.setColor(r * 0.4, g * 0.4, b * 0.4, a)
	lg.rectangle("fill", x, y, barW, barH, innerRadius)

	-- Face
	local fy = y - lift

	lg.setColor(colorOutline)
	lg.rectangle("fill", x - outlineW, fy - outlineW, barW + outlineW * 2, barH + outlineW * 2, outerRadius)

	lg.setColor(colorHealthR, colorHealthG, colorHealthB, 1)
	lg.rectangle("fill", x, fy, barW, barH, innerRadius)

	-- Fill
	local hpFrac = max(0, hp / maxHp)
	local fillW = floor(barW * hpFrac)

	lg.setColor(colorHealth)
	lg.rectangle("fill", x, fy, fillW, barH, innerRadius)

	-- Text
	local hpInt = ceil(hp)

	if hpCache.hpValue ~= hpInt then
		hpCache.hpValue = hpInt

		local hpText = format("%s / %s", formatNum(hpInt), hpCache.maxText)

		hpCache.text = hpText
		hpCache.textW = lg.getFont():getWidth(hpText)
	end

	local textH = lg.getFont():getHeight()

	lg.setColor(colorText)
	Text.printShadow(hpCache.text, x + (barW - hpCache.textW) * 0.5, fy + (barH - textH) * 0.5)
end

return BossHP
