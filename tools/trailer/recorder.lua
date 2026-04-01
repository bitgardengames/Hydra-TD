local Config = require("tools.trailer.config")
local HeroExport = require("tools.trailer.hero_export")
local Draw = require("render.draw")

local lg = love.graphics

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

	local filename = format("trailer/frames/frame_%05d.png", recorder.frame)

	--[[local canvas = HeroExport.renderWorldToCanvas(
		Config.output.width,
		Config.output.height,
		function()
			Draw.drawWorld()

			if Config.showUI then
				Draw.drawUI()
			end
		end
	)

	local img = canvas:newImageData()
	img:encode("png", filename)
	]]

	lg.captureScreenshot(filename)
end

return recorder