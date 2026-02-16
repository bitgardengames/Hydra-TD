local Constants = require("core.constants")
local Cursor = require("core.cursor")
local Theme = require("core.theme")

local Hud = require("ui.bottom_bar_hud")
local Shop = require("ui.bottom_bar_shop")
local Inspect = require("ui.bottom_bar_inspect")

local lg = love.graphics
local getTime = love.timer.getTime
local getDelta = love.timer.getDelta
local floor = math.floor

local colorPanel  = Theme.ui.panel
local colorPanel2 = Theme.ui.panel2

local BottomBar = {}

-- Layout
local PAD = 8
local UI_H = Constants.UI_H
local SHOP_W = ((124 * 3) + (PAD * 2) + (PAD * (3 - 1)))
local INSPECT_W = 260
local HUD_H = 28

local PANEL_LIFT  = 12
local PANEL_INSET = 12

function BottomBar.draw()
	local font = lg.getFont()
	local textH = font:getHeight()
	local sw, sh = lg.getDimensions()

	local dt = getDelta()
	local now = getTime()
	local mx, my = Cursor.x, Cursor.y

	local OUTER_PAD = 10
	local PANEL_GAP = 10
	local OUTER_R = 12
	local INNER_R = 8

	local outerW = OUTER_PAD * 2 + SHOP_W
	local outerH = UI_H
	local outerX = PANEL_INSET
	local outerY = sh - outerH - PANEL_LIFT

	-- Outer backdrop
	lg.setColor(colorPanel)
	lg.rectangle("fill", outerX, outerY, outerW, outerH, OUTER_R, OUTER_R)

	-- HUD panel
	local infoX = outerX + OUTER_PAD
	local infoY = outerY + OUTER_PAD
	local infoW = outerW - OUTER_PAD * 2
	local infoH = HUD_H

	lg.setColor(colorPanel2)
	lg.rectangle("fill", infoX, infoY, infoW, infoH, INNER_R, INNER_R)
	
	Hud.draw(infoX, infoY, infoW, infoH, dt)

	-- Shop panel
	local shopPanelX = outerX + OUTER_PAD
	local shopPanelY = infoY + infoH + PANEL_GAP
	local shopPanelW = SHOP_W
	local shopPanelH = outerH - (shopPanelY - outerY) - OUTER_PAD

	lg.setColor(colorPanel2)
	lg.rectangle("fill", shopPanelX, shopPanelY, shopPanelW, shopPanelH, INNER_R, INNER_R)

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