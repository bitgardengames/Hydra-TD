local State = require("core.state")
local Theme = require("core.theme")
local Util = require("core.util")
local Hotkeys = require("core.hotkeys")
local Save = require("core.save")
local Text = require("ui.text")
local L = require("core.localization")

local lg = love.graphics
local floor = math.floor
local sin = math.sin
local exp = math.exp
local pi = math.pi

local Hud = {}

-- Cache color components once (avoid table indexing every frame)
local colorText = Theme.ui.text
local colorMoney = Theme.ui.money
local colorLives = Theme.ui.lives

local ct1, ct2, ct3 = colorText[1], colorText[2], colorText[3]
local cm1, cm2, cm3 = colorMoney[1], colorMoney[2], colorMoney[3]
local cl1, cl2, cl3 = colorLives[1], colorLives[2], colorLives[3]

local formatInt = Util.formatInt

local MONEY_X = 12
local LIVES_X = 90
local CONTROL_PAD = 8

-- Text caches (no per-frame string rebuilding)
local hudCache = {
	money = {value = nil, text = ""},
	lives = {value = nil, text = ""},
	speed = {value = nil, text = ""},
}

local MONEY_RESPONSE = -60 * math.log(0.75)
local MONEY_PULSE_DURATION = 0.34
local MONEY_PULSE_FLOOR = 0.22

-- This follows authoritative money, rather than moneyLerp: the latter remains
-- solely responsible for making the displayed number easy to read.
local previousMoney
local moneyPulse = 0
local moneyPulseTime = 0

local function changeStrength(delta)
	-- $10 is noticeable, while very large wave rewards do not throw the label
	-- outside its allotted HUD space.
	return math.min(1, math.log(1 + math.abs(delta)) / math.log(101))
end

local function feedbackPose(pulse, remaining, reducedMotion)
	local amount = math.min(1, math.abs(pulse))
	local progress = 1 - math.min(1, math.max(0, remaining) / MONEY_PULSE_DURATION)
	local envelope = sin(progress * pi) * amount
	local gain = pulse > 0
	local r, g, b = cm1, cm2, cm3
	if gain then
		r = r + (0.32 - r) * envelope
		g = g + (1 - g) * envelope
		b = b + (0.42 - b) * envelope
	else
		r = r + (1 - r) * envelope * 0.7
		g = g + (0.48 - g) * envelope * 0.7
		b = b + (0.22 - b) * envelope * 0.7
	end
	return {
		r = r, g = g, b = b,
		y = reducedMotion and 0 or (gain and -3.5 or 2.25) * envelope,
		scaleY = reducedMotion and 1 or (gain and 1 + 0.035 * envelope or 1 - 0.075 * envelope),
	}
end

function Hud.update(dt)
	dt = math.max(0, dt or 0)
	if previousMoney == nil then
		previousMoney = State.money
	elseif State.money ~= previousMoney then
		local delta = State.money - previousMoney
		local signedStrength = (delta > 0 and 1 or -1) * math.max(MONEY_PULSE_FLOOR, changeStrength(delta))
		-- Add changes into one bounded pulse. Keeping some of the existing clock
		-- makes bursts feel continuous without allowing them to extend forever.
		moneyPulse = math.max(-1, math.min(1, moneyPulse * 0.55 + signedStrength))
		moneyPulseTime = math.max(moneyPulseTime, MONEY_PULSE_DURATION * 0.65)
		if moneyPulseTime == 0 then moneyPulseTime = MONEY_PULSE_DURATION end
		previousMoney = State.money
	end
	moneyPulseTime = math.max(0, moneyPulseTime - dt)
	if moneyPulseTime == 0 then moneyPulse = 0 end
	local factor = 1 - exp(-MONEY_RESPONSE * dt)
	State.moneyLerp = State.moneyLerp + (State.money - State.moneyLerp) * factor
end

function Hud.draw(infoX, infoY, infoW, infoH, dt, mx, my)
	local font = lg.getFont()
	local textH = font:getHeight()
	local y = infoY + floor((infoH - textH) * 0.5 + 0.5)

	local moneyRounded = floor(State.moneyLerp + 0.5)

	local moneyCache = hudCache.money

	if moneyCache.value ~= moneyRounded then
		moneyCache.value = moneyRounded
		moneyCache.text = "$" .. formatInt(moneyRounded)
	end

	local settings = Save.data and Save.data.settings or {}
	local moneyPose = feedbackPose(moneyPulse, moneyPulseTime, settings.cameraMotion == false)
	local moneyX = infoX + MONEY_X
	local moneyY = y + moneyPose.y
	lg.setColor(moneyPose.r, moneyPose.g, moneyPose.b, 1)
	if moneyPose.scaleY ~= 1 then
		lg.push()
		lg.translate(moneyX, moneyY + textH * 0.5)
		lg.scale(1, moneyPose.scaleY)
		Text.printShadow(moneyCache.text, 0, -textH * 0.5)
		lg.pop()
	else
		Text.printShadow(moneyCache.text, moneyX, moneyY)
	end

	local livesCache = hudCache.lives

	if livesCache.value ~= State.lives then
		livesCache.value = State.lives
		livesCache.text = L("hud.lives", State.lives)
	end

	lg.setColor(cl1, cl2, cl3, 1)
	local livesAnim = State.livesAnim or 0

	if livesAnim > 0 then
		local x = infoX + LIVES_X
		local t = 1 - livesAnim
		local easedT = 1 - (1 - t) * (1 - t)
		local dipY = sin(easedT * pi * 1.85) * livesAnim * 4.5
		local animY = y + dipY

		Text.printShadow(livesCache.text, x, animY)

		lg.setColor(cl1, cl2, cl3, 0.25 + livesAnim * 0.5)
		Text.printShadow(livesCache.text, x, animY + 1)
	else
		Text.printShadow(livesCache.text, infoX + LIVES_X, y)
	end

	-- Always expose the active simulation multiplier, including during prep.
	local speedCache = hudCache.speed
	if speedCache.value ~= State.speed then
		speedCache.value = State.speed
		speedCache.text = L("hud.speed", State.speed)
	end
	local speedKey = Hotkeys.getDisplay("fastForward")
	local speedLabel = speedKey and (speedCache.text .. " [" .. speedKey .. "]") or speedCache.text

	-- Keep the bottom bar focused on persistent run status. Starting a wave remains
	-- available through its hotkey and the wave preview control.
	local right = infoX + infoW - CONTROL_PAD
	lg.setColor(ct1, ct2, ct3, 1)
	Text.printShadow(speedLabel, right - font:getWidth(speedLabel), y)
end

return Hud
