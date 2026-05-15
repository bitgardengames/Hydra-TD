local Sim = require("core.sim")
local State = require("core.state")
local Camera = require("core.camera")
local Draw = require("render.draw")
local Towers = require("world.towers")
local TowerBranchDefs = require("world.tower_branch_defs")
local Sound = require("systems.sound")
local Waves = require("systems.waves")
local Constants = require("core.constants")
local Theme = require("core.theme")
local Fonts = require("core.fonts")
local Difficulty = require("systems.difficulty")

local lg = love.graphics

local versionText = Constants.VERSION_STRING
local versionPad = 12

local colorText = Theme.ui.text
local cr, cg, cb = colorText[1], colorText[2], colorText[3]

local FIXED_DT = 1 / 120

local Backdrop = {
    active = false,
    t = 0,
    shotIndex = 1,
    shots = {},

    fadeT = 0,
    fadeDur = 0.20,
	fadeDurInitial = 0.50,
    fadeDir = -1,
	isInitial = true,
}

Backdrop.shots = {
	--[[{
		duration = 14,
		map = 7,
		towers = {
			{kind = "cannon", gx = 11, gy = 9, level = 3},
			{kind = "slow", gx = 12, gy = 10, level = 2},
			{kind = "poison", gx = 17, gy = 6, level = 4},
			{kind = "plasma", gx = 21, gy = 11, level = 3},
		},
		wave = 17,
		warmup = 20.0,
		camera = {gx = 16, gy = 7, ox = 180, oy = 50, zoom = 2.0},
	},]]

	{
		duration = 14,
		map = 3,
		towers = {
			{kind = "cannon", gx = 12, gy = 9, level = 3},
			{kind = "slow", gx = 13, gy = 9, level = 4},
			{kind = "shock", gx = 11, gy = 6, level = 4},
			{kind = "poison", gx = 21, gy = 8, level = 3},
			{kind = "plasma", gx = 22, gy = 11, level = 4},
		},
		wave = 17,
		warmup = 20.0,
		camera = {gx = 16, gy = 7, ox = 0, oy = 0, zoom = 2.0},
	},

	{
		duration = 14,
		map = 5,
		towers = {
			{kind = "lancer", gx = 12, gy = 8, level = 4},
			{kind = "shock", gx = 22, gy = 8, level = 2},
			{kind = "shock", gx = 13, gy = 8, level = 4},
			{kind = "plasma", gx = 22, gy = 6, level = 4},
		},
		wave = 12,
		warmup = 55.0,
		camera = {gx = 12, gy = 8, ox = 200, oy = -164, zoom = 2.0},
	},

	{
		duration = 14,
		map = 2,
		towers = {
			{kind = "cannon", gx = 12, gy = 6, level = 4},
			{kind = "shock", gx = 12, gy = 10, level = 5},
			{kind = "poison", gx = 22, gy = 6, level = 4},
			--{kind = "plasma", gx = 22, gy = 11, level = 3},
		},
		wave = 13,
		warmup = 26.0,
		camera = {gx = 16, gy = 7, ox = 52, oy = -62, zoom = 2.0},
	},

	{
		duration = 14,
		map = 12,
		towers = {
			{kind = "cannon", gx = 12, gy = 6, level = 3},
			{kind = "slow", gx = 12, gy = 9, level = 5},
			--{kind = "poison", gx = 22, gy = 7, level = 4},
			{kind = "lancer", gx = 22, gy = 7, level = 3},
			{kind = "plasma", gx = 21, gy = 8, level = 3},
		},
		wave = 13,
		warmup = 20.0,
		camera = {gx = 16, gy = 7, ox = -24, oy = -152, zoom = 2.0},
	},

	{
		duration = 14,
		map = 10,
		towers = {
			{kind = "cannon", gx = 13, gy = 5, level = 5},
			{kind = "lancer", gx = 13, gy = 9, level = 3},
			{kind = "poison", gx = 21, gy = 7, level = 5},
			{kind = "lancer", gx = 23, gy = 7, level = 4},
		},
		wave = 18,
		warmup = 21.0,
		camera = {gx = 16, gy = 7, ox = 24, oy = -152, zoom = 2.0},
	},
}

