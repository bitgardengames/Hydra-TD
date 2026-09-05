local Theme = require("core.theme")
local State = require("core.state")
local Save = require("core.save")
local Text = require("ui.text")

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

local colorHealthR, colorHealthG, colorHealthB = colorHealth[1] * 0.4, colorHealth[2] * 0.4, colorHealth[3] * 0.4

local y = 24
local barW = 354
local barH = 26
local outlineW = Theme.outline.width
local outerRadius = 6 + outlineW * 0.5
local innerRadius = 6 - outlineW * 0.25
local idleLift = 6

local ENTRANCE_DURATION = 0.24
local EXIT_DURATION = 0.18

local cache = {
	identity = nil,
	maxHp = nil,
	displayHp = nil,
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
	if type(boss) ~= "table" then return nil end
	if type(boss.hp) ~= "number" or type(boss.maxHp) ~= "number" then return nil end
	if boss.hp <= 0 or boss.maxHp <= 0 then return nil end
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
	cache.visibility = 0
	cache.hpValue = nil
	cache.maxText = formatNum(maxHp)
	cache.text = nil
	cache.thresholds = meaningfulThresholds(boss, maxHp)
end

local function clear()
	cache.identity, cache.maxHp = nil, nil
	cache.displayHp = nil
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
	elseif hp > oldDisplay then
		-- Healing is smoothed to keep increases in the main fill easy to follow.
		cache.displayHp = min(hp, oldDisplay + maxHp * dt * 2.5)
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
	-- A smooth, centered unfurl gives the bar some personality without moving its
	-- anchor or adding spring/recoil motion when the boss takes damage.
	local reveal = visibility * visibility * (3 - 2 * visibility)
	local sw = lg.getWidth()
	local x = floor((sw - barW) * 0.5)
	local fy = y - idleLift
	local alpha = reveal
	if presentationPulse > 0 then alpha = min(1, alpha + presentationPulse * 0.35) end
	local r, g, b, a = colorBase[1], colorBase[2], colorBase[3], (colorBase[4] or 1) * alpha

	-- Both layers unfold together so the raised cutaway remains intact throughout.
	local shownW = max(1, floor(barW * reveal))
	local shownX = x + floor((barW - shownW) * 0.5)
	lg.setColor(colorOutline[1], colorOutline[2], colorOutline[3], alpha)
	lg.rectangle("fill", shownX - outlineW, y - outlineW, shownW + outlineW * 2, barH + outlineW * 2, outerRadius)
	lg.setColor(r * 0.4, g * 0.4, b * 0.4, a)
	lg.rectangle("fill", shownX, y, shownW, barH, innerRadius)
	lg.setColor(colorOutline[1], colorOutline[2], colorOutline[3], alpha)
	lg.rectangle("fill", shownX - outlineW, fy - outlineW, shownW + outlineW * 2, barH + outlineW * 2, outerRadius)
	lg.setColor(colorHealthR, colorHealthG, colorHealthB, alpha)
	lg.rectangle("fill", shownX, fy, shownW, barH, innerRadius)

	local fillW = floor(shownW * max(0, min(1, cache.displayHp / maxHp)))
	lg.setColor(colorHealth[1], colorHealth[2], colorHealth[3], alpha)
	lg.rectangle("fill", shownX, fy, fillW, barH, innerRadius)

	if cache.thresholds then
		lg.setColor(colorText[1], colorText[2], colorText[3], 0.72 * alpha)
		for index, fraction in ipairs(cache.thresholds) do
			local tx = shownX + floor(shownW * fraction)
			if boss and boss.lungeWindup and boss.lungeActiveThreshold == index then
				local pulse = 0.65 + 0.35 * math.sin((boss.lungeWindup or 0) * 18)
				lg.setColor(1, 0.55, 0.16, pulse * alpha)
				lg.rectangle("fill", tx - 3, fy, 6, barH)
			else
				lg.setColor(colorText[1], colorText[2], colorText[3], 0.72 * alpha)
			end
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
	-- Let the face open before introducing the label; this avoids squeezed text
	-- during the short unfurl animation.
	local textAlpha = max(0, min(1, (reveal - 0.55) / 0.45)) * alpha
	lg.setColor(colorText[1], colorText[2], colorText[3], textAlpha)
	Text.printShadow(cache.text, x + (barW - cache.textW) * 0.5, fy + (barH - textH) * 0.5)
end

return BossHP
