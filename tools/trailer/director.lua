local Config = require("tools.trailer.config")
local Camera = require("core.camera")
local Draw = require("render.draw")
local DrawWorld = require("render.draw_world")
local Towers = require("world.towers")
local State = require("core.state")
local Waves = require("systems.waves")
local Shots = require("tools.trailer.shots")
local Sim = require("core.sim")
local Recorder = require("tools.trailer.recorder")
local HeroExport = require("tools.trailer.hero_export")
local Title = require("ui.title")
local Fonts = require("core.fonts")
local Enemies = require("world.enemies")
local Floaters = require("ui.floaters")
local Sound = require("systems.sound")

local pi = math.pi
local min = math.min
local max = math.max
local sin = math.sin
local floor = math.floor

local lg = love.graphics

local HERO_FONT_SIZE = 168
local CTA_FONT_SIZE = 120

local FONT_HERO = lg.newFont("assets/fonts/PTSans.ttf", HERO_FONT_SIZE)
local FONT_CTA = lg.newFont("assets/fonts/PTSans.ttf", CTA_FONT_SIZE)

local FPS = 60
local STEP_DT = 1 / FPS

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

	scrub = {
		enabled = false,
		playing = false,
		frame = 0,
		lastShotName = nil,
	},
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

function Director._stepFixed(step)
	Director.t = Director.t + step

	Director.ctx.time = Director.t

	-- Run simulation
	if Director.shot.type ~= "logo" then
		Sim.update(step)

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

	-- Text beats
	local texts = Director.shot.text or {}

	for _, tb in ipairs(texts) do
		if not tb.done and Director.t >= tb.t then
			Director.activeText = tb
			Director.textT = 0
			tb.done = true
		end
	end

	if Director.activeText then
		Director.textT = Director.textT + step
		if Director.textT >= Director.activeText.dur then
			Director.activeText = nil
		end
	end

	-- Logo beat
	local logo = Director.shot.logo
	if logo and not logo.done and Director.t >= logo.t then
		Director.activeLogo = true
		Director.logoT = 0
		logo.done = true
	end

	if Director.activeLogo then
		Director.logoT = Director.logoT + step
		Title.updateLancerIdle(Director.lancerIdle, step, Director.logoT)
		if logo and Director.logoT >= logo.dur then
			Director.activeLogo = false
		end
	end
end

function Director.seekToFrame(frame)
	frame = max(0, frame)
	Director.scrub.frame = frame

	-- Reload current shot fresh
	local name = Director.scrub.lastShotName

	if not name then
		return
	end

	Director.load(name)

	-- Fast-forward deterministically
	for i = 1, frame do
		Director._stepFixed(STEP_DT)
	end
end


function Director.load(name)
	Director.shot = Shots[name]
	assert(Director.shot, "Trailer shot not found: " .. tostring(name))

	Director.scrub.lastShotName = name

	Director.t = 0

	Director.ctx = {
		firstEnemy = nil,
		time = 0,
	}

	-- Logo-only shot, no world setup
	if Director.shot.type == "logo" then
		Title.invalidateCache()

		return
	end

	HeroExport.init()

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
	State.worldMapIndex = Director.shot.map

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
	-- Scrub mode takes over time
	if Director.scrub.enabled then
		if Director.scrub.playing then
			-- advance in real time but quantized to fixed frames
			Director._scrubAccum = (Director._scrubAccum or 0) + dt

			while Director._scrubAccum >= STEP_DT do
				Director._scrubAccum = Director._scrubAccum - STEP_DT
				Director.scrub.frame = Director.scrub.frame + 1
				Director._stepFixed(STEP_DT)
			end
		end

		return
	end

	Director._stepFixed(dt)

    -- Run simulation
	if Director.shot.type ~= "logo" then
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

local function drawFadedBannerForText(text, font, y, alpha)
	local screenW = lg.getWidth()

	-- Visual tuning knobs
	local fade = 120
	local paddingX = 14
	local featherY = 8

	lg.setFont(font)

	-- Width tracks the actual string
	local textW = font:getWidth(text)
	local totalW = textW + paddingX * 2
	local x0 = (screenW - totalW) * 0.5

	-- Height is fixed relative to font size (not string content)
	local bannerHeight = font:getAscent() * 1.15

	-- Slight upward optical bias (feels centered)
	local y0 = y + font:getAscent() * 0.10

	-- Solid center slab
	lg.setColor(0, 0, 0, alpha)
	lg.rectangle("fill", x0, y0, totalW, bannerHeight)

	-- Horizontal fades
	for i = 1, fade do
		local a = alpha * (1 - i / fade)
		if a <= 0 then break end

		lg.setColor(0, 0, 0, a)
		lg.rectangle("fill", x0 - i, y0, 1, bannerHeight)
		lg.rectangle("fill", x0 + totalW + i - 1, y0, 1, bannerHeight)
	end