function Backdrop.start(index)
	Backdrop.active = true
	Backdrop.t = 0

	if index then
		Backdrop.shotIndex = index
	else
		Backdrop.shotIndex = math.random(1, #Backdrop.shots)
	end

	local shot = Backdrop.shots[Backdrop.shotIndex]

	State.worldMapIndex = shot.map

	-- Save current difficulty
	if not Backdrop.prevDifficulty then
		Backdrop.prevDifficulty = Difficulty.key()
	end

	-- Force difficulty
	Difficulty.set("hard")

	resetGame()

	State.ignoreStats = true

	State.money = 9999

	Sound.suppressed = true

	-- Place towers
	for _, t in ipairs(shot.towers or {}) do
		local ok = Towers.addTower(t.kind, t.gx, t.gy)

		if ok and t.level then
			local tower = Towers.towers[#Towers.towers]

			if tower then
				for i = 1, (t.level - 1) do
					local nextLevel = (tower.level or 1) + 1
					local choices = TowerBranchDefs.getChoices(tower.kind, nextLevel) or {}
					local choiceCount = #choices
					local choiceId = choiceCount > 0 and choices[((i - 1) % choiceCount) + 1] or nil

					if choiceId then
						Towers.upgradeTower(tower, choiceId)
					end
				end
			end
		end
	end

	-- Start wave
	State.wave = shot.wave or 1
	Waves.startWave()

	-- Warmup
	local tt = 0

	while tt < (shot.warmup or 0) do
		Sim.update(FIXED_DT)
		tt = tt + FIXED_DT
	end

	Sound.suppressed = false

	-- begin fade-in
	local dur = Backdrop.isInitial and Backdrop.fadeDurInitial or Backdrop.fadeDur

	Backdrop.fadeT = dur
	Backdrop.fadeDir = -1
	Backdrop.currentFadeDur = dur
	Backdrop.isInitial = false
end

function Backdrop.update(dt)
	if not Backdrop.active then
		return
	end

	-- Handle fade
	if Backdrop.fadeDir ~= 0 then
		Backdrop.fadeT = Backdrop.fadeT + FIXED_DT * Backdrop.fadeDir

		if Backdrop.fadeDir == 1 and Backdrop.fadeT >= Backdrop.currentFadeDur then
			Backdrop.fadeT = Backdrop.currentFadeDur
			Backdrop.shotIndex = Backdrop.shotIndex % #Backdrop.shots + 1

			Backdrop.start(Backdrop.shotIndex)

			return
		elseif Backdrop.fadeDir == -1 and Backdrop.fadeT <= 0 then
			Backdrop.fadeT = 0
			Backdrop.fadeDir = 0
		end
	end

	Backdrop.t = Backdrop.t + dt

	local shot = Backdrop.shots[Backdrop.shotIndex]

	if Backdrop.t >= shot.duration and Backdrop.fadeDir == 0 then
		Backdrop.fadeDir = 1
		Backdrop.fadeT = 0
	end
end

function Backdrop.draw()
	if not Backdrop.active then
		return
	end

	local shot = Backdrop.shots[Backdrop.shotIndex]

	local tile = Constants.TILE
	local gx = shot.camera.gx
	local gy = shot.camera.gy

	local cx = gx * tile + tile * 0.5
	local cy = gy * tile + tile * 0.5

	Camera.centerOn(cx + (shot.camera.ox or 0), cy + (shot.camera.oy or 0), shot.camera.zoom or Camera.wscale)

	Camera.begin()
	Draw.drawWorld()
	Camera.finish()
	Camera.present()

	-- Fade overlay
	if Backdrop.fadeT > 0 then
		local p = Backdrop.fadeT / Backdrop.currentFadeDur

		p = p * p * (3 - 2 * p)

		lg.setColor(0.08, 0.08, 0.08, p)
		lg.rectangle("fill", 0, 0, lg.getWidth(), lg.getHeight())
		lg.setColor(1, 1, 1, 1)
	end

	-- Version tag
	local sw, sh = lg.getDimensions()

	Fonts.set("ui")

	love.graphics.setColor(cr, cg, cb, 0.75)

	local font = Fonts.ui
	local tw = font:getWidth(versionText)
	local th = font:getHeight()

	love.graphics.print(versionText, sw - tw - versionPad - 5, sh - th - versionPad)
end

function Backdrop.stop()
	Backdrop.active = false

	State.ignoreStats = false

	if Backdrop.prevDifficulty then
		Difficulty.set(Backdrop.prevDifficulty)
		Backdrop.prevDifficulty = nil
	end
end

return Backdrop
