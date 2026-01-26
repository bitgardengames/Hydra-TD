local Theme = require("core.theme")
local State = require("core.state")
local Text = require("ui.text")

local lg = love.graphics
local floor = math.floor
local ceil = math.ceil
local max = math.max
local format = string.format

local colorText = Theme.ui.text

local BossHP = {}

local function formatNum(n)
    return tostring(floor(n + 0.5)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

function BossHP.draw()
    local boss = State.activeBoss

    if not boss or boss.hp <= 0 then
        return
    end

    -- Layout
    local barW = 340
    local barH = 22

	local sw = lg.getDimensions()
    local x = (sw - barW) * 0.5
    local y = 14

    local pad = 4
    local radius = 8

    local hpFrac = max(0, boss.hp / boss.maxHp)

    -- Background frame
    lg.setColor(0, 0, 0, 0.75)
    lg.rectangle("fill", x - pad, y - pad, barW + pad * 2, barH + pad * 2, radius, radius)

    -- HP fill
    lg.setColor(0.75, 0.15, 0.15, 0.9)
    lg.rectangle("fill", x, y, barW * hpFrac, barH, radius - 4, radius - 4)

    -- Text
	local hpText = format("%s / %s", formatNum(ceil(boss.hp)), formatNum(boss.maxHp))

    local font = lg.getFont()
    local textW = font:getWidth(hpText)
    local textH = font:getHeight()

    lg.setColor(colorText)
    Text.printShadow(hpText, x + (barW - textW) * 0.5, y + (barH - textH) * 0.5)
end

return BossHP