end

function Director.draw()
	if Director.shot.type ~= "logo" then
		if HeroExport.draw(function()
			--Camera.begin()
			Draw.drawWorld()
		end) then
			return -- Skip normal draw this frame
		end

		Camera.begin()
		Draw.drawWorld()
		Camera.finish()
		Camera.present()

		Fonts.set("title")

		Floaters.draw()
	else
		-- Clear to black for logo cards
		lg.clear(0, 0, 0, 1)

		-- Backdrop
		--local sw, sh = lg.getDimensions()

		--lg.setColor(0.31, 0.57, 0.76, 1)
		--lg.rectangle("fill", 0, 0, sw, sh)
		Camera.begin()
		DrawWorld.drawGrass()
		Camera.finish()
		Camera.present()
	end

	-- Text beat
	if Director.activeText then
		local tb = Director.activeText
		local t  = Director.textT

		local w = lg.getWidth()
		local h = lg.getHeight()

		-- Base layout
		local yBase = h * 0.65
		local drift = 10 -- Pixels of vertical motion
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
			-- Banner backdrop
			drawFadedBannerForText(tb.text, FONT_HERO, y - 10, alpha * 0.4)

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
		local sw = lg.getWidth()
		local sh = lg.getHeight()

		local fadeDur = 0.375
		local alphaStart = 0

		local baseScale = 0.56
		local w = floor(sw * baseScale)
		local h = floor(sh * baseScale)

		local p = 1
		if Director.logoT < fadeDur then
			p = Director.logoT / fadeDur
			p = p * p * (3 - 2 * p)
		end

		local alpha = alphaStart + (1 - alphaStart) * p

		-- Banner top-left position
		local x = floor(sw * 0.5)
		local y = floor(sh * 0.5) - 120

		lg.setColor(1, 1, 1, alpha)
		Title.draw({x = x, y = y, alpha = alpha, lancerScale = 7.0, angle = Director.lancerIdle.angle})

		lg.setColor(1, 1, 1, 1)
	end

	if Director.transition then
		local alpha = 1

		if Director.transition == "out" then
			local t = min(1, Director.transitionT / Director.transitionDur)

			t = t * t * (3 - 2 * t)
			alpha = t
		elseif Director.transition == "hold" then
			alpha = 1
		elseif Director.transition == "in" then
			local t = min(1, Director.transitionT / Director.transitionDur)

			t = t * t * (3 - 2 * t)
			alpha = 1 - t
		end

		lg.setColor(0, 0, 0, alpha)
		lg.rectangle("fill", 0, 0, lg.getWidth(), lg.getHeight())
		lg.setColor(1, 1, 1, 1)
	end
end

function love.keypressed(key)
	if key == "f9" then
		HeroExport.setFormat("vertical") -- or "vertical"
		HeroExport.capture({
			--subject = require("world.towers").towers[1], -- Actual tower instance from world.towers
			subject = require("world.enemies").enemies[1], -- Actual tower instance from world.towers
			subjectType = "enemy",
		})
	elseif key == "f8" then
		Director.scrub.enabled = not Director.scrub.enabled
		Director.scrub.playing = false
		Director._scrubAccum = 0

		-- When enabling scrub, lock to the *current* frame
		if Director.scrub.enabled then
			Director.scrub.frame = floor(Director.t * FPS + 0.5)
			Director.seekToFrame(Director.scrub.frame)
		end
	end

	if Director.scrub.enabled then
		if key == "space" then
			Director.scrub.playing = not Director.scrub.playing
		elseif key == "right" then
			Director.seekToFrame(Director.scrub.frame + 1)
		elseif key == "left" then
			Director.seekToFrame(Director.scrub.frame - 1)
		elseif key == "pagedown" then
			Director.seekToFrame(Director.scrub.frame + 10)
		elseif key == "pageup" then
			Director.seekToFrame(Director.scrub.frame - 10)
		elseif key == "home" then
			Director.seekToFrame(0)
		elseif key == "end" then
			local maxFrame = floor((Director.shot.duration or 0) * FPS + 0.5)
			Director.seekToFrame(maxFrame)
		end
	end
end

return Director