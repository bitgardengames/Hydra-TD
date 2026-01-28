function love.conf(t)
	t.identity = "HydraTD"
	t.window.icon = "assets/appicon_256.png"

	t.console = false
	
	t.modules.touch = false
	t.modules.video = false
	t.modules.physics = false
	
    t.window.title = "Hydra TD"
	--t.window.borderless = true
	t.window.fullscreen = true
    t.window.vsync = 1
    t.window.msaa = 8
end