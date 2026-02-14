local Config = require("tools.map_export.config")
local Exporter = require("tools.map_export.exporter")

local Main = {}

function Main.run()
	if not Config.enabled then
		love.event.quit()

		return
	end

	love.math.setRandomSeed(Config.seed or 123456)
	love.timer.step()

	Exporter.start()
end

function love.update(dt)
	Exporter.update(dt)
end

function love.draw()
	Exporter.draw()
end

return Main