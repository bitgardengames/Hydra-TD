-- ui/menu/screens/campaign.lua
local Constants = require("core.constants")
local Sound = require("systems.sound")
local Fonts = require("core.fonts")
local Theme = require("core.theme")
local State = require("core.state")
local Save = require("core.save")
local Maps = require("world.map_defs")
local Text = require("ui.text")
local Cursor = require("core.cursor")
local Button = require("ui.button")
local L = require("core.localization")

local lg = love.graphics
local sin = math.sin
local min = math.min
local max = math.max
local floor = math.floor

local Screen = {}

local colorText = Theme.ui.text
local colorPath = Theme.terrain.path
local colorGrass = Theme.terrain.grass
local colorPanel = Theme.ui.panel
local colorMenu = Theme.menu

local PAD_PREVIEW = 28
local PAD_TITLE   = 54
local PAD_META    = 18
local PAD_ACTION  = 26

local CAROUSEL_OFFSET      = 90
local CAROUSEL_SCALE_SIDE = 0.82
local CAROUSEL_ALPHA_SIDE = 0.35

local mapPreviews = {}
local carouselCards = {}
local campaignButtons = {}

local function ease(p)
	return p * p * (3 - 2 * p)
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function isMapLocked(i)
	return not Save.isMapUnlocked(i, Maps[i].id)
end

-- Map preview generation
local function buildMapPreview(mapDef)
	local w, h = 520, 312
	local canvas = lg.newCanvas(w, h)

	lg.setCanvas(canvas)
	lg.clear(0, 0, 0, 0)

	local tileW = w / Constants.GRID_W
	local tileH = h / Constants.GRID_H

	lg.setColor(colorGrass)
	lg.rectangle("fill", 0, 0, w, h)

	lg.setColor(colorPath)
	lg.setLineWidth(4)

	for i = 1, #mapDef.path - 1 do
		local ax, ay = mapDef.path[i][1], mapDef.path[i][2]
		local bx, by = mapDef.path[i + 1][1], mapDef.path[i + 1][2]

		lg.line((ax - 0.5) * tileW, (ay - 0.5) * tileH, (bx - 0.5) * tileW, (by - 0.5) * tileH)
	end

	lg.setLineWidth(1)
	lg.setCanvas()

	return canvas
end

