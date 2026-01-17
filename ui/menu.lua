local Constants = require("core.constants")
local Sound = require("systems.sound")
local Fonts = require("core.fonts")
local Theme = require("core.theme")
local State = require("core.state")
local Util = require("core.util")
local Save = require("core.save")
local Maps = require("world.maps")
local Title = require("ui.title")
local Text = require("ui.text")

local Menu = {}

local cursor = 1
local previewAlpha = 1
local mapPreviews = {}

local colorText = Theme.ui.text
local colorPath = Theme.terrain.path
local colorGrass = Theme.terrain.grass

local lg = love.graphics
local sin = math.sin
local rad = math.rad
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
	{label = "SFX Volume", key = "sfx"},
	{label = "Fullscreen", key = "fullscreen"},
	{label = "Back"},
}

local HERO_ANGLE = -math.pi / 6 -- Not just any old angle

local lancerIdle = {
	angle = HERO_ANGLE,
	from = HERO_ANGLE,
	to = HERO_ANGLE - rad(28),
	t = 0,
	hold = 0,
	dir = 1,
	startupHold = 5,
}

local function ease(p)
	return p * p * (3 - 2 * p)
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

-- Map Preview Generation
local function buildMapPreview(mapDef)
	-- Big hero preview
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

		lg.line((ax - 0.5) * tileW, (ay - 0.5) * tileH, (bx - 0.5) * tileW, (by - 0.5) * tileH)
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

local function drawUIMeter(label, color, value, maxValue, x, y, selected)
	local t = max(0, min(1, value / maxValue))

	-- Selection caret
	if selected then
		Text.printShadow(">", x - 18, y)
	end

	-- Label
	Text.printShadow(label, x, y)

	-- Bar background
	lg.setColor(0, 0, 0, 0.35)
	lg.rectangle("fill", x + 120, y + 4, 120, 8, 4, 4)

	-- Fill
	if value > 0 then
		lg.setColor(color[1], color[2], color[3], 1)
		lg.rectangle("fill", x + 120, y + 4, 120 * t, 8, 4, 4)
	end
end

local function isMapLocked(i)
	return not Save.isMapUnlocked(i, Maps[i].id)
end

-- Carousel
local carouselCards = {}

