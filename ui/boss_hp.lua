local Theme = require("core.theme")
local State = require("core.state")
local Save = require("core.save")
local Text = require("ui.text")
local Enemies = require("world.enemies")

local lg = love.graphics
local floor = math.floor
local ceil = math.ceil
local max = math.max
local min = math.min
local format = string.format

local colorText = Theme.ui.text
local colorHealth = Theme.ui.bossHealth
local colorOutline = Theme.outline.color
local colorBase = Theme.ui.button
local colorTrail = Theme.ui.warn

local colorHealthR, colorHealthG, colorHealthB = colorHealth[1] * 0.4, colorHealth[2] * 0.4, colorHealth[3] * 0.4

local y = 24
local barW = 354
local barH = 26
local outlineW = Theme.outline.width
local outerRadius = 6 + outlineW * 0.5
local innerRadius = 6 - outlineW * 0.25
local idleLift = 6

local TRAIL_DELAY = 0.10
local TRAIL_CATCHUP = 7
local ENTRANCE_DURATION = 0.24
local EXIT_DURATION = 0.18

local cache = {
	identity = nil,
	maxHp = nil,
	displayHp = nil,
	trailHp = nil,
	trailDelay = 0,
	visibility = 0,
	hpValue = nil,
	maxText = nil,
	text = nil,
	textW = 0,
	thresholds = nil,
}
local presentationPulse = 0

local BossHP = {}