local function addCard(cards, i, from, to, mapCount)
	if i < 1 or i > mapCount then return end
	cards[#cards + 1] = { i = i, from = from, to = to }
end

function Screen.load()
	-- Build previews once
	if #mapPreviews == 0 then
		for i, map in ipairs(Maps) do
			mapPreviews[i] = buildMapPreview(map)
		end
	end

	campaignButtons = {
		{
			id = "play",
			label = L("menu.play"),
			w = 220,
			h = 42,
			onClick = function()
				if isMapLocked(State.mapIndex) then
					Sound.play("uiError")
					return
				end

				Sound.play("uiConfirm")
				State.mode = "game"
				resetGame()
			end
		},
		{
			id = "back",
			label = L("menu.back"),
			w = 220,
			h = 42,
			onClick = function()
				State.mode = "menu"
				Sound.play("uiBack")
			end
		}
	}
end

function Screen.update(dt)
	local sw, sh = lg.getDimensions()
	local cx = floor(sw * 0.5)
	local startY = floor(sh * 0.38 + 260)
	local gap = 52

	for i, btn in ipairs(campaignButtons) do
		btn.x = cx - btn.w * 0.5
		btn.y = startY + (i - 1) * gap
		btn.enabled = (btn.id ~= "play") or not isMapLocked(State.mapIndex)

		Button.update(btn, Cursor.x, Cursor.y, dt)
	end
end

function Screen.draw()
	local sw, sh = lg.getDimensions()

	lg.setColor(colorMenu)
	lg.rectangle("fill", 0, 0, sw, sh)

	local index = State.mapIndex
	local map = Maps[index]
	local mapCount = #Maps

	local dir = State.carouselDir or 0
	local p = ease(State.carouselT or 1)

	local preview = mapPreviews[index]
	local pw, ph = preview:getWidth(), preview:getHeight()

	local centerX = floor(sw * 0.5)
	local blockH = ph + PAD_PREVIEW + PAD_TITLE + PAD_META + PAD_ACTION
	local pyTop = floor(sh * 0.38 - blockH * 0.5)
	local centerY = pyTop + ph * 0.5

	local slots = {
		prev = { x = centerX - CAROUSEL_OFFSET, y = centerY, scale = CAROUSEL_SCALE_SIDE, alpha = CAROUSEL_ALPHA_SIDE },
		curr = { x = centerX, y = centerY, scale = 1.0, alpha = 1.0 },
		next = { x = centerX + CAROUSEL_OFFSET, y = centerY, scale = CAROUSEL_SCALE_SIDE, alpha = CAROUSEL_ALPHA_SIDE },
	}

	for i = #carouselCards, 1, -1 do carouselCards[i] = nil end

	if dir == 0 then
		addCard(carouselCards, index - 1, slots.prev, slots.prev, mapCount)
		addCard(carouselCards, index,     slots.curr, slots.curr, mapCount)
		addCard(carouselCards, index + 1, slots.next, slots.next, mapCount)
	end

	local resolved = {}

	for _, c in ipairs(carouselCards) do
		local from, to = c.from, c.to

		resolved[#resolved + 1] = {
			i = c.i,
			x = lerp(from.x, to.x, p),
			y = lerp(from.y, to.y, p),
			s = lerp(from.scale, to.scale, p),
			a = lerp(from.alpha, to.alpha, p),
		}
	end

	table.sort(resolved, function(a, b) return a.s < b.s end)

	for _, r in ipairs(resolved) do
		local pv = mapPreviews[r.i]
		local locked = isMapLocked(r.i)
		local alpha = locked and (r.a * 0.35) or r.a

		lg.setColor(1, 1, 1, alpha)
		lg.push()
		lg.translate(r.x, r.y)
		lg.scale(r.s, r.s)
		lg.draw(pv, -pw * 0.5, -ph * 0.5)
		lg.pop()
	end

	lg.setColor(colorPanel)
	lg.rectangle("line", centerX - pw * 0.5, centerY - ph * 0.5, pw, ph, 6, 6)

	if isMapLocked(index) then
		lg.setColor(0, 0, 0, 0.45)
		lg.rectangle("fill", centerX - pw * 0.5, centerY - ph * 0.5, pw, ph, 12, 12)

		lg.setColor(colorText)

		Fonts.set("title")
		Text.printfShadow(L("campaign.locked"), centerX - pw * 0.5, centerY - 14, pw, "center")
	end

	local textY = pyTop + ph + PAD_PREVIEW

	lg.setColor(colorText)

	Fonts.set("title")
	Text.printfShadow(L(map.nameKey), 0, textY, sw, "center")

	lg.setColor(colorText)

	Fonts.set("ui")
	Text.printfShadow(L("campaign.mapOf", index, mapCount), 0, textY + PAD_TITLE, sw, "center")

	Fonts.set("menu")
	for _, btn in ipairs(campaignButtons) do
		Button.draw(btn)
	end
end

-- ================================
-- Input
-- ================================
function Screen.keypressed(key)
	if key == "left" then
		if State.mapIndex > 1 then
			State.mapIndex = State.mapIndex - 1
			State.carouselDir = -1
			State.carouselT = 0
			Sound.play("uiMove")
		else
			Sound.play("uiError")
		end
	elseif key == "right" then
		if State.mapIndex < #Maps and not isMapLocked(State.mapIndex + 1) then
			State.mapIndex = State.mapIndex + 1
			State.carouselDir = 1
			State.carouselT = 0
			Sound.play("uiMove")
		else
			Sound.play("uiError")
		end
	elseif key == "escape" then
		State.mode = "menu"
		Sound.play("uiBack")
	end
end

function Screen.mousepressed(x, y, button)
	for _, btn in ipairs(campaignButtons) do
		if Button.mousepressed(btn, x, y, button) then
			return true
		end
	end
end

return Screen