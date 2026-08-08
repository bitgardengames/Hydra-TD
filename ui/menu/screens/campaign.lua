local Sound = require("systems.sound")
local Difficulty = require("systems.difficulty")
local Fonts = require("core.fonts")
local Theme = require("core.theme")
local State = require("core.state")
local Save = require("core.save")
local Maps = require("world.map_defs")
local MapPreviewCache = require("world.map_preview_cache")
local Camera = require("core.camera")
local Text = require("ui.text")
local Button = require("ui.button")
local Medals = require("ui.medals")
local Tooltip = require("ui.tooltip")
local Backdrop = require("scenes.backdrop")
local Steam = require("core.steam")
local L = require("core.localization")
local CampaignUnlocks = require("systems.campaign_unlocks")
local Towers = require("world.towers")
local EnemyDefs = require("world.enemy_defs")

local lg = love.graphics
local floor = math.floor
local format = string.format

local Screen = {}

-- Colors
local colorText = Theme.ui.text
local colorShadow = Theme.ui.shadow
local colorDim = Theme.ui.screenDim
local colorBackdrop = Theme.ui.backdrop
local colorHover = {0.94, 0.94, 0.94}
local colorEnabled = {0.88, 0.88, 0.88}
local colorDisabled = {0.65, 0.65, 0.65}
local colorOutline = Theme.outline.color

-- Layout
local outlineW = Theme.outline.width
local baseRadius = 6 * 3
local outerRadius = baseRadius + outlineW * 0.5
local innerRadius = baseRadius - outlineW * 0.25

local PAD_PREVIEW = 44
local PAD_TITLE = 60
local PAD_META = 92
local TITLE_OFFSET = -22

local paddingX = 28
local paddingY = 28

local btnW = 240
local btnH = 42
local gap = 62

-- Arrow navigation
local ARROW_SIZE = 20
local PATH_TRIM_START = 34
local PATH_TRIM_END = 72

-- State
local campaignButtons = {}
local pulseTime = 0
local DIFFICULTY_ORDER = {"easy", "normal", "hard"}
local MEDAL_NAMES = {"bronze", "silver", "gold"}
local medalR = 9
local medalGap = 10
local medalInsetX = 22
local medalInsetY = 20
local getMapStats

local function hideMedalTooltip()
	Tooltip.hide()
end

local function updateMedalTooltip(mapId, previewX, previewY)
	local stats = getMapStats(mapId)
	local earnedCount = stats and stats.completedDifficulty and Medals.getCount(stats.completedDifficulty) or 0
	local mx, my = love.mouse.getPosition()
	local step = medalR * 2 + medalGap

	for tier = 1, earnedCount do
		-- These are the three medal hit rectangles, matching Medals.draw's
		-- centers and diameter exactly.
		local x = previewX + medalInsetX + (tier - 1) * step
		local y = previewY + medalInsetY
		local w, h = medalR * 2, medalR * 2

		if mx >= x and mx <= x + w and my >= y and my <= y + h then
			local difficultyKey = DIFFICULTY_ORDER[tier]
			local timestamp = stats.medalEarnedAt and stats.medalEarnedAt[difficultyKey]
			local earnedDate = L("campaign.medalDateUnavailable")
			if type(timestamp) == "number" then
				earnedDate = os.date(L("campaign.medalDateFormat"), timestamp)
			end

			Tooltip.show({
				title = L("campaign.medalTooltipTitle", L("campaign.medals." .. MEDAL_NAMES[tier]), L("difficulty." .. difficultyKey)),
				rows = {{label = L("campaign.medalEarnedOn"), value = earnedDate}},
			})
			return
		end
	end

	hideMedalTooltip()
end

local function getDifficultyIndex(key)
	for i, difficultyKey in ipairs(DIFFICULTY_ORDER) do
		if difficultyKey == key then
			return i
		end
	end

	return 2
end

