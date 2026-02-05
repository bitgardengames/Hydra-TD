-- ui/glyphs.lua
local Glyphs = {}

Glyphs.size = 18
Glyphs.padding = 4

Glyphs.map = {
	a = { image = "glyphs/xbox_a.png" },
	b = { image = "glyphs/xbox_b.png" },
	x = { image = "glyphs/xbox_x.png" },
	y = { image = "glyphs/xbox_y.png" },

	leftshoulder  = { image = "glyphs/xbox_lb.png" },
	rightshoulder = { image = "glyphs/xbox_rb.png" },

	start = { image = "glyphs/xbox_start.png" },
	back  = { image = "glyphs/xbox_back.png" },

	dpup    = { image = "glyphs/dpad_up.png" },
	dpdown  = { image = "glyphs/dpad_down.png" },
	dpleft  = { image = "glyphs/dpad_left.png" },
	dpright = { image = "glyphs/dpad_right.png" },
}

function Glyphs.load()
	for _, g in pairs(Glyphs.map) do
		g.tex = love.graphics.newImage(g.image)
		g.tex:setFilter("linear", "linear")
	end
end

function Glyphs.draw(key, x, y, scale)
	local g = Glyphs.map[key]
	if not g then return end

	scale = scale or 1
	local s = Glyphs.size * scale

	love.graphics.draw(
		g.tex,
		x, y,
		0,
		s / g.tex:getWidth(),
		s / g.tex:getHeight()
	)
end
