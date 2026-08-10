local Fonts = {}

local current = "ui"
local uiScale = 1

local FONT_MAP = {
	--latin = "assets/fonts/PTSans.ttf",
	latin = "assets/fonts/Fredoka_SemiCondensed-SemiBold.ttf",
	cjk = "assets/fonts/NotoSansCJK-Regular.ttc",
	cyrillic = "assets/fonts/NotoSans-Regular.ttf",
}

function Fonts.load()
	Fonts.active = "latin"
	Fonts.reload()
end

function Fonts.setLocale(kind)
	if Fonts.active ~= kind then
		Fonts.active = kind
		Fonts.reload()
	end
end

function Fonts.reload()
	local f = FONT_MAP[Fonts.active]
	local function size(value) return math.max(8, math.floor(value * uiScale + 0.5)) end

	Fonts.version = love.graphics.newFont(f, size(12))
	Fonts.tooltip = love.graphics.newFont(f, size(14))
	Fonts.ui = love.graphics.newFont(f, size(16))
	Fonts.floaters = love.graphics.newFont(f, size(24))
	Fonts.menu = love.graphics.newFont(f, size(24))
	Fonts.title = love.graphics.newFont(f, size(42))
end

function Fonts.setUIScale(value)
	local nextScale = math.max(0.75, math.min(1.5, tonumber(value) or 1))
	nextScale = math.floor(nextScale * 20 + 0.5) / 20
	if nextScale ~= uiScale then
		uiScale = nextScale
		if Fonts.active then Fonts.reload() end
	end
	return uiScale
end

function Fonts.set(kind)
	current = kind
	love.graphics.setFont(Fonts[kind])
end

function Fonts.get(kind)
	return Fonts[current]
end

return Fonts
