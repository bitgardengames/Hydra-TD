local State = require("core.state")
local Theme = require("core.theme")
local Util = require("core.util")
local WaveBuilder = require("systems.wave_builder")
local Waves = require("systems.waves")
local GameSpeed = require("core.game_speed")
local Hotkeys = require("core.hotkeys")
local Text = require("ui.text")
local Button = require("ui.button")
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
local WAVE_X = 150
local CONTROL_PAD = 8
local CONTROL_GAP = 8
local SPEED_BUTTON_W = 76
local START_BUTTON_W = 112
local CONTROL_H = 20

local speedButtons = {{anim = Button.newAnimation()}}
local startButtons = {{anim = Button.newAnimation()}}

speedButtons[1].onClick = function()
	GameSpeed.cycle()
end

startButtons[1].onClick = function()
	if State.inPrep then
		Waves.startWave()
	end
end

-- Text caches (no per-frame string rebuilding)
local hudCache = {
	money = {value = nil, text = ""},
	lives = {value = nil, text = ""},
	wave = {value = nil, text = ""},
	speed = {value = nil, text = ""},
}

local MONEY_RESPONSE = -60 * math.log(0.75)

function Hud.update(dt)
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

	lg.setColor(cm1, cm2, cm3, 1)
	Text.printShadow(moneyCache.text, infoX + MONEY_X, y)

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

	local waveCache = hudCache.wave
	local intensityTier = WaveBuilder.getIntensityTier(State.wave)

	if waveCache.value ~= State.wave then
		waveCache.value = State.wave
		waveCache.text = intensityTier > 0 and L("hud.endlessTier", State.wave, intensityTier) or L("hud.wave", State.wave)
	end

	lg.setColor(ct1, ct2, ct3, 1)
	Text.printShadow(waveCache.text, infoX + WAVE_X, y)

	-- Keep both actions as explicit rectangles so their mouse targets and visual
	-- states follow the same shared animation contract as the other HUD buttons.
	local startButton = startButtons[1]
	startButton.x = infoX + infoW - CONTROL_PAD - START_BUTTON_W
	startButton.y = infoY + floor((infoH - CONTROL_H) * 0.5 + 0.5)
	startButton.w = START_BUTTON_W
	startButton.h = CONTROL_H
	startButton.enabled = State.inPrep == true

	local speedButton = speedButtons[1]
	speedButton.x = startButton.x - CONTROL_GAP - SPEED_BUTTON_W
	speedButton.y = startButton.y
	speedButton.w = SPEED_BUTTON_W
	speedButton.h = CONTROL_H
	speedButton.enabled = true

	-- Always expose the active simulation multiplier, including during prep.
	local speedCache = hudCache.speed
	if speedCache.value ~= State.speed then
		speedCache.value = State.speed
		speedCache.text = L("hud.speed", State.speed)
	end
	local speedKey = Hotkeys.getDisplay("fastForward")
	speedButton.label = speedKey and (speedCache.text .. " [" .. speedKey .. "]") or speedCache.text

	local startLabel = L("hud.startWaveButton")
	local startKey = Hotkeys.getDisplay("skipPrep")
	startButton.label = startKey and (startLabel .. " [" .. startKey .. "]") or startLabel

	Button.updateList(speedButtons, dt, mx, my)
	Button.updateList(startButtons, dt, mx, my)
	Button.drawList(speedButtons)
	Button.drawList(startButtons)

end

function Hud.getSpeedButtons()
	return speedButtons
end

function Hud.getStartButtons()
	return startButtons
end

return Hud
