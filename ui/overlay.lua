local Overlay = {}

local active = nil

local min = math.min

local function smoothstep(t)
	return t * t * (3 - 2 * t)
end

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

function Overlay.newEnterAnimation()
	return {enterT = 0}
end

function Overlay.updateEnterAnimation(anim, dt, speed)
	if not anim then
		return 1
	end

	anim.enterT = min(1, (anim.enterT or 0) + dt * (speed or 6))

	return anim.enterT
end

function Overlay.easeEnter(anim)
	return smoothstep(anim and anim.enterT or 1)
end

function Overlay.dimAlpha(anim, maxAlpha)
	return (maxAlpha or 0.5) * Overlay.easeEnter(anim)
end

function Overlay.panelScale(anim, fromScale, toScale)
	local from = fromScale or 0.96
	local to = toScale or 1

	return from + (to - from) * Overlay.easeEnter(anim)
end

function Overlay.panelOffsetY(anim, fromOffset, toOffset)
	local from = fromOffset or 12
	local to = toOffset or 0

	return from + (to - from) * Overlay.easeEnter(anim)
end

function Overlay.pushPanelTransform(cx, cy, anim, fromScale, fromOffsetY)
	local lg = love.graphics
	local scale = Overlay.panelScale(anim, fromScale)
	local offsetY = Overlay.panelOffsetY(anim, fromOffsetY)

	lg.push()
	lg.translate(cx, cy + offsetY)
	lg.scale(scale, scale)
	lg.translate(-cx, -cy)
end

function Overlay.popPanelTransform()
	love.graphics.pop()
end

return Overlay
