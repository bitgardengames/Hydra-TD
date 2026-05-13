local Constants = require("core.constants")
local Theme = require("core.theme")

local Hud = require("ui.bottom_bar_hud")
local Shop = require("ui.bottom_bar_shop")
local Inspect = require("ui.bottom_bar_inspect")

local lg = love.graphics
local getTime = love.timer.getTime
local getDelta = love.timer.getDelta
local floor = math.floor

local colorPanel2 = Theme.ui.panel2
local colorBackdrop = Theme.ui.backdrop
local colorOutline = Theme.outline.color

local BottomBar = {}

-- Layout
local PAD = 12
local UI_H = Constants.UI_H
local SHOP_W = ((120 * 3) + (PAD * 2) + (PAD * (3 - 1)))
local INSPECT_W = 260
local HUD_H = 28

local PANEL_LIFT = 16
local PANEL_INSET = 16

local OUTER_PAD = 12
local PANEL_GAP = 16

local outerW = OUTER_PAD * 2 + SHOP_W
local outerH = UI_H
local outerX = PANEL_INSET

local outlineW = Theme.outline.width
local baseRadius = 6 * 3
local outerRadius = baseRadius + outlineW * 0.5
local innerRadius = baseRadius - outlineW * 0.25
local outerSmallRadius = 6 + outlineW * 0.5
local innerSmallRadius = 6 - outlineW * 0.25

function BottomBar.draw()
	local font = lg.getFont()
	local textH = font:getHeight()
	local _, sh = lg.getDimensions()

	local dt = getDelta()
	local now = getTime()
	local mx, my = love.mouse.getPosition()

	local outerY = sh - outerH - PANEL_LIFT

	-- Outer backdrop
	lg.setColor(colorOutline)
	lg.rectangle("fill", outerX - outlineW, outerY - outlineW, outerW + outlineW * 2, outerH + outlineW * 2, outerRadius)

	lg.setColor(colorBackdrop)
	lg.rectangle("fill", outerX, outerY, outerW, outerH, innerRadius)

	-- HUD panel
	local infoX = outerX + OUTER_PAD
	local infoY = outerY + OUTER_PAD
	local infoW = outerW - OUTER_PAD * 2
	local infoH = HUD_H

	lg.setColor(colorOutline)
	lg.rectangle("fill", infoX - outlineW, infoY - outlineW, infoW + outlineW * 2, infoH + outlineW * 2, outerSmallRadius)

	lg.setColor(colorPanel2) -- colorPanel2, colorBackdrop
	lg.rectangle("fill", infoX, infoY, infoW, infoH, innerSmallRadius)

	Hud.draw(infoX, infoY, infoW, infoH, dt)

	-- Shop panel
	local shopPanelX = outerX + OUTER_PAD
	local shopPanelY = infoY + infoH + PANEL_GAP
	local shopPanelW = SHOP_W
	local shopPanelH = outerH - (shopPanelY - outerY) - OUTER_PAD

	Shop.draw(shopPanelX + PAD, shopPanelY + PAD, shopPanelW - PAD * 2, shopPanelH - PAD * 2, dt, now, mx, my)

	-- Inspect
	local inspectW = INSPECT_W + PAD * 2

	Inspect.draw(outerX + outerW + PANEL_GAP, outerY, inspectW, outerH, dt, textH, now, mx, my)
end

function BottomBar.getShopButtons()
	return Shop.getButtons()
end

function BottomBar.getInspectButtons()
	return Inspect.getButtons()
end

return BottomBar