local function formatNum(n)
	return tostring(floor(n + 0.5)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

local function resolveBoss()
	local boss = State.activeBoss
	if type(boss) == "string" then
		for i = 1, #Enemies.enemies do
			local enemy = Enemies.enemies[i]
			if enemy.boss == true and enemy.kind == boss and enemy.hp and enemy.hp > 0 then
				return enemy
			end
		end
		return nil
	end
	return boss
end

local function meaningfulThresholds(boss, maxHp)
	-- Boss definitions may opt in with ratios (0..1) or authored HP values.
	local source = boss.healthThresholds or boss.phaseThresholds or boss.thresholds
	if type(source) ~= "table" then return nil end
	local result = {}
	for _, value in ipairs(source) do
		if type(value) == "table" then value = value.hpFraction or value.fraction or value.hp end
		if type(value) == "number" then
			local fraction = value <= 1 and value or value / maxHp
			if fraction > 0 and fraction < 1 then result[#result + 1] = fraction end
		end
	end
	return #result > 0 and result or nil
end

local function reset(boss, hp, maxHp)
	cache.identity = boss
	cache.maxHp = maxHp
	cache.displayHp = hp
	cache.trailHp = hp
	cache.trailDelay = 0
	cache.visibility = 0
	cache.hpValue = nil
	cache.maxText = formatNum(maxHp)
	cache.text = nil
	cache.thresholds = meaningfulThresholds(boss, maxHp)
end

local function clear()
	cache.identity, cache.maxHp = nil, nil
	cache.displayHp, cache.trailHp = nil, nil
	cache.hpValue, cache.maxText, cache.text = nil, nil, nil
	cache.thresholds = nil
	cache.visibility = 0
end

local function motionEnabled()
	local settings = Save.data and Save.data.settings or {}
	return settings.screenShake ~= false and settings.cameraMotion ~= false
end

function BossHP.update(dt)
	presentationPulse = max(0, presentationPulse - max(0, dt or 0))
	local boss = resolveBoss()
	local hp = boss and boss.hp
	local maxHp = boss and boss.maxHp
	if type(hp) ~= "number" or type(maxHp) ~= "number" or maxHp <= 0 or hp <= 0 then
		if cache.identity == nil or not motionEnabled() then
			clear()
			return
		end
		dt = max(0, dt or 0)
		cache.visibility = max(0, cache.visibility - dt / EXIT_DURATION)
		if cache.visibility == 0 then clear() end
		return
	end

	if cache.identity ~= boss or cache.maxHp ~= maxHp then reset(boss, hp, maxHp) end
	dt = max(0, dt or 0)
	cache.visibility = motionEnabled() and min(1, cache.visibility + dt / ENTRANCE_DURATION) or 1
	local oldDisplay = cache.displayHp

	if hp < oldDisplay then
		cache.displayHp = hp -- Damage is always immediately legible in the main fill.
		cache.trailHp = max(cache.trailHp, oldDisplay)
		cache.trailDelay = TRAIL_DELAY
	elseif hp > oldDisplay then
		-- Healing is smoothed, while never allowing the damage trail below the fill.
		cache.displayHp = min(hp, oldDisplay + maxHp * dt * 2.5)
		cache.trailHp = max(cache.trailHp, cache.displayHp)
	end

	cache.trailDelay = max(0, cache.trailDelay - dt)
	if cache.trailDelay == 0 then
		cache.trailHp = max(cache.displayHp, cache.trailHp + (cache.displayHp - cache.trailHp) * min(1, dt * TRAIL_CATCHUP))
	end
end

function BossHP.presentationEvent(kind)
	if kind == "boss_incoming" then presentationPulse = 0.8 end
	if kind == "boss_spawn" then presentationPulse = 0.45 end
	if kind == "boss_defeated" then presentationPulse = 0.3 end
end

function BossHP.draw()
	local boss = resolveBoss()
	local hp = boss and boss.hp
	local maxHp = boss and boss.maxHp
	local bossIsActive = type(hp) == "number" and type(maxHp) == "number" and maxHp > 0 and hp > 0
	-- Keep draw robust for callers which have not run an update tick yet.
	if bossIsActive and (cache.identity ~= boss or cache.maxHp ~= maxHp) then
		reset(boss, hp, maxHp)
		cache.visibility = motionEnabled() and 0 or 1
	end
	if cache.identity == nil or cache.visibility <= 0 then return end
	maxHp = cache.maxHp

	local motion = motionEnabled()
	local visibility = motion and cache.visibility or 1
	local reveal = visibility * visibility * (3 - 2 * visibility)
	local sw = lg.getWidth()
	local x = floor((sw - barW) * 0.5)
	local fy = y - idleLift
	local alpha = reveal
	if presentationPulse > 0 then alpha = min(1, alpha + presentationPulse * 0.35) end
	local r, g, b, a = colorBase[1], colorBase[2], colorBase[3], (colorBase[4] or 1) * alpha

	-- Keep the bar at its full width while it fades in and out. This avoids the
	-- cutaway effect caused by horizontally clipping its raised layers.
	local shownW = barW
	local shownX = x
	lg.setColor(colorOutline[1], colorOutline[2], colorOutline[3], alpha)
	lg.rectangle("fill", shownX - outlineW, y - outlineW, shownW + outlineW * 2, barH + outlineW * 2, outerRadius)
	lg.setColor(r * 0.4, g * 0.4, b * 0.4, a)
	lg.rectangle("fill", shownX, y, shownW, barH, innerRadius)
	lg.setColor(colorOutline[1], colorOutline[2], colorOutline[3], alpha)
	lg.rectangle("fill", shownX - outlineW, fy - outlineW, shownW + outlineW * 2, barH + outlineW * 2, outerRadius)
	lg.setColor(colorHealthR, colorHealthG, colorHealthB, alpha)
	lg.rectangle("fill", shownX, fy, shownW, barH, innerRadius)

	local trailW = floor(shownW * max(0, min(1, cache.trailHp / maxHp)))
	local fillW = floor(shownW * max(0, min(1, cache.displayHp / maxHp)))
	if trailW > fillW then
		lg.setColor(colorTrail[1], colorTrail[2], colorTrail[3], 0.82 * alpha)
		lg.rectangle("fill", shownX, fy, trailW, barH, innerRadius)
	end
	lg.setColor(colorHealth[1], colorHealth[2], colorHealth[3], alpha)
	lg.rectangle("fill", shownX, fy, fillW, barH, innerRadius)

	if cache.thresholds then
		lg.setColor(colorText[1], colorText[2], colorText[3], 0.72 * alpha)
		for _, fraction in ipairs(cache.thresholds) do
			local tx = shownX + floor(shownW * fraction)
			lg.rectangle("fill", tx - 1, fy + 3, 2, barH - 6)
		end
	end

	local hpInt = ceil(cache.displayHp)
	if cache.hpValue ~= hpInt then
		cache.hpValue = hpInt
		cache.text = format("%s / %s", formatNum(hpInt), cache.maxText)
		cache.textW = lg.getFont():getWidth(cache.text)
	end
	local textH = lg.getFont():getHeight()
	lg.setColor(colorText[1], colorText[2], colorText[3], alpha)
	Text.printShadow(cache.text, x + (barW - cache.textW) * 0.5, fy + (barH - textH) * 0.5)
end

return BossHP
