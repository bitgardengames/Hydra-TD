local State = require("core.state")

local Screens = {
	menu = require("ui.menu.screens.main_menu"),
	campaign = require("ui.menu.screens.campaign"),
	settings = require("ui.menu.screens.settings"),

	victory = require("ui.menu.screens.victory"),
	game_over = require("ui.menu.screens.game_over"),

	pause = require("ui.menu.pause"),
}

local Menu = {}

local lastMode

function Menu.load()
	for _, screen in pairs(Screens) do
		if screen.load then
			screen.load()
		end
	end
end

function Menu.update(dt)
	--[[if State.mode ~= lastMode then
		if lastMode then
			local prev = Screens[lastMode]
			if prev and prev.leave then prev.leave() end
		end

		local next = Screens[State.mode]
		if next and next.enter then next.enter() end

		lastMode = State.mode
	end]]

	local screen = Screens[State.mode]

	if screen and screen.update then
		screen.update(dt)
	end
end

function Menu.set(mode)
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