local function cycleDifficulty(dir)
	local current = Save.data.settings.difficulty or Difficulty.default
	local index = getDifficultyIndex(current)
	local nextIndex = index + dir

	if nextIndex < 1 then
		nextIndex = #DIFFICULTY_ORDER
	elseif nextIndex > #DIFFICULTY_ORDER then
		nextIndex = 1
	end

	local nextDifficulty = DIFFICULTY_ORDER[nextIndex]

	Save.data.settings.difficulty = nextDifficulty
	Difficulty.set(nextDifficulty)
	Save.flush()
	Sound.play("uiMove")
end

local function difficultyButtonLabel()
	local current = Save.data.settings.difficulty or Difficulty.default

	return format("%s: %s", L("settings.difficulty"), L("difficulty." .. current))
end

-- Helpers
local function isMapLocked(i)
	return not Save.isMapUnlocked(i, Maps[i].id)
end

local function drawPathCurrent(entry, previewX, previewY, pw, ph, pulseT)
	local path = entry.pathWorld
	if not path or #path < 2 then return end

	local function toScreen(wx, wy)
		-- same logic as MapRender
		local winW = entry.winW or love.graphics.getWidth()
		local winH = entry.winH or love.graphics.getHeight()

		local sx = pw / winW
		local sy = ph / winH

		local z = entry.camScale or Camera.wscale

		local mapW = entry.mapW
		local mapH = entry.mapH

		local cx = mapW * 0.5
		local cy = mapH * 0.5

		local camWX = cx - (winW / (2 * z))
		local camWY = cy - (winH / (2 * z))

		-- apply camera transform
		local screenX = (wx - camWX) * z
		local screenY = (wy - camWY) * z

		-- apply canvas scaling
		screenX = screenX * sx
		screenY = screenY * sy

		return previewX + screenX, previewY + screenY
	end

	-- Precompute segment lengths
	local lengths = {}
	local points = {}
	local totalLen = 0

	for i = 1, #path do
		local px, py = toScreen(path[i][1], path[i][2])
		points[i] = {px, py}
	end

	for i = 1, #points - 1 do
		local x1, y1 = points[i][1], points[i][2]
		local x2, y2 = points[i + 1][1], points[i + 1][2]

		local dx = x2 - x1
		local dy = y2 - y1
		local len = math.sqrt(dx*dx + dy*dy)

		lengths[i] = len
		totalLen = totalLen + len
	end

	if totalLen <= 0 then return end

	-- Animate along path
	local speed = 140
	local trimStart = math.min(PATH_TRIM_START, totalLen * 0.45)
	local trimEnd = math.min(PATH_TRIM_END, totalLen * 0.45)
	local animLen = totalLen - trimStart - trimEnd
	if animLen <= 0 then
		return
	end

	local dist = trimStart + ((pulseT * speed) % animLen)
	local tailDist = 55
	local tailMaxAlpha = 0.28
	local fadeWindow = math.min(36, animLen * 0.2)
	local fadeIn = 1
	local fadeOut = 1

	if fadeWindow > 0 then
		fadeIn = math.min(1, (dist - trimStart) / fadeWindow)
		fadeOut = math.min(1, (trimStart + animLen - dist) / fadeWindow)
	end

	local headAlphaScale = math.min(fadeIn, fadeOut)

	local acc = 0

	for i = 1, #lengths do
		local segLen = lengths[i]

		if dist <= acc + segLen then
			local t = (dist - acc) / segLen

			local x1, y1 = points[i][1], points[i][2]
			local x2, y2 = points[i + 1][1], points[i + 1][2]

			local px = x1 + (x2 - x1) * t
			local py = y1 + (y2 - y1) * t

			-- Tail glow along the travelled section for a subtle routing cue.
			local tail = 0

			while tail < tailDist do
				local trailDist = math.max(trimStart, dist - tail)

				local trailAcc = 0
				local trailX, trailY = px, py

				for seg = 1, #lengths do
					local trailSegLen = lengths[seg]

					if trailDist <= trailAcc + trailSegLen then
						local trailT = (trailDist - trailAcc) / trailSegLen
						local tx1, ty1 = points[seg][1], points[seg][2]
						local tx2, ty2 = points[seg + 1][1], points[seg + 1][2]
						trailX = tx1 + (tx2 - tx1) * trailT
						trailY = ty1 + (ty2 - ty1) * trailT
						break
					end

					trailAcc = trailAcc + trailSegLen
				end

				local fade = 1 - (tail / tailDist)
				local alpha = tailMaxAlpha * fade * fade * headAlphaScale
				local radius = 4 + fade * 2
				lg.setColor(1, 1, 1, alpha)
				lg.circle("fill", trailX, trailY, radius)
				tail = tail + 8
			end

			-- Core
			lg.setColor(1, 1, 1, 0.9 * headAlphaScale)
			lg.circle("fill", px, py, 3)

			return
		end

		acc = acc + segLen
	end