local function addCard(cards, i, from, to, mapCount)
	if i < 1 or i > mapCount then
		return
	end

	cards[#cards + 1] = {i = i, from = from, to = to}
end

function Menu.load()
	for i, map in ipairs(Maps) do
		mapPreviews[i] = buildMapPreview(map)
	end
end

-- Draw
function Menu.draw()
	local sw, sh = lg.getDimensions()

	-- Main menu
	if State.mode == "menu" then
		local dt = love.timer.getDelta()
		local t  = love.timer.getTime()

		local ROTATE_TIME = 1.8
		local HOLD_TIME   = 5.0

		local spacing = 44
		local y = floor(sh * 0.45)

		-- Lancer idle update
		if lancerIdle.startupHold > 0 then
			-- Startup hero pose hold
			lancerIdle.startupHold = lancerIdle.startupHold - dt
			lancerIdle.angle = HERO_ANGLE
		else
			-- Normal swivel logic
			if lancerIdle.hold > 0 then
				lancerIdle.hold = lancerIdle.hold - dt
			else
				lancerIdle.t = lancerIdle.t + dt / ROTATE_TIME

				if lancerIdle.t >= 1 then
					lancerIdle.t = 0
					lancerIdle.hold = HOLD_TIME
					lancerIdle.dir = -lancerIdle.dir
				end
			end

			-- Base swivel
			local p = lancerIdle.t

			p = p * p * (3 - 2 * p)

			local a, b

			if lancerIdle.dir == 1 then
				a, b = lancerIdle.from, lancerIdle.to
			else
				a, b = lancerIdle.to, lancerIdle.from
			end

			lancerIdle.angle = a + (b - a) * p

			-- Servo while holding
			if lancerIdle.hold > 0 then
				local SERVO_AMPLITUDE = rad(0.35)
				local SERVO_SPEED = 1.8
				local fade = min(1, lancerIdle.hold / 0.6)

				local servo = sin(t * SERVO_SPEED) * SERVO_AMPLITUDE * fade
				lancerIdle.angle = lancerIdle.angle + servo
			end
		end

		-- Draw menu
		lg.setColor(0.31, 0.57, 0.76, 1)
		lg.rectangle("fill", 0, 0, sw, sh)

		Title.draw({x = sw * 0.5, y = y - 72, lancerScale = 3.0, angle = lancerIdle.angle, alpha = 1})

		Fonts.set("menu")

		y = y + spacing

		for i, label in ipairs(menuItems) do
			local pulse = (i == cursor) and (0.85 + sin(t * 4) * 0.15) or 1
			local prefix = (i == cursor) and "> " or "  "

			lg.setColor(colorText[1], colorText[2], colorText[3], pulse)

			Text.printfShadow(prefix .. label, 0, y, sw, "center")

			y = y + spacing
		end
	-- Campaign / map select
	elseif State.mode == "campaign" then
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

		-- Slot targets
		local slots = {
			prev = {x = centerX - offset, y = centerY, scale = CAROUSEL_SCALE_SIDE, alpha = CAROUSEL_ALPHA_SIDE},
			curr = {x = centerX, y = centerY, scale = 1.0, alpha = 1.0},
			next = {x = centerX + offset, y = centerY, scale = CAROUSEL_SCALE_SIDE, alpha = CAROUSEL_ALPHA_SIDE}
		}

		-- Draw backdrop
		lg.setColor(0.31, 0.57, 0.76, 1)
		lg.rectangle("fill", 0, 0, sw, sh)

		-- Build carousel cards (reuse table, no allocations)
		local cards = carouselCards

		for i = #cards, 1, -1 do
			cards[i] = nil
		end

		if dir == 0 then
			-- Idle / settled: always show prev, curr, next
			addCard(cards, index - 1, slots.prev, slots.prev, mapCount)
			addCard(cards, index, slots.curr, slots.curr, mapCount)
			addCard(cards, index + 1, slots.next, slots.next, mapCount)
		elseif dir == 1 then
			-- Old previous slides out left
			addCard(cards, index - 2, slots.prev, {x = slots.prev.x - offset * 0.7, y = centerY, scale = CAROUSEL_SCALE_SIDE * 0.85, alpha = 0}, mapCount)

			-- Old current -> previous
			addCard(cards, index - 1, slots.curr, slots.prev, mapCount)

			-- Old next -> current (new selection)
			addCard(cards, index, slots.next, slots.curr, mapCount)

			-- New next slides in from right
			addCard(cards, index + 1, {x = slots.next.x + offset * 0.7, y = centerY, scale = CAROUSEL_SCALE_SIDE * 0.85, alpha = 0}, slots.next, mapCount)
		elseif dir == -1 then
			-- Old next slides out right
			addCard(cards, index + 2, slots.next, {x = slots.next.x + offset * 0.7, y = centerY, scale = CAROUSEL_SCALE_SIDE * 0.85, alpha = 0}, mapCount)

			-- Old current -> next
			addCard(cards, index + 1, slots.curr, slots.next, mapCount)

			-- Old previous -> current (new selection)
			addCard(cards, index, slots.prev, slots.curr, mapCount)

			-- New previous slides in from left
			addCard(cards, index - 1, {x = slots.prev.x - offset * 0.7, y = centerY, scale = CAROUSEL_SCALE_SIDE * 0.85, alpha = 0}, slots.prev, mapCount)
		end

		-- Resolve transforms (lerp)
		local resolved = {}

		for i = 1, #cards do
			local c = cards[i]
			local from, to = c.from, c.to

			resolved[#resolved + 1] = {
				i = c.i,
				x = lerp(from.x, to.x, p),
				y = lerp(from.y, to.y, p),
				s = lerp(from.scale, to.scale, p),
				a = lerp(from.alpha, to.alpha, p),
			}
		end

		table.sort(resolved, function(a, b)
			return a.s < b.s
		end)

		-- Draw carousel
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

		-- Border on current card
		lg.setColor(1, 1, 1, 0.75)
		lg.setLineWidth(3)
		lg.rectangle("line", slots.curr.x - pw * 0.5, slots.curr.y - ph * 0.5, pw, ph, 6, 6)
		lg.setLineWidth(1)

		-- Locked overlay on current map
		if isMapLocked(index) then
			lg.setColor(0, 0, 0, 0.45)
			lg.rectangle("fill", slots.curr.x - pw * 0.5, slots.curr.y - ph * 0.5, pw, ph, 12, 12)

			Fonts.set("title")
			lg.setColor(1, 1, 1, 0.85)
			lg.printf("LOCKED", slots.curr.x - pw * 0.5, slots.curr.y - 14, pw, "center")
		end

		-- Text / UI
		local textY = pyTop + ph + PAD_PREVIEW

		Fonts.set("title")
		lg.setColor(colorText)
		lg.printf(map.name, 0, textY, sw, "center")
		textY = textY + PAD_TITLE

		Fonts.set("menu")
		lg.setColor(1, 1, 1, 0.6)
		lg.printf(("Map %d of %d"):format(index, mapCount), 0, textY, sw, "center")
		textY = textY + PAD_META

		lg.setColor(1, 1, 1, 0.8)
		lg.printf("[Enter] Play   [Esc] Back", 0, textY, sw, "center")

		--[[
		-- Scroll indicators (optional but helpful)
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
		-- Backdrop
		lg.setColor(0.31, 0.57, 0.76, 1)
		lg.rectangle("fill", 0, 0, sw, sh)

		local centerX = floor(sw * 0.5)
		local startY = floor(sh * 0.45)
		local lineH = 44

		Fonts.set("title")

		lg.setColor(1, 1, 1, 1)
		Text.printfShadow("Settings", 0, startY - 56, sw, "center")

		Fonts.set("menu")

		-- Music
		drawUIMeter("Music Volume", Theme.tower.shock, Save.data.settings.musicVolume, 1, centerX - 140, startY, settingsCursor == 1)

		lg.setColor(1, 1, 1, 1)

		-- SFX
		drawUIMeter("SFX Volume", Theme.tower.cannon, Save.data.settings.sfxVolume, 1, centerX - 140, startY + lineH, settingsCursor == 2)

		-- Fullscreen
		local fsY = startY + lineH * 2

		lg.setColor(1, 1, 1, 1)

		if settingsCursor == 3 then
			Text.printShadow(">", centerX - 140 - 18, fsY)
		end

		Text.printfShadow("Fullscreen", 0, fsY, sw, "center")

		-- Row 4: Back
		local backY = fsY + lineH

		lg.setColor(1, 1, 1, 1)

		if settingsCursor == 4 then
			Text.printShadow(">", centerX - 140 - 18, backY)
		end

		Text.printfShadow("Back", 0, backY, sw, "center")
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

				-- Focus carousel on furthest unlocked map
				State.mapIndex = math.min(Save.data.furthestIndex or 1, #Maps)
				State.carouselDir = 0
				State.carouselT = 1

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
			local dir = (key == "right") and 1 or -1
			local step = 0.10

			if settingsCursor == 1 then
				local vol = Util.clamp(Save.data.settings.musicVolume + dir * step, 0, 1)
				vol = math.floor(vol / step + 0.5) * step
				
				Save.data.settings.musicVolume = vol
				Sound.setMusicVolume(vol)
				Sound.play("uiMove")
				Save.flush()
			elseif settingsCursor == 2 then
				local vol = Util.clamp(Save.data.settings.sfxVolume + dir * step, 0, 1)
				vol = math.floor(vol / step + 0.5) * step
				
				Save.data.settings.sfxVolume = vol
				Sound.setSFXVolume(vol)
				Sound.play("uiMove")
				Save.flush()
			elseif settingsCursor == 3 then
				local isFullscreen = love.window.getFullscreen()

				if isFullscreen then
					-- Go windowed (must set a mode)
					--love.window.setFullscreen(false)
					love.window.setMode(1280, 800, {fullscreen = false, resizable = true, vsync = 1})
				else
					-- Go fullscreen (desktop resolution)
					--love.window.setFullscreen(true)
					love.window.setMode(0, 0, {fullscreen = true, fullscreentype = "desktop", vsync = 1})
				end

				Save.data.settings.fullscreen = isFullscreen

				-- Recalculate camera scaling
				require("core.camera").resize()

				Sound.play("uiConfirm")
				Save.flush()
			end
		elseif key == "return" or key == "escape" then
			State.mode = "menu"
			Sound.play("uiBack")
		end
	end
end

return Menu