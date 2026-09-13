local Window = {}

local DEFAULT_WIDTH, DEFAULT_HEIGHT = 1280, 800
local DISPLAY_MODES = {windowed = true, borderless = true, fullscreen = true}

local function positiveInteger(value, fallback)
	value = tonumber(value)
	if not value or value < 1 or value ~= value then return fallback end
	return math.floor(value + 0.5)
end

local function displayCount()
	if not love or not love.window or not love.window.getDisplayCount then return 1 end
	local ok, count = pcall(love.window.getDisplayCount)
	return ok and math.max(1, positiveInteger(count, 1)) or 1
end

local function desktopDimensions(display)
	if love and love.window and love.window.getDesktopDimensions then
		local ok, w, h = pcall(love.window.getDesktopDimensions, display)
		if ok and tonumber(w) and tonumber(h) and w > 0 and h > 0 then return w, h end
	end
	return DEFAULT_WIDTH, DEFAULT_HEIGHT
end

local function resolutionKey(w, h) return tostring(w) .. "x" .. tostring(h) end

-- Returns the useful modes for a display in deterministic, smallest-first order.
-- The desktop size is included even on platforms which omit it from the exclusive
-- fullscreen mode list.
function Window.getResolutions(display)
	display = math.min(displayCount(), math.max(1, positiveInteger(display, 1)))
	local desktopW, desktopH = desktopDimensions(display)
	local modes = {}
	if love and love.window and love.window.getFullscreenModes then
		local ok, available = pcall(love.window.getFullscreenModes, display)
		if ok and type(available) == "table" then modes = available end
	end

	local result, seen = {}, {}
	local function add(w, h)
		w, h = positiveInteger(w), positiveInteger(h)
		if not w or not h or w > desktopW or h > desktopH then return end
		local key = resolutionKey(w, h)
		if seen[key] then return end
		seen[key] = true
		result[#result + 1] = {width = w, height = h}
	end
	for _, mode in ipairs(modes) do
		if type(mode) == "table" then add(mode.width, mode.height) end
	end
	add(desktopW, desktopH)
	table.sort(result, function(a, b)
		local aa, ba = a.width * a.height, b.width * b.height
		return aa == ba and a.width < b.width or aa < ba
	end)
	return result
end

function Window.getDisplays()
	local displays = {}
	for i = 1, displayCount() do
		local w, h = desktopDimensions(i)
		displays[i] = {index = i, width = w, height = h, resolutions = Window.getResolutions(i)}
	end
	return displays
end

local function resolutionAvailable(resolutions, width, height)
	for _, mode in ipairs(resolutions) do
		if mode.width == width and mode.height == height then return true end
	end
	return false
end

function Window.normalizeSettings(settings, displays)
	settings = type(settings) == "table" and settings or {}
	displays = displays or Window.getDisplays()
	if #displays == 0 then
		displays = {{index = 1, width = DEFAULT_WIDTH, height = DEFAULT_HEIGHT,
			resolutions = {{width = DEFAULT_WIDTH, height = DEFAULT_HEIGHT}}}}
	end

	if not DISPLAY_MODES[settings.displayMode] then
		settings.displayMode = settings.fullscreen == false and "windowed" or "borderless"
	end
	settings.fullscreen = nil -- retired, unstable alias
	settings.displayIndex = positiveInteger(settings.displayIndex, 1)
	if settings.displayIndex > #displays then settings.displayIndex = 1 end
	local display = displays[settings.displayIndex] or displays[1]
	settings.windowWidth = positiveInteger(settings.windowWidth, DEFAULT_WIDTH)
	settings.windowHeight = positiveInteger(settings.windowHeight, DEFAULT_HEIGHT)
	settings.windowWidth = math.min(settings.windowWidth, display.width)
	settings.windowHeight = math.min(settings.windowHeight, display.height)

	local resolutions = display.resolutions or {}
	local fallback = resolutions[#resolutions] or {width = display.width, height = display.height}
	local windowFallback = fallback
	for _, resolution in ipairs(resolutions) do
		if resolution.width == DEFAULT_WIDTH and resolution.height == DEFAULT_HEIGHT then
			windowFallback = resolution
			break
		end
	end
	settings.fullscreenWidth = positiveInteger(settings.fullscreenWidth, fallback.width)
	settings.fullscreenHeight = positiveInteger(settings.fullscreenHeight, fallback.height)
	if not resolutionAvailable(resolutions, settings.fullscreenWidth, settings.fullscreenHeight) then
		settings.fullscreenWidth, settings.fullscreenHeight = fallback.width, fallback.height
	end
	if not resolutionAvailable(resolutions, settings.windowWidth, settings.windowHeight) then
		settings.windowWidth, settings.windowHeight = windowFallback.width, windowFallback.height
	end
	return settings
end

function Window.buildMode(settings, displays)
	Window.normalizeSettings(settings, displays)
	local display = (displays or Window.getDisplays())[settings.displayIndex]
	local mode = settings.displayMode
	local width, height = settings.windowWidth, settings.windowHeight
	if mode == "borderless" then
		width, height = 0, 0
	elseif mode == "fullscreen" then
		width, height = settings.fullscreenWidth, settings.fullscreenHeight
	end
	return width, height, {
		fullscreen = mode ~= "windowed",
		fullscreentype = mode == "fullscreen" and "exclusive" or (mode == "borderless" and "desktop" or nil),
		display = settings.displayIndex,
		resizable = mode == "windowed", vsync = 1,
	}, display
end

function Window.apply(settings)
	settings = settings or {}
	local displays = Window.getDisplays()
	local width, height, flags, display = Window.buildMode(settings, displays)
	local renderW, renderH = width, height
	if renderW == 0 then renderW, renderH = display.width, display.height end
	flags.msaa = require("core.scale").suggestMSAA(renderW, renderH)
	local ok, err = love.window.updateMode(width, height, flags)
	if ok and love.resize then love.resize(love.graphics.getDimensions()) end
	return ok, err
end

return Window