end

local function pointInTriangle(px, py, ax, ay, bx, by, cx, cy)
	if ax == nil or ay == nil or bx == nil or by == nil or cx == nil or cy == nil then
		return false
	end
	local function sign(px, py, ax, ay, bx, by)
		return (px - bx) * (ay - by) - (ax - bx) * (py - by)
	end

	local b1 = sign(px, py, ax, ay, bx, by) < 0
	local b2 = sign(px, py, bx, by, cx, cy) < 0
	local b3 = sign(px, py, cx, cy, ax, ay) < 0

	return (b1 == b2) and (b2 == b3)
end

local function resolveArrowColor(enabled, hover)
	if not enabled then
		return colorDisabled
	end

	if hover then
		return colorHover
	end

	return colorEnabled
end

local function drawTriangleWithShadow(points, color)
	-- Shadow
	lg.setColor(colorShadow)
	lg.polygon("fill", points[1] + 1, points[2] + 1, points[3] + 1, points[4] + 1, points[5] + 1, points[6] + 1)

	-- Main triangle
	lg.setColor(color)
	lg.polygon("fill", unpack(points))
end

getMapStats = function(mapId)
	local stats = Save.data.mapStats

	return stats and stats[mapId]
end

local function getCompletionString(mapId)
	local s = getMapStats(mapId)

	if not s then
		return nil
	end

	if s.completedDifficulty then
		local diff = L("difficulty." .. s.completedDifficulty)
		if (s.bestEndlessWave or 0) > 0 then
			return L("campaign.completedBestEndless", diff, s.bestWave or 0, s.bestEndlessWave)
		end
		return L("campaign.completedBest", diff, s.bestWave or 0)
	end

	if (s.bestEndlessWave or 0) > 0 then
		return L("campaign.bestEndless", s.bestEndlessWave)
	end
	if s.bestWave and s.bestWave > 0 then
		return L("campaign.best", s.bestWave)
	end

	return nil
end

