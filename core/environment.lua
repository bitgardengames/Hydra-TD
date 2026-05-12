local Environment = {}

function Environment.load()
	love.mouse.setVisible(false)
	love.graphics.setDefaultFilter("nearest", "nearest")
	love.window.setTitle("Hydra TD")


	--love.window.setMode(0, 0, {fullscreen = true, fullscreentype = "desktop", vsync = 1, msaa = 8})

	-- Testing resolution scaling
	--love.window.setMode(2560, 1440, {fullscreen = false, resizable = false, msaa = 8}) -- 1440p
	--love.window.setMode(1920, 1080, {fullscreen = false, resizable = false, msaa = 8}) -- 1080
	--love.window.setMode(1280, 720, {fullscreen = false, resizable = false, msaa = 8}) -- 720p
	--love.window.setMode(1366, 768, {fullscreen = false, resizable = false, msaa = 8}) -- laptops
	--love.window.setMode(1280, 800, {fullscreen = false, resizable = false, msaa = 8}) -- steam deck
	--love.window.setMode(1024, 768, {fullscreen = false, resizable = false, msaa = 8}) -- torture test

	-- Vertical format
	--love.window.setMode(1080, 1920, {fullscreen = false, resizable = false, msaa = 8})
end

return Environment