local State = require("core.state")
local Theme = require("core.theme")
local Enemies = require("world.enemies")
local Waves = require("systems.waves")
local Hotkeys = require("core.hotkeys")
local Text = require("ui.text")
local L = require("core.localization")

local lg = love.graphics
local floor = math.floor
local tostring = tostring

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

-- Text caches (no per-frame string rebuilding)
local hudCache = {
	money = {value = nil, text = ""},
	lives = {value = nil, text = ""},
	wave = {value = nil, text = ""},
	prep = {value = nil, text = "", action = nil},
	spawn = {remaining = nil, count = nil, text = ""},
}

-- Number formatting cache
local numCache = {}

local function formatNum(n)
	local v = floor(n + 0.5)
	local cached = numCache[v]

	if cached then
		return cached
	end

	local s = tostring(v)
	s = s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	numCache[v] = s

	return s
end

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
		moneyCache.text = "$" .. formatNum(moneyRounded)
	end

	lg.setColor(cm1, cm2, cm3, 1)
	Text.printShadow(moneyCache.text, infoX + 12, y)

	local livesCache = hudCache.lives

	if livesCache.value ~= State.lives then
		livesCache.value = State.lives
		livesCache.text = L("hud.lives", State.lives)
	end

	lg.setColor(cl1, cl2, cl3, 1)
	Text.printShadow(livesCache.text, infoX + 90, y)

	local waveCache = hudCache.wave

	if waveCache.value ~= State.wave then
		waveCache.value = State.wave
		waveCache.text = L("hud.wave", State.wave)
	end

	lg.setColor(ct1, ct2, ct3, 1)
	Text.printShadow(waveCache.text, infoX + 170, y)

	-- Prep / spawning block
	if State.inPrep then
		local t = floor(State.prepTimer * 10 + 0.5) / 10
		local prepCache = hudCache.prep
		local skipKey = Hotkeys.getDisplay("skipPrep")

		if prepCache.value ~= t or prepCache.action ~= skipKey then
			prepCache.value = t
			prepCache.action = skipKey
			prepCache.text = L("hud.prep", t, skipKey)
		end

		lg.setColor(cg1, cg2, cg3, 1)
		Text.printShadow(prepCache.text, infoX + 260, y)
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
		Text.printShadow(spawnCache.text, infoX + 260, y)
	end
end

return Hud