local function localizedTowerList(kinds)
	local names = {}

	for _, kind in ipairs(kinds or {}) do
		local def = Towers.TowerDefs[kind]
		names[#names + 1] = L((def and def.nameKey) or ("tower." .. kind))
	end

	return table.concat(names, L("campaign.previewListSeparator"))
end

local function buildPreviewMessages(map)
	local messages = {}
	local reward = CampaignUnlocks.getRewardForMap(map)

	if #(map.introducesEnemies or {}) > 0 then
		local names = {}
		for _, enemyId in ipairs(map.introducesEnemies) do
			local def = EnemyDefs[enemyId]
			names[#names + 1] = L((def and def.nameKey) or ("enemy." .. enemyId))
		end
		messages[#messages + 1] = L(#names == 1 and "campaign.newEnemy" or "campaign.newEnemies", table.concat(names, L("campaign.previewListSeparator")))
	end

	if reward then
		local rewardLabel = reward.labelKey and L(reward.labelKey) or reward.label
		if reward.type == "tower" then
			messages[#messages + 1] = L("campaign.clearReward", rewardLabel or localizedTowerList({reward.id}))
		elseif rewardLabel then
			messages[#messages + 1] = L("campaign.clearReward", rewardLabel)
		end
	end

	return messages
end

local function layoutCampaignButtons(cx, buttonsStartY)
	for i, btn in ipairs(campaignButtons) do
		btn.x = cx - btn.w * 0.5
		btn.y = buttonsStartY + (i - 1) * gap
		btn.enabled = (btn.id ~= "play") or not isMapLocked(State.mapIndex)

		if btn.id == "difficulty" then
			btn.label = difficultyButtonLabel()
		end
	end
end

local function getCampaignLayout(entry)
	local sw, sh = lg.getDimensions()
	local preview = entry.canvas
	local pw, ph = preview:getWidth(), preview:getHeight()
	local cx = floor(sw * 0.5)
	local buttonsBlockH = (#campaignButtons - 1) * gap + campaignButtons[1].h
	local contentH = ph + PAD_PREVIEW + PAD_TITLE + PAD_META + buttonsBlockH
	local boxW = pw + paddingX * 2
	local boxH = contentH + paddingY * 2
	local boxX = cx - boxW * 0.5
	local boxY = floor(sh * 0.5 - boxH * 0.5)
	local previewX = cx - pw * 0.5
	local previewY = boxY + paddingY
	local textY = previewY + ph + PAD_PREVIEW + TITLE_OFFSET

	return {
		sw = sw,
		sh = sh,
		cx = cx,
		preview = preview,
		previewX = previewX,
		previewY = previewY,
		previewW = pw,
		previewH = ph,
		boxX = boxX,
		boxY = boxY,
		boxW = boxW,
		boxH = boxH,
		textY = textY,
		arrowY = textY + 28,
		buttonsStartY = textY + PAD_TITLE + PAD_META,
	}
end

local function canNavigateMaps(direction)
	local nextIndex = State.mapIndex + direction
	if nextIndex < 1 or nextIndex > #Maps then
		return false
	end

	return direction < 0 or not isMapLocked(nextIndex)
end

local function navigateMaps(direction)
	if not canNavigateMaps(direction) then
		Sound.play("uiError")
		return false
	end

	hideMedalTooltip()
	State.mapIndex = State.resolveMapIndex(State.mapIndex + direction)
	Sound.play("uiMove")
	return true
end

local function getArrowPoints(layout, direction)
	local ax
	if direction < 0 then
		ax = layout.boxX + paddingX + ARROW_SIZE * 2
		return {ax + ARROW_SIZE * 0.5, layout.arrowY - ARROW_SIZE, ax - ARROW_SIZE * 0.5, layout.arrowY, ax + ARROW_SIZE * 0.5, layout.arrowY + ARROW_SIZE}
	end

	ax = layout.boxX + layout.boxW - paddingX - ARROW_SIZE * 2
	return {ax - ARROW_SIZE * 0.5, layout.arrowY - ARROW_SIZE, ax + ARROW_SIZE * 0.5, layout.arrowY, ax - ARROW_SIZE * 0.5, layout.arrowY + ARROW_SIZE}
end

local function pointInArrow(x, y, layout, direction)
	local points = getArrowPoints(layout, direction)
	return pointInTriangle(x, y, points[1], points[2], points[3], points[4], points[5], points[6])
end

-- Load
function Screen.load()
	campaignButtons = {
		{
			id = "difficulty",
			label = difficultyButtonLabel(),
			w = btnW,
			h = btnH,
			onClick = function()
				cycleDifficulty(1)
			end
		},

		{
			id = "play",
			label = L("menu.play"),
			w = btnW,
			h = btnH,
			onClick = function()
				hideMedalTooltip()
				if isMapLocked(State.mapIndex) then
					Sound.play("uiError")
					return
				end

				Sound.play("uiConfirm")

				State.worldMapIndex = State.mapIndex
				State.challenge = false
				State.endless = false
				State.mode = "game"
				Backdrop.stop()
				Difficulty.set(Save.data.settings.difficulty)
				resetGame()
				Sound.playMusic("gameplay")
			end
		},

		{
			id = "back",
			label = L("menu.back"),
			w = btnW,
			h = btnH,
			onClick = function()
				hideMedalTooltip()
				State.mode = "menu"
				Steam.setRichPresence(L("presence.menu"))
				Sound.play("uiBack")
			end
		}
	}
end

function Screen.update(dt)
	pulseTime = pulseTime + dt

	Backdrop.update(dt)
	Medals.update(dt)

	local index = State.mapIndex
	local map = Maps[index]
	local entry = MapPreviewCache.get(map.id)

	if not entry then
		hideMedalTooltip()
		return
	end

	local layout = getCampaignLayout(entry)
	updateMedalTooltip(map.id, layout.previewX, layout.previewY)

	-- Buttons
	layoutCampaignButtons(layout.cx, layout.buttonsStartY)

	local mx, my = love.mouse.getPosition()
	for i, btn in ipairs(campaignButtons) do
		Button.update(btn, mx, my, dt)
	end
end

function Screen.draw()
	Backdrop.draw()

	local index = State.mapIndex
	local map = Maps[index]
	local mapCount = #Maps
	local entry = MapPreviewCache.get(map.id)

	if not entry then
		return
	end

	local layout = getCampaignLayout(entry)
	local sw, sh = layout.sw, layout.sh
	local previewX, previewY = layout.previewX, layout.previewY
	local pw, ph = layout.previewW, layout.previewH

	-- Dim background
	lg.setColor(colorDim)
	lg.rectangle("fill", 0, 0, sw, sh)

	-- Panel
	lg.setColor(colorOutline)
	lg.rectangle("fill", layout.boxX - outlineW, layout.boxY - outlineW, layout.boxW + outlineW * 2, layout.boxH + outlineW * 2, outerRadius)

	lg.setColor(colorBackdrop)
	lg.rectangle("fill", layout.boxX, layout.boxY, layout.boxW, layout.boxH, innerRadius)

	-- Preview
	local locked = isMapLocked(index)
	local alpha = locked and 0.35 or 1.0

	lg.setColor(1, 1, 1, alpha)

	lg.draw(layout.preview, previewX, previewY)

	drawPathCurrent(entry, previewX, previewY, pw, ph, pulseTime)

	-- Completion medals
	local stats = getMapStats(map.id)
	local count = stats and stats.completedDifficulty and Medals.getCount(stats.completedDifficulty) or 0

	local platePadX = 10
	local platePadY = 8

	local clusterW, clusterH = Medals.getClusterSize(medalR, medalGap)

	local plateX = previewX + medalInsetX - platePadX
	local plateY = previewY + medalInsetY - platePadY
	local plateW = clusterW + platePadX * 2
	local plateH = clusterH + platePadY * 2

	lg.setColor(colorDim)
	lg.rectangle("fill", plateX, plateY, plateW, plateH, 8, 8)

	Medals.draw(previewX + medalInsetX, previewY + medalInsetY, count, medalR, medalGap, {
		time = pulseTime,
		shine = not Save.data.settings.reducedFlash,
	})

	--[[ Completion stats
	local statText = getCompletionString(map.id)

	if statText then
		local pad = 8
		local offsetX = 12 -- move right
		local offsetY = 4 -- move up

		local font = Fonts.get("ui")

		Fonts.set("ui")

		local tw = font:getWidth(statText)
		local th = 16

		local bx = previewX + pad + offsetX
		local by = previewY + ph - th - pad * 2 - offsetY
		local bw = tw + pad * 2
		local bh = th + pad * 2

		-- Backdrop
		lg.setColor(colorDim)
		lg.rectangle("fill", bx - pad, by - pad, bw, bh, 8, 8)

		-- Text
		lg.setColor(colorText)
		lg.print(statText, bx, by)
	end]]

	Fonts.set("title")

	-- Frame
	lg.setColor(colorOutline)
	lg.setLineWidth(3)
	lg.rectangle("line", previewX, previewY, pw, ph)
	lg.setLineWidth(1)

	-- Locked overlay
	if locked then
		lg.setColor(0.01, 0.01, 0.01, 0.45)
		lg.rectangle("fill", previewX, previewY, pw, ph, 12, 12)

		lg.setColor(colorText)
		Text.printfShadow(L("campaign.locked"), previewX, previewY + ph * 0.5 - 16, pw, "center")
	end

	local textY = layout.textY

	-- Arrows
	local leftEnabled = canNavigateMaps(-1)
	local rightEnabled = canNavigateMaps(1)
	local mx, my = love.mouse.getPosition()

	-- Left
	do
		local points = getArrowPoints(layout, -1)
		local hover = leftEnabled and pointInArrow(mx, my, layout, -1)

		local color = resolveArrowColor(leftEnabled, hover)
		drawTriangleWithShadow(points, color)
	end

	-- Right
	do
		local points = getArrowPoints(layout, 1)
		local hover = rightEnabled and pointInArrow(mx, my, layout, 1)

		local color = resolveArrowColor(rightEnabled, hover)
		drawTriangleWithShadow(points, color)
	end

	-- Title
	lg.setColor(colorText)
	Text.printfShadow(L(map.nameKey), 0, textY, sw, "center")

	Fonts.set("ui")

	Text.printfShadow(L("campaign.mapOf", index, mapCount), 0, textY + PAD_TITLE, sw, "center")

	local previewMessages = buildPreviewMessages(map)
	local metaY = textY + PAD_TITLE + 20
	for i, message in ipairs(previewMessages) do
		Text.printfShadow(message, 0, metaY + (i - 1) * 18, sw, "center")
	end

	-- Buttons
	layoutCampaignButtons(layout.cx, layout.buttonsStartY)

	Fonts.set("menu")

	for i, btn in ipairs(campaignButtons) do
		Button.draw(btn)
	end
end

function Screen.keypressed(key)
	if key == "left" then
		navigateMaps(-1)
	elseif key == "right" then
		navigateMaps(1)
	elseif key == "up" or key == "down" then
		cycleDifficulty(1)
	elseif key == "escape" then
		hideMedalTooltip()
		State.mode = "menu"
		Steam.setRichPresence(L("presence.menu"))
		Sound.play("uiBack")
	end
end

function Screen.mousepressed(x, y, button)
	if button == 1 then
		local index = State.mapIndex
		local map = Maps[index]
		local entry = MapPreviewCache.get(map.id)

		if not entry then
			return
		end

		local layout = getCampaignLayout(entry)

		-- Left
		if canNavigateMaps(-1) and pointInArrow(x, y, layout, -1) then
			navigateMaps(-1)
			return true
		end

		-- Right
		if canNavigateMaps(1) and pointInArrow(x, y, layout, 1) then
			navigateMaps(1)
			return true
		end
	end

	-- Buttons
	for _, btn in ipairs(campaignButtons) do
		if Button.mousepressed(btn, x, y, button) then
			return true
		end
	end
end

function Screen.mousereleased(x, y, button)
	for _, btn in ipairs(campaignButtons) do
		if Button.mousereleased(btn, x, y, button) then
			return true
		end
	end
end

function Screen.resize(w, h)
	hideMedalTooltip()
	MapPreviewCache.buildAll(520, 312)
	Backdrop.start()
end

function Screen.enter()
	hideMedalTooltip()
end

function Screen.leave()
	hideMedalTooltip()
end

return Screen
