local Config = require("tools.trailer.config")
local Camera = require("core.camera")
local Draw = require("ui.draw")
local Towers = require("world.towers")
local State = require("core.state")
local Waves = require("systems.waves")
local Shots = require("tools.trailer.shots")
local Sim = require("tools.trailer.sim")
local Recorder = require("tools.trailer.recorder")
local Title = require("ui.title")
local Fonts = require("core.fonts")
local Enemies = require("world.enemies")
local Sound = require("systems.sound")

local pi = math.pi
local min = math.min
local max = math.max
local sin = math.sin

local lg = love.graphics

local FONT_HERO = lg.newFont("assets/fonts/PTSans.ttf", 112)
local FONT_CTA = lg.newFont("assets/fonts/PTSans.ttf", 82)

local Director = {
	t = 0,
	shot = nil,
	nextShot = nil,
	activeCamera = nil,

	transition = nil, -- "out", "hold", "in"
	transitionT = 0,
	transitionDur = 0.25,

	transitionHold = 0,
	transitionHoldFrames = 2, -- tweak: 1–3 is ideal

	warmupActions = {},
	timelineActions = {},

	activeText = nil,
	textT = 0,

	activeLogo = false,
	logoT = 0,

	ctx = nil,
}

local HERO_ANGLE = -math.pi / 6

Director.lancerIdle = {
    t = 0,
    hold = 0,
    dir = 1,
    from = HERO_ANGLE,
    to = HERO_ANGLE - math.rad(28),
    angle = HERO_ANGLE,
    startupHold = 0.4,
}

function Director.buildScene(scene)
    if not scene then
		return
	end

	State.money = 99999 -- Hacks, I'm reporting you

    -- Place towers instantly
    if scene.towers then
        for _, t in ipairs(scene.towers) do
            Towers.addTower(t.kind, t.gx, t.gy)
        end
    end

	-- Run warmup actions (t == 0)
	for _, action in ipairs(Director.warmupActions or {}) do
		action.fn()
		action.done = true
	end

    -- Start wave early if requested
    if scene.wave then
        if scene.wave.index then
            State.wave = scene.wave.index - 1
            Waves.startWave()
        elseif scene.wave.start then
            Waves.startWave()
        end

        local warmup = scene.wave.warmup or 0
        local step = 1 / 60
        local t = 0

        while t < warmup do
            Sim.update(step)
            t = t + step
        end
    end
end

function Director.load(name)
	Director.shot = Shots[name]
	assert(Director.shot, "Trailer shot not found: " .. tostring(name))

	Director.t = 0

	Director.ctx = {
		firstEnemy = nil,
	}

	-- Logo-only shot, no world setup
	if Director.shot.type == "logo" then
		return
	end

	-- Reset action flags
	Director.warmupActions = {}
	Director.timelineActions = {}

	for _, a in ipairs(Director.shot.actions or {}) do
		a.done = false

		if a.t == 0 then
			table.insert(Director.warmupActions, a)
		else
			table.insert(Director.timelineActions, a)
		end
	end

	-- Jump to map
	State.mapIndex = Director.shot.map

	-- Reset game
	State.mode = "game"
	resetGame()

	Sound.suppressed = true

	Director.buildScene(Director.shot.scene)

	Sound.suppressed = false

	-- Resolve camera (function or static)
	if type(Director.shot.camera) == "function" then
		Director.activeCamera = Director.shot.camera(Director.ctx)
	else
		Director.activeCamera = Director.shot.camera
	end
end

function Director.update(dt)
    Director.t = Director.t + dt

    -- Run simulation
	if Director.shot.type ~= "logo" then
		Sim.update(dt)

		-- Capture first enemy once
		if not Director.ctx.firstEnemy then
			local enemies = Enemies.enemies

			if enemies and enemies[1] then
				Director.ctx.firstEnemy = enemies[1]
			end
		end

		-- Camera
		if Director.activeCamera then
			Director.activeCamera.update(Director.t)
		end
	end

    -- Run scheduled actions
    for _, action in ipairs(Director.timelineActions or {}) do
        if not action.done and Director.t >= action.t then
            action.fn()
            action.done = true
        end
    end

	local texts = Director.shot.text or {}

	for _, tb in ipairs(texts) do
		if not tb.done and Director.t >= tb.t then
			Director.activeText = tb
			Director.textT = 0
			tb.done = true
		end
	end

	if Director.activeText then
		Director.textT = Director.textT + dt

		if Director.textT >= Director.activeText.dur then
			Director.activeText = nil
		end
	end

	local logo = Director.shot.logo

	if logo and not logo.done and Director.t >= logo.t then
		Director.activeLogo = true
		Director.logoT = 0
		logo.done = true
	end

	if Director.activeLogo then
		Director.logoT = Director.logoT + dt

		Title.updateLancerIdle(Director.lancerIdle, dt, Director.logoT)

		if Director.logoT >= logo.dur then
			Director.activeLogo = false
		end
	end

    -- Shot finished?
	if Director.t >= Director.shot.duration and not Director.transition then
		if Config.mode == "single" then
			-- Stop immediately after this shot
			Recorder.enabled = false
			love.event.quit()

			return
		end

		-- sequence mode
		if Director.shot.next then
			Director.transition = "out"
			Director.transitionT = 0
			Director.nextShot = Director.shot.next
		else
			Recorder.enabled = false
			love.event.quit()
		end
	end

	if Director.transition == "out" then
		Director.transitionT = Director.transitionT + dt

		if Director.transitionT >= Director.transitionDur then
			-- Fully black now
			Director.load(Director.nextShot)
			Director.nextShot = nil

			-- Begin hold
			Director.transition = "hold"
			Director.transitionHold = Director.transitionHoldFrames
			Director.transitionT = 0
		end
	elseif Director.transition == "hold" then
		Director.transitionHold = Director.transitionHold - 1

		if Director.transitionHold <= 0 then
			-- Start fade-in
			Director.transition = "in"
			Director.transitionT = 0
		end
	elseif Director.transition == "in" then
		Director.transitionT = Director.transitionT + dt

		if Director.transitionT >= Director.transitionDur then
			Director.transition = nil
			Director.transitionT = 0
		end
	end
