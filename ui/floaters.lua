local Camera = require("core.camera")
local Text = require("ui.text")

local floaters = {}

local ipairs = ipairs
local floor = math.floor
local random = love.math.random
local tinsert = table.insert
local tremove = table.remove

local function add(x, y, text, r, g, b)
	tinsert(floaters, {
		x = x,
		y = y,
		startY = y,
		rise = 22 + random() * 6,
		text = text,
		t = 0,
		life = 1,
		r = r or 1,
		g = g or 1,
		b = b or 1,
	})
end

local function update(dt)
	for i = #floaters, 1, -1 do
		local f = floaters[i]

		f.t = f.t + dt

		local p = f.t / f.life

		if p >= 1 then
			tremove(floaters, i)
		else
			local ease = 1 - (1 - p) * (1 - p)

			f.y = f.startY - ease * f.rise
		end
	end
end

local function draw()
	for _, f in ipairs(floaters) do
		local p = f.t / f.life

		local rise = (1 - p) * 10
		local alpha = (p < 0.2) and 1 or (1 - (p - 0.2) / 0.8)

		-- Convert world to screen
		local sx, sy = Camera.worldToScreen(f.x, f.y - rise)

		-- Snap after conversion
		sx = floor(sx + 0.5)
		sy = floor(sy + 0.5)

		local text = f.text
		local font = love.graphics.getFont()
		local textW = font:getWidth(text)

		love.graphics.setColor(f.r, f.g, f.b, alpha)
		Text.printShadow(text, sx - textW * 0.5, sy)
	end
end

function clear()
	for i = #floaters, 1, -1 do
		floaters[i] = nil
	end
end

return {
	floaters = floaters,
	add = add,
	update = update,
	draw = draw,
	clear = clear,
}