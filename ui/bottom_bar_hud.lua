local State = require("core.state")
local Theme = require("core.theme")
local Util = require("core.util")
local Enemies = require("world.enemies")
local Waves = require("systems.waves")
local Hotkeys = require("core.hotkeys")
local Text = require("ui.text")
local L = require("core.localization")

local lg = love.graphics
local floor = math.floor
local sin = math.sin
local pi = math.pi

local Hud = {}

-- Cache color components once (avoid table indexing every frame)
local colorText = Theme.ui.text
local colorMoney = Theme.ui.money
local colorLives = Theme.ui.lives
local colorGood = Theme.ui.good

local ct1, ct2, ct3 = colorText[1], colorText[2], colorText[3]
local cm1, cm2, cm3 = colorMoney[1], colorMoney[2], colorMoney[3]
local cl1, cl2, cl3 = colorLives[1], colorLives[2], colorLives[3]
local cg1, cg2, cg3 = colorGood[1], colorGood[2], colorGood[3]

local formatInt = Util.formatInt

local MONEY_X = 12
local LIVES_X = 90
local WAVE_X = 170
local STATUS_X = 260

-- Text caches (no per-frame string rebuilding)
local hudCache = {
	money = {value = nil, text = ""},
	lives = {value = nil, text = ""},
	wave = {value = nil, text = ""},
	prep = {value = nil, text = "", action = nil},
	spawn = {remaining = nil, count = nil, text = ""},
}

function Hud.draw(infoX, infoY, infoW, infoH, dt)
	local font = lg.getFont()
	local textH = font:getHeight()
	local y = infoY + floor((infoH - textH) * 0.5 + 0.5)

	-- Smooth money
	State.moneyLerp = State.moneyLerp + (State.money - State.moneyLerp) * 0.25
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
		local shakeX = sin(t * 42) * livesAnim * 2.4
		local dipY = sin(t * pi * 1.6) * livesAnim * 5
		local animY = y + dipY

		Text.printShadow(livesCache.text, x + shakeX, animY)

		lg.setColor(cl1, cl2, cl3, 0.25 + livesAnim * 0.5)
		Text.printShadow(livesCache.text, x + shakeX * 0.6, animY + 1)
	else
		Text.printShadow(livesCache.text, infoX + LIVES_X, y)
	end

	local waveCache = hudCache.wave

	if waveCache.value ~= State.wave then
		waveCache.value = State.wave
		waveCache.text = L("hud.wave", State.wave)
	end

	lg.setColor(ct1, ct2, ct3, 1)
	Text.printShadow(waveCache.text, infoX + WAVE_X, y)

	-- Prep / spawning block
	if State.inPrep then
		local prepCache = hudCache.prep
		local skipKey = Hotkeys.getDisplay("skipPrep")

		if prepCache.action ~= skipKey then
			prepCache.action = skipKey
			prepCache.text = L("hud.prep", skipKey)
		end

		lg.setColor(cg1, cg2, cg3, 1)
		Text.printShadow(prepCache.text, infoX + STATUS_X, y)
	else
		local spawner = Waves.getSpawner()
		local spawnCache = hudCache.spawn
		local remaining = spawner.remaining
		local count = #Enemies.enemies

		if spawnCache.remaining ~= remaining or spawnCache.count ~= count then
			spawnCache.remaining = remaining
			spawnCache.count = count
			spawnCache.text = L("hud.spawning", remaining, count)
		end

		lg.setColor(0.85, 0.85, 0.85, 0.85)
		Text.printShadow(spawnCache.text, infoX + STATUS_X, y)
	end
end

return Hud
