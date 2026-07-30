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
	preview = {wave = nil, entries = nil, count = 0},
	spawn = {remaining = nil, count = nil, text = ""},
}

function Hud.draw(infoX, infoY, infoW, infoH, dt)
	local font = lg.getFont()
	local textH = font:getHeight()
	local y = State.inPrep and (infoY + 1) or (infoY + floor((infoH - textH) * 0.5 + 0.5))

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

		local previewCache = hudCache.preview
		if previewCache.wave ~= State.wave then
			local preview = Waves.getWavePreview(State.wave)
			previewCache.wave = State.wave
			previewCache.count = preview.count
			previewCache.entries = {}
			for i = 1, #preview.composition do
				local group = preview.composition[i]
				previewCache.entries[i] = L("hud.compositionEntry", group.count, group.name)
			end
		end

		lg.setColor(cg1, cg2, cg3, 1)
		Text.printShadow(prepCache.text, infoX + STATUS_X, y)

		-- The composition gets the full second row. Drop trailing groups until the
		-- localized text fits; the total remains visible even when details do not.
		local entries = previewCache.entries
		local visible = #entries
		local maxWidth = infoW - 16
		local previewText
		repeat
			local details = table.concat(entries, L("hud.compositionSeparator"), 1, visible)
			if visible < #entries then
				details = details .. L("hud.moreComposition")
			end
			previewText = L("hud.nextWave", details, L("hud.waveTotal", previewCache.count))
			if font:getWidth(previewText) <= maxWidth or visible == 0 then break end
			visible = visible - 1
		until false

		Text.printShadow(previewText, infoX + 8, infoY + infoH - textH - 1)
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
