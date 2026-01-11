local Constants = require("core.constants")
local Sound = require("systems.sound")
local Fonts = require("core.fonts")
local Theme = require("core.theme")
local State = require("core.state")
local Maps = require("world.maps")

local Menu = {}

local cursor = 1
local previewAlpha = 1
local mapPreviews = {}

local colorText = Theme.ui.text
local colorPath = Theme.terrain.path
local colorGrass = Theme.terrain.grass

local lg = love.graphics
local sin = math.sin
local min = math.min
local max = math.max
local floor = math.floor

local PAD_PREVIEW = 28
local PAD_TITLE = 22
local PAD_META = 18
local PAD_ACTION = 26

local CAROUSEL_OFFSET = 90
local CAROUSEL_SCALE_SIDE = 0.82
local CAROUSEL_ALPHA_SIDE = 0.35

local menuItems = {
	"Play",
	"Settings",
	"Quit",
}

local settingsCursor = 1
local settingsItems = {
	{label = "Music Volume", key = "music"},
	{label = "SFX Volume",   key = "sfx"},
	{label = "Fullscreen",  key = "fullscreen"},
	{label = "Back"},
}

local function ease(p)
	return p * p * (3 - 2 * p)
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

-- Map Preview Generation
local function buildMapPreview(mapDef)
	-- BIG hero preview
	local w, h = 520, 312
	local canvas = lg.newCanvas(w, h)

	lg.setCanvas(canvas)
	lg.clear(0, 0, 0, 0)

	local tileW = w / Constants.GRID_W
	local tileH = h / Constants.GRID_H

	-- Background
	lg.setColor(colorGrass)
	lg.rectangle("fill", 0, 0, w, h)

	-- Path
	lg.setColor(colorPath)
	lg.setLineWidth(4)

	for i = 1, #mapDef.path - 1 do
		local ax, ay = mapDef.path[i][1], mapDef.path[i][2]
		local bx, by = mapDef.path[i + 1][1], mapDef.path[i + 1][2]

		lg.line(
			(ax - 0.5) * tileW, (ay - 0.5) * tileH,
			(bx - 0.5) * tileW, (by - 0.5) * tileH
		)
	end

	lg.setLineWidth(1)
	lg.setCanvas()

	return canvas
end

local function drawTriangle(cx, cy, dir, size, alpha)
	alpha = alpha or 1
	size = size or 10

	lg.setColor(colorText[1], colorText[2], colorText[3], alpha)

	if dir == "up" then
		lg.polygon("fill", cx, cy - size, cx - size, cy + size, cx + size, cy + size)
	elseif dir == "down" then
		lg.polygon("fill", cx, cy + size, cx - size, cy - size, cx + size, cy - size)
	end
end

local function isMapLocked(i)
	local maxUnlocked = State.maxUnlockedMap or State.mapIndex

	return i > maxUnlocked
end

function Menu.load()
	for i, map in ipairs(Maps) do
		mapPreviews[i] = buildMapPreview(map)
	end
end

-- Helpers
local function drawBlurred(canvas, x, y)
	for ox = -1, 1 do
		for oy = -1, 1 do
			if ox ~= 0 or oy ~= 0 then
				lg.setColor(1, 1, 1, 0.08)
				lg.draw(canvas, x + ox, y + oy)
			end
		end
	end
end

-- Carousel
local carouselCards = {}

local function addCard(cards, i, from, to, mapCount)
	if i < 1 or i > mapCount then
		return
	end

	cards[#cards + 1] = {i = i, from = from, to = to}
end


-- Draw
function Menu.draw()
	local sw, sh = lg.getDimensions()

	-- Main menu
	if State.mode == "menu" then
		local t = love.timer.getTime()
		local spacing = 34
		local y = floor(sh * 0.45)

		Fonts.set("title")
		lg.setColor(colorText)
		lg.printf("Hydra TD", 0, y - 72, sw, "center")

		Fonts.set("ui")

		for i, label in ipairs(menuItems) do
			local pulse = (i == cursor) and (0.85 + sin(t * 4) * 0.15) or 1
			local prefix = (i == cursor) and "> " or "  "
			lg.setColor(colorText[1], colorText[2], colorText[3], pulse)
			lg.printf(prefix .. label, 0, y, sw, "center")
			y = y + spacing
		end

	-- Campaign / map select
	elseif State.mode == "campaign" then
		----------------------------------------------------------------
		-- Setup & clamp animation intent
		----------------------------------------------------------------
		local index = State.mapIndex
		local map   = Maps[index]
		local mapCount = #Maps

		-- If we're at bounds, kill animation direction
		local dir = State.carouselDir or 0
		local p = ease(State.carouselT or 1)

		local centerPreview = mapPreviews[index]
		local pw, ph = centerPreview:getWidth(), centerPreview:getHeight()

		-- Layout
		local centerX = floor(sw * 0.5)
		local blockH  = ph + PAD_PREVIEW + PAD_TITLE + PAD_META + PAD_ACTION
		local pyTop   = floor(sh * 0.38 - blockH * 0.5)
		local centerY = pyTop + ph * 0.5

		local offset = CAROUSEL_OFFSET

		----------------------------------------------------------------
		-- Slot targets (CENTER-ANCHORED)
		----------------------------------------------------------------
		local slots = {
			prev = {
				x = centerX - offset,
				y = centerY,
				scale = CAROUSEL_SCALE_SIDE,
				alpha = CAROUSEL_ALPHA_SIDE
			},
			curr = {
				x = centerX,
				y = centerY,
				scale = 1.0,
				alpha = 1.0
			},
			next = {
				x = centerX + offset,
				y = centerY,
				scale = CAROUSEL_SCALE_SIDE,
				alpha = CAROUSEL_ALPHA_SIDE
			}
		}

		----------------------------------------------------------------
		-- Build carousel cards (reuse table, no allocations)
		----------------------------------------------------------------
		local cards = carouselCards
		for i = #cards, 1, -1 do
			cards[i] = nil
		end

		if dir == 0 then
			-- Idle / settled: always show prev, curr, next
			addCard(cards, index - 1, slots.prev, slots.prev, mapCount)
			addCard(cards, index,     slots.curr, slots.curr, mapCount)
			addCard(cards, index + 1, slots.next, slots.next, mapCount)

		elseif dir == 1 then
			-- Scrolling DOWN

			-- Old previous slides out left
			addCard(cards, index - 2, slots.prev, {
				x = slots.prev.x - offset * 0.7,
				y = centerY,
				scale = CAROUSEL_SCALE_SIDE * 0.85,
				alpha = 0
			}, mapCount)

			-- Old current -> previous
			addCard(cards, index - 1, slots.curr, slots.prev, mapCount)

			-- Old next -> current (new selection)
			addCard(cards, index, slots.next, slots.curr, mapCount)

			-- New next slides in from right
			addCard(cards, index + 1, {
				x = slots.next.x + offset * 0.7,
				y = centerY,
				scale = CAROUSEL_SCALE_SIDE * 0.85,
				alpha = 0
			}, slots.next, mapCount)

		elseif dir == -1 then
			-- Scrolling UP

			-- Old next slides out right
			addCard(cards, index + 2, slots.next, {
				x = slots.next.x + offset * 0.7,
				y = centerY,
				scale = CAROUSEL_SCALE_SIDE * 0.85,
				alpha = 0
			}, mapCount)

			-- Old current -> next
			addCard(cards, index + 1, slots.curr, slots.next, mapCount)

			-- Old previous -> current (new selection)
			addCard(cards, index, slots.prev, slots.curr, mapCount)

			-- New previous slides in from left
			addCard(cards, index - 1, {
				x = slots.prev.x - offset * 0.7,
				y = centerY,
				scale = CAROUSEL_SCALE_SIDE * 0.85,
				alpha = 0
			}, slots.prev, mapCount)
		end

		----------------------------------------------------------------
		-- Resolve transforms (lerp) + sort back → front
		----------------------------------------------------------------
		local resolved = {}
		for i = 1, #cards do
			local c = cards[i]
			local from, to = c.from, c.to

			resolved[#resolved + 1] = {
				i = c.i,
				x = lerp(from.x,     to.x,     p),
				y = lerp(from.y,     to.y,     p),
				s = lerp(from.scale, to.scale, p),
				a = lerp(from.alpha, to.alpha, p),
			}
		end

		table.sort(resolved, function(a, b)
			return a.s < b.s
		end)

		----------------------------------------------------------------
		-- Draw carousel (CENTER-ANCHORED)
		----------------------------------------------------------------
		for i = 1, #resolved do
			local r  = resolved[i]
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

		----------------------------------------------------------------
		-- Border on current card
		----------------------------------------------------------------
		lg.setColor(1, 1, 1, 0.75)
		lg.setLineWidth(3)
		lg.rectangle("line", slots.curr.x - pw * 0.5, slots.curr.y - ph * 0.5, pw, ph, 6, 6)
		lg.setLineWidth(1)

		-- Locked overlay on current map
		if isMapLocked(index) then
			lg.setColor(0, 0, 0, 0.45)
			lg.rectangle("fill", slots.curr.x - pw * 0.5, slots.curr.y - ph * 0.5, pw, ph, 12, 12)

			Fonts.set("menu")
			lg.setColor(1, 1, 1, 0.85)
			lg.printf("LOCKED", slots.curr.x - pw * 0.5, slots.curr.y - 14, pw, "center")
		end

		----------------------------------------------------------------
		-- Text / UI
		----------------------------------------------------------------
		local textY = pyTop + ph + PAD_PREVIEW

		Fonts.set("menu")
		lg.setColor(colorText)
		lg.printf(map.name, 0, textY, sw, "center")
		textY = textY + PAD_TITLE

		Fonts.set("ui")
		lg.setColor(1, 1, 1, 0.6)
		lg.printf(("Map %d of %d"):format(index, mapCount), 0, textY, sw, "center")
		textY = textY + PAD_META

		lg.setColor(1, 1, 1, 0.8)
		lg.printf("[Enter] Play   [Esc] Back", 0, textY, sw, "center")

		--[[ =====================================================
		-- Scroll indicators (optional but helpful)
		-- =====================================================
		local pulse = 0.6 + sin(love.timer.getTime() * 3) * 0.2
		local arrowX = cx + pw * 0.5
		local arrowPad = 22

		if index > 1 then
			drawTriangle(arrowX, py - arrowPad, "up", 8, pulse)
		end

		if index < #Maps then
			drawTriangle(arrowX, py + ph + arrowPad, "down", 8, pulse)
		end]]
	-- Settings
	elseif State.mode == "settings" then
		local spacing = 32
		local y = floor(sh * 0.45)

		Fonts.set("menu")
		lg.setColor(colorText)
		lg.printf("Settings", 0, y - 56, sw, "center")

		Fonts.set("ui")

		for i, item in ipairs(settingsItems) do
			local selected = (i == settingsCursor)
			local alpha = selected and 1 or 0.6
			local prefix = selected and "> " or "  "

			lg.setColor(colorText[1], colorText[2], colorText[3], alpha)
			lg.printf(prefix .. item.label, 0, y, sw, "center")
			y = y + spacing
		end
	end
end

-- Input
function Menu.keypressed(key)
	if State.mode == "menu" then
		if key == "up" then
			cursor = max(1, cursor - 1)
			Sound.play("uiMove")
		elseif key == "down" then
			cursor = min(#menuItems, cursor + 1)
			Sound.play("uiMove")
		elseif key == "return" then
			Sound.play("uiConfirm")
			if cursor == 1 then
				previewAlpha = 0
				State.mode = "campaign"
			elseif cursor == 2 then
				State.mode = "settings"
			elseif cursor == 3 then
				love.event.quit()
			end
		end
	elseif State.mode == "campaign" then
		if key == "left" then
			local old = State.mapIndex
			local new = old - 1

			if new < 1 then
				Sound.play("uiError")
				return
			end

			State.mapIndex = new
			State.carouselDir = -1
			State.carouselT = 0
			previewAlpha = 0
			Sound.play("uiMove")
		elseif key == "right" then
			local old = State.mapIndex
			local new = old + 1

			if new > #Maps or isMapLocked(new) then
				Sound.play("uiError")
				return
			end

			State.mapIndex = new
			State.carouselDir = 1
			State.carouselT = 0
			previewAlpha = 0
			Sound.play("uiMove")
		elseif key == "return" then
			if isMapLocked(State.mapIndex) then
				Sound.play("uiError")
				return
			end

			Sound.play("uiConfirm")
			State.mode = "game"
			resetGame()
		elseif key == "escape" then
			Sound.play("uiBack")
			State.mode = "menu"
		end
	elseif State.mode == "settings" then
		if key == "up" then
			settingsCursor = max(1, settingsCursor - 1)
			Sound.play("uiMove")
		elseif key == "down" then
			settingsCursor = min(#settingsItems, settingsCursor + 1)
			Sound.play("uiMove")
		elseif key == "left" or key == "right" then
			if settingsItems[settingsCursor].key == "fullscreen" then
				love.window.setFullscreen(not love.window.getFullscreen())
				local w, h = lg.getDimensions()
				require("core.camera").resize(w, h)
				Sound.play("uiConfirm")
			end
		elseif key == "return" or key == "escape" then
			State.mode = "menu"
			Sound.play("uiBack")
		end
	end
end

return Menu