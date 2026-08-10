local Window = {}

function Window.apply(settings, fullscreen)
	settings = settings or {}
	if fullscreen == nil then fullscreen = settings.fullscreen == true end
	local width, height = 1280, 800
	if fullscreen then width, height = love.window.getDesktopDimensions() end
	local msaa = require("core.scale").suggestMSAA(width, height)
	local ok, err = love.window.updateMode(fullscreen and 0 or width, fullscreen and 0 or height, {
		fullscreen = fullscreen, fullscreentype = fullscreen and "desktop" or nil,
		resizable = not fullscreen, vsync = 1, msaa = msaa,
	})
	if ok and love.resize then love.resize(love.graphics.getDimensions()) end
	return ok, err
end

return Window
