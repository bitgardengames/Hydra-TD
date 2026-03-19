local Config = require("tools.trailer.config")

local recorder = {
    frame = 0,
    enabled = Config.recorder or false,
}

local format = string.format

function recorder.capture()
	if not recorder.enabled then
		return
	end

	recorder.frame = recorder.frame + 1

	love.graphics.captureScreenshot(format("trailer/frames/frame_%05d.png", recorder.frame))
end

return recorder