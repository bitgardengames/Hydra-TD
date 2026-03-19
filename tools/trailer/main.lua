local Config = require("tools.trailer.config")
local Director = require("tools.trailer.director")
local Recorder = require("tools.trailer.recorder")

local Trailer = {}

local TRAILER_DIR = "trailer"
local FRAMES_DIR = TRAILER_DIR .. "/frames"

local FIXED_DT = 1 / 120

function Trailer.run()
	require("core.bootstrap").initMinimal()

	love.filesystem.createDirectory(TRAILER_DIR)
	love.filesystem.createDirectory(FRAMES_DIR)

	Recorder.fixedDt = FIXED_DT

    -- Force fixed timestep
    love.timer.step()

	if Config.mode == "single" then
		Director.load(Config.startShot)
	elseif Config.mode == "screenshots" then
		Director.runScreenshotBatch(Config.screenshots.list, Config.screenshots.prefix)
	else
		Director.loadSequence(Config.sequence)
	end

	--require("systems.sound").playMusic("gameplay")
	require("systems.sound").playMusic("menu")
end

function love.update(dt)
    if Recorder.enabled then
        -- Deterministic offline render
        Director.update(Recorder.fixedDt)
    else
        -- Normal interactive update
        Director.update(Recorder.fixedDt)
    end
end

function love.draw()
	Director.draw()

	local batch = Director._shotBatch

	if batch and not batch.capturing and not batch.done then
		local entry = batch.entries[batch.index]
		local shot = entry.shot
		local targetFrame = entry.frame

		local filename = string.format(
			"screenshots/%s_%02d_%s_%d.png",
			batch.prefix,
			batch.index,
			shot,
			targetFrame
		)

		batch.capturing = true

		love.graphics.captureScreenshot(function(img)
			img:encode("png", filename)
			print("Saved:", filename)

			batch.index = batch.index + 1
			batch.capturing = false

			if batch.index > #batch.entries then
				batch.done = true
				print("Screenshot batch complete")
				love.event.quit()
				return
			end

			Director._loadFrozenBatchShot(batch.index)
		end)
	end

	if Recorder.enabled then
		Recorder.capture()
	end
end

return Trailer