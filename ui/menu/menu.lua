local State = require("core.state")

local Settings = require("ui.menu.screens.settings")

local Screens = {
	menu = require("ui.menu.screens.main_menu"),
	campaign = require("ui.menu.screens.campaign"),
	tower_mastery = require("ui.menu.screens.tower_mastery"),
	settings = Settings,
	settings_gameplay = Settings,
	victory = require("ui.menu.screens.victory"),
	game_over = require("ui.menu.screens.game_over"),

	pause = require("ui.menu.pause"),
}

local Menu = {}


function Menu.load()
	local loaded = {}

	for _, screen in pairs(Screens) do
		if screen.load and not loaded[screen] then
			screen.load()
			loaded[screen] = true
		end
	end
end

function Menu.update(dt)
	local screen = Screens[State.mode]

	if screen and screen.update then
		screen.update(dt)
	end
end

function Menu.set(mode)
	local previousScreen = Screens[State.mode]
	if previousScreen and previousScreen.leave then
		previousScreen.leave()
	end

	State.mode = mode
	
	local screen = Screens[mode]

	if screen and screen.enter then
		screen.enter()
	end
end

function Menu.draw()
	local screen = Screens[State.mode]

	if screen and screen.draw then
		screen.draw()
	end
end

function Menu.keypressed(key)
	local screen = Screens[State.mode]

	if screen and screen.keypressed then
		screen.keypressed(key)
	end
end

function Menu.gamepadpressed(joystick, button)
	local screen = Screens[State.mode]
	if screen and screen.gamepadpressed then screen.gamepadpressed(joystick, button) end
end

function Menu.mousepressed(x, y, button)
	local screen = Screens[State.mode]

	if screen and screen.mousepressed then
		screen.mousepressed(x, y, button)
	end
end

function Menu.mousereleased(x, y, button)
	local screen = Screens[State.mode]

	if screen and screen.mousereleased then
		screen.mousereleased(x, y, button)
	end
end

function Menu.wheelmoved(x, y)
	local screen = Screens[State.mode]

	if screen and screen.wheelmoved then
		screen.wheelmoved(x, y)
	end
end

-- Pause overlay (called from main loop)
function Menu.updatePause(dt)
	Screens.pause.update(dt)
end

function Menu.drawPause()
	Screens.pause.draw()
end

function Menu.mousepressedPause(x, y, button)
	return Screens.pause.mousepressed(x, y, button)
end

return Menu
