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

local min = math.min

local lg = love.graphics

local FONT = lg.newFont("assets/fonts/PTSans.ttf", 82)

local Director = {
	t = 0,
	shot = nil,
	nextShot = nil,

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

	Director.buildScene(Director.shot.scene)
end

function Director.update(dt)
    Director.t = Director.t + dt

    -- Run simulation
	if Director.shot.type ~= "logo" then
		Sim.update(dt)

		-- Camera (absolute time)
		Director.shot.camera.update(Director.t)
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
	else
		-- Clear to black for logo cards
		lg.clear(0, 0, 0, 1)


		-- Backdrop
		local sw, sh = lg.getDimensions()

		lg.setColor(0.31, 0.57, 0.76, 1)
		lg.rectangle("fill", 0, 0, sw, sh)
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

	-- Text beat
	if Director.activeText then
		local tb = Director.activeText
		local t  = Director.textT

		local w = lg.getWidth()
		local h = lg.getHeight()

		-- Base layout
		local yBase = h * 0.65
		local drift = 10 -- pixels of vertical motion
		local y = yBase

		-- Alpha calculation
		local alpha = 1

		if tb.fadeIn > 0 and t < tb.fadeIn then
			alpha = t / tb.fadeIn
		elseif tb.fadeOut > 0 and t > tb.dur - tb.fadeOut then
			alpha = (tb.dur - t) / tb.fadeOut
		end

		alpha = math.max(0, math.min(1, alpha))
		alpha = alpha * alpha * (3 - 2 * alpha) -- smoothstep

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
		lg.setFont(FONT)
		lg.setColor(1, 1, 1, alpha)

		-- Shadow
		lg.setColor(0, 0, 0, alpha * 0.35)
		lg.printf(
			tb.text,
			3,
			y + 3,
			w,
			"center"
		)

		-- Main text
		lg.setColor(1, 1, 1, alpha)
		lg.printf(
			tb.text,
			0,
			y,
			w,
			"center"
		)

		lg.setColor(1, 1, 1, 1)
	end

	-- Logo
	if Director.activeLogo then
		local logo = Director.shot.logo
		local t = Director.logoT

		local screenW = lg.getWidth()
		local screenH = lg.getHeight()

		-- Timing
		local inDur = logo.fadeIn or 0.6

		local p = 1
		if t < inDur then
			local x = t / inDur
			p = x * x * (3 - 2 * x) -- smoothstep
		end

		-- Alpha (very light)
		local alpha = 0.9 + 0.1 * p

		-- Virtual banner size
		local baseScale = 0.66
		local scale = baseScale * (0.97 + 0.03 * p)

		local w = math.floor(screenW * scale)
		local h = math.floor(screenH * scale)

		-- Position (settle upward)
		local centerX = math.floor((screenW - w) * 0.5)

		local settleUp = 120   -- final upward bias
		local slide    = 24    -- intro motion distance

		local centerY =
			math.floor((screenH - h) * 0.5)
			- settleUp
			+ math.floor((1 - p) * slide)

		-- Draw
		lg.push()
		lg.translate(centerX, centerY)

		lg.setColor(1, 1, 1, alpha)
		Title.drawAnimatedBannerStyle(w, h, Director.logoT, {
			alpha = alpha,
			baseAngle = -math.pi / 6,
			swivelAmplitude = math.rad(4.5), -- slightly calmer than menu
			servoAmplitude  = math.rad(0.25),
		})

		lg.pop()

		lg.setColor(1, 1, 1, 1)
	end
end

return Director