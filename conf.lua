local Constants = require("core.constants")

function love.conf(t)
	if Constants.IS_DEMO then
		t.identity = "HydraTD_Demo"
		t.window.title = "Hydra TD Demo"
	else
		t.identity = "HydraTD"
		t.window.title = "Hydra TD"
	end

	t.window.icon = "assets/appicon_256.png"

	t.modules.touch = false
	t.modules.video = false
	t.modules.physics = false

	t.window.vsync = 1
	t.window.msaa = 8
	t.console = false
end
