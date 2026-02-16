local Config = require("tools.trailer.config")
local Director = require("tools.trailer.director")
local Recorder = require("tools.trailer.recorder")

local Trailer = {}

local TRAILER_DIR = "trailer"
local FRAMES_DIR = TRAILER_DIR .. "/frames"

local FIXED_DT = 1 / 60

function Trailer.run()
	require("core.bootstrap").initMinimal()

	love.filesystem.createDirectory(TRAILER_DIR)
	love.filesystem.createDirectory(FRAMES_DIR)

	Recorder.fixedDt = FIXED_DT

	--Recorder.enabled = false -- Flip back after recording audio

    -- Force fixed timestep
    love.timer.step()

    if Config.mode == "single" then
        Director.load(Config.startShot)
    else
        Director.load("shot_01") -- always start at the beginning
    end
end

function love.update(dt)
    if Recorder.enabled then
        -- Deterministic offline render
        Director.update(Recorder.fixedDt)
    else
        -- Normal interactive update
        Director.update(dt)
    end
end

function love.draw()
    Director.draw()

    if Recorder.enabled then
        Recorder.capture()
    end
end

return Trailer