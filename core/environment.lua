local Environment = {}

function Environment.load()
    love.mouse.setVisible(false)
    love.graphics.setDefaultFilter("nearest", "nearest")
    love.window.setTitle("Hydra TD")

    if #love.joystick.getJoysticks() > 0 then
        require("core.cursor").enableVirtual()
    end

	--love.window.setMode(0, 0, {fullscreen = true, fullscreentype = "desktop", vsync = 1})

	-- Testing resolution scaling
	--love.window.setMode(2560, 1440, {fullscreen = false, resizable = false}) -- 1440p
	--love.window.setMode(1920, 1080, {fullscreen = false, resizable = false}) -- 1080
	--love.window.setMode(1280, 720, {fullscreen = false, resizable = false}) -- 720p
	--love.window.setMode(1366, 768, {fullscreen = false, resizable = false}) -- laptops
	--love.window.setMode(1280, 800, {fullscreen = false, resizable = false}) -- steam deck
	--love.window.setMode(1024, 768, {fullscreen = false, resizable = false}) -- torture test
end

return Environment