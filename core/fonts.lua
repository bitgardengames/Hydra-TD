local Fonts = {}

function Fonts.load()
    Fonts.ui = love.graphics.newFont("assets/fonts/PTSans.ttf", 16)
    Fonts.floaters = love.graphics.newFont("assets/fonts/PTSans.ttf", 24)
    Fonts.menu = love.graphics.newFont("assets/fonts/PTSans.ttf", 32)
    Fonts.title = love.graphics.newFont("assets/fonts/PTSans.ttf", 48)
end

function Fonts.set(kind)
    love.graphics.setFont(Fonts[kind])
end

return Fonts