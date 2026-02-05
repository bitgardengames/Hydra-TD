local Fonts = {}

local FONT_MAP = {
	latin = "assets/fonts/PTSans.ttf",
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

	Fonts.version = love.graphics.newFont(f, 12)
	Fonts.ui = love.graphics.newFont(f, 16)
	Fonts.floaters = love.graphics.newFont(f, 24)
	Fonts.menu = love.graphics.newFont(f, 32)
	Fonts.title = love.graphics.newFont(f, 48)
end

function Fonts.set(kind)
	love.graphics.setFont(Fonts[kind])
end

return Fonts