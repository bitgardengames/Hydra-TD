local State = require("core.state")

local Settings = require("ui.menu.screens.settings")

local Screens = {
	menu = require("ui.menu.screens.main_menu"),
	campaign = require("ui.menu.screens.campaign"),
	settings = Settings,
	settings_gameplay = Settings,
	victory = require("ui.menu.screens.victory"),
	game_over = require("ui.menu.screens.game_over"),

	pause = require("ui.menu.pause"),
}

local Menu = {
	transition = nil,
}

local TRANSITION_DURATION = 0.18
local TRANSITION_OFFSET = 28

local transitionCanvas = nil
local transitionCanvasW = 0
local transitionCanvasH = 0

local function getTransitionCanvas()
	local w, h = love.graphics.getDimensions()
	if not transitionCanvas or transitionCanvasW ~= w or transitionCanvasH ~= h then
		transitionCanvas = love.graphics.newCanvas(w, h)
		transitionCanvasW = w
		transitionCanvasH = h
	end
	return transitionCanvas
end

local function shouldTransition(from, to)
	if from == to then
		return false
	end

	-- Gameplay and pause swaps should stay immediate so input never feels delayed.
	if from == "game" or to == "game" or from == "pause" or to == "pause" then
		return false
	end

	if from == "settings_gameplay" or to == "settings_gameplay" then
		return false
	end

	return Screens[from] ~= nil and Screens[to] ~= nil
end

-- Screen lifecycle changes must go through one path. Transitions used to carry
-- a second copy of this leave/set/enter sequence, which made it very easy for
-- immediate and animated navigation to drift apart as screens gained hooks.
local function changeScreen(mode)
	if State.mode == mode then
		return false
	end

	local previousScreen = Screens[State.mode]
	if previousScreen and previousScreen.leave then
		previousScreen.leave()
	end

	State.mode = mode

	local screen = Screens[mode]
	if screen and screen.enter then
		screen.enter()
	end

	return true
end

local function finishTransition(transition)
	changeScreen(transition.to)
	transition.switched = true
end

local function drawScreen(mode, alpha, offsetX)
	local screen = Screens[mode]
	if not (screen and screen.draw) then
		return
	end

	if alpha >= 0.999 and (not offsetX or offsetX == 0) then
		screen.draw()
		return
	end

	local canvas = getTransitionCanvas()
	love.graphics.push("all")
	love.graphics.setCanvas(canvas)
	love.graphics.clear(0, 0, 0, 0)
	love.graphics.origin()
	screen.draw()
	love.graphics.pop()

	love.graphics.push("all")
	love.graphics.setColor(1, 1, 1, alpha or 1)
	love.graphics.draw(canvas, offsetX or 0, 0)
	love.graphics.pop()
end

local function dispatch(mode, event, ...)
	local screen = Screens[mode]
	local handler = screen and screen[event]
	if handler then
		return handler(...)
	end
end

function Menu.handlesMode(mode)
	return Screens[mode] ~= nil
end


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
	local transition = Menu.transition
	if transition then
		transition.t = math.min(transition.t + dt, transition.duration)

		if not transition.switched and transition.t >= transition.duration * 0.5 then
			finishTransition(transition)
		end

		if transition.t >= transition.duration then
			if not transition.switched then
				finishTransition(transition)
			end
			Menu.transition = nil
		end
	end

	dispatch(State.mode, "update", dt)
end

function Menu.set(mode)
	local from = State.mode

	if Menu.transition then
		if Menu.transition.to == mode then
			return
		end
		Menu.transition = nil
	end

	if not shouldTransition(from, mode) then
		changeScreen(mode)
		return
	end

	Menu.transition = {
		from = from,
		to = mode,
		t = 0,
		duration = TRANSITION_DURATION,
		switched = false,
	}
end

function Menu.draw()
	local transition = Menu.transition
	if transition then
		local progress = math.min(transition.t / transition.duration, 1)
		local eased = progress * progress * (3 - 2 * progress)
		local incomingX = TRANSITION_OFFSET * (1 - eased)
		local outgoingX = -TRANSITION_OFFSET * eased

		drawScreen(transition.from, 1 - eased, outgoingX)
		drawScreen(transition.to, eased, incomingX)
		return
	end

	drawScreen(State.mode, 1, 0)
end

function Menu.keypressed(key)
	return dispatch(State.mode, "keypressed", key)
end

function Menu.mousepressed(x, y, button)
	return dispatch(State.mode, "mousepressed", x, y, button)
end

function Menu.mousereleased(x, y, button)
	return dispatch(State.mode, "mousereleased", x, y, button)
end

function Menu.wheelmoved(x, y)
	return dispatch(State.mode, "wheelmoved", x, y)
end

-- Pause overlay (called from main loop)
function Menu.updatePause(dt)
	return dispatch("pause", "update", dt)
end

function Menu.drawPause()
	return dispatch("pause", "draw")
end

function Menu.mousepressedPause(x, y, button)
	return dispatch("pause", "mousepressed", x, y, button)
end

return Menu
