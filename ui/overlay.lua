local Overlay = {}

local active = nil

function Overlay.show(screen)
	active = screen

	if active and active.enter then
		active.enter()
	end
end

function Overlay.hide()
	active = nil
end

function Overlay.isActive()
	return active ~= nil
end

function Overlay.update(dt)
	if active and active.update then
		active.update(dt)
	end
end

function Overlay.draw()
	if active and active.draw then
		active.draw()
	end
end

function Overlay.mousepressed(x, y, button)
	if active and active.mousepressed then
		return active.mousepressed(x, y, button)
	end
end

function Overlay.mousereleased(x, y, button)
	if active and active.mousereleased then
		return active.mousereleased(x, y, button)
	end
end

function Overlay.keypressed(key)
	if active and active.keypressed then
		return active.keypressed(key)
	end
end

return Overlay