end

function Director.draw()
	if Director.shot.type ~= "logo" then
		Camera.begin()
		Draw.drawWorld()
		Camera.finish()
		Camera.present()

		Fonts.set("floaters")

		Draw.drawFloaters()
	else
		-- Clear to black for logo cards
		lg.clear(0, 0, 0, 1)


		-- Backdrop
		local sw, sh = lg.getDimensions()

		lg.setColor(0.31, 0.57, 0.76, 1)
		lg.rectangle("fill", 0, 0, sw, sh)
	end

	-- Text beat
	if Director.activeText then
		local tb = Director.activeText
		local t  = Director.textT

		local w = lg.getWidth()
		local h = lg.getHeight()

		-- Base layout
		local yBase = h * 0.60
		local drift = 10 -- pixels of vertical motion
		local y = yBase

		-- Alpha calculation
		local alpha = 1

		if tb.fadeIn > 0 and t < tb.fadeIn then
			alpha = t / tb.fadeIn
		elseif tb.fadeOut > 0 and t > tb.dur - tb.fadeOut then
			alpha = (tb.dur - t) / tb.fadeOut
		end

		alpha = max(0, min(1, alpha))
		alpha = alpha * alpha * (3 - 2 * alpha)

		-- Vertical motion
		if tb.fadeIn > 0 and t < tb.fadeIn then
			local p = t / tb.fadeIn
			p = p * p * (3 - 2 * p)

			y = yBase + drift * (1 - p)
		elseif tb.fadeOut > 0 and t > tb.dur - tb.fadeOut then
			local p = (tb.dur - t) / tb.fadeOut
			p = p * p * (3 - 2 * p)

			y = yBase - drift * (1 - p)
		end

		-- Draw
		if tb.smallText then
			lg.setFont(FONT_CTA)
		else
			lg.setFont(FONT_HERO)
		end

		lg.setColor(1, 1, 1, alpha)

		-- Shadow
		lg.setColor(0, 0, 0, alpha * 0.35)
		lg.printf(tb.text, 3, y + 3, w, "center")

		-- Main text
		lg.setColor(1, 1, 1, alpha)
		lg.printf(tb.text, 0, y, w, "center")

		lg.setColor(1, 1, 1, 1)
	end

	-- Logo
	if Director.activeLogo then
		local screenW = lg.getWidth()
		local screenH = lg.getHeight()

		local fadeDur = 0.15
		local alphaStart = 0.60

		-- Fixed banner scale
		local baseScale = 0.56
		local w = math.floor(screenW * baseScale)
		local h = math.floor(screenH * baseScale)

		-- Centered position, then nudged upward
		local centerX = math.floor((screenW - w) * 0.5)
		local centerY = math.floor((screenH - h) * 0.5) - 120

		-- Subtle alpha settle
		local p = 1

		if Director.logoT < fadeDur then
			p = Director.logoT / fadeDur
			p = p * p * (3 - 2 * p) -- smoothstep
		end

		local alpha = alphaStart + (1 - alphaStart) * p

		lg.push()
		lg.translate(centerX, centerY)

		lg.setColor(1, 1, 1, alpha)
		Title.drawBannerStyle(w, h, {alpha = 1, angle = Director.lancerIdle.angle})

		lg.pop()

		lg.setColor(1, 1, 1, 1)
	end

	if Director.transition then
		local alpha = 1

		if Director.transition == "out" then
			local t = min(1, Director.transitionT / Director.transitionDur)

			t = t * t * (3 - 2 * t) -- smoothstep
			alpha = t
		elseif Director.transition == "hold" then
			alpha = 1
		elseif Director.transition == "in" then
			local t = min(1, Director.transitionT / Director.transitionDur)

			t = t * t * (3 - 2 * t)
			alpha = 1 - t
		end

		lg.setColor(0, 0, 0, alpha)
		lg.rectangle(
			"fill",
			0, 0,
			lg.getWidth(),
			lg.getHeight()
		)
		lg.setColor(1, 1, 1, 1)
	end
end